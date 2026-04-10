import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:danaya_plus/features/pos/domain/models/sale.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

final clientSyncProvider = Provider((ref) {
  final service = ClientSyncService(ref);
  ref.onDispose(() => service.disconnectWebSocket());
  return service;
});

class ClientSyncService {
  final Ref _ref;
  WebSocketChannel? _wsChannel;
  Timer? _reconnectTimer;

  ClientSyncService(this._ref);

  String _getBaseUrl() {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null) return '';
    return 'http://${settings.serverIp}:${settings.serverPort}';
  }

  Map<String, String> _getHeaders() {
    final settings = _ref.read(shopSettingsProvider).value;
    return {
      'content-type': 'application/json',
      if (settings?.syncKey != null && settings!.syncKey.isNotEmpty)
        'X-Sync-Key': settings.syncKey,
    };
  }

  void connectWebSocket() {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || settings.serverIp.isEmpty) return;
    
    final wsUrl = 'ws://${settings.serverIp}:${settings.serverPort}/ws?key=${settings.syncKey}';
    
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      debugPrint('🟢 Tentative de connexion WebSocket à $wsUrl');
      
      _wsChannel!.stream.listen(
        (message) {
          debugPrint('📥 WS Message Reçu: $message');
          _handleWebSocketMessage(message);
        },
        onDone: () {
          debugPrint('🔴 WebSocket Client Déconnecté. Reconnexion...');
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('⚠️ Erreur WebSocket Client: $error');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('❌ Echec initial WebSocket ($e). Reconnexion...');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connectWebSocket();
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      // Quand on reçoit un signal de changement, on force la synchro immédiate locale
      if (type == 'sale_synced' || type == 'stock_movement_synced') {
        debugPrint('⚡ Temps Réel: Forçage de la synchro des produits suites à $type');
        syncProductsFromServer();
      }
    } catch (e) {
      debugPrint('Erreur lors du traitement WS: $e');
    }
  }

  void disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  /// Récupère les réglages de la boutique depuis le serveur
  Future<void> syncSettingsFromServer() async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/sync/settings'), headers: _getHeaders());
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final settings = _ref.read(shopSettingsProvider).value;
        if (settings != null) {
          final updated = settings.copyWith(
            name: data['name'],
            currency: data['currency'],
            taxName: data['taxName'],
            taxRate: (data['taxRate'] as num).toDouble(),
            useTax: data['useTax'],
            phone: data['phone'],
            address: data['address'],
          );
          await _ref.read(shopSettingsProvider.notifier).save(updated);
          debugPrint('✅ Réglages de la boutique synchronisés depuis le serveur');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur synchro réglages: $e');
    }
  }

  /// Récupère les utilisateurs depuis le serveur (Authentification partagée)
  Future<void> syncUsersFromServer() async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/sync/users'), headers: _getHeaders());
      if (response.statusCode == 200) {
        final List<dynamic> usersJson = jsonDecode(response.body);
        final db = await _ref.read(databaseServiceProvider).database;

        await db.transaction((txn) async {
          for (final userMap in usersJson) {
            await txn.insert(
              'users',
              userMap as Map<String, dynamic>,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
        debugPrint('✅ Synchronisation des utilisateurs réussie (${usersJson.length} comptes)');
      }
    } catch (e) {
      debugPrint('❌ Erreur synchro utilisateurs: $e');
    }
  }

  /// SECURITY NOTE: This service currently uses plain HTTP/WS. For production use over 
  /// non-secure networks, it is CRITICAL to implement:
  /// 1. HTTPS/WSS (SSL/TLS)
  /// 2. Authentication headers (JWT/API Keys)
  /// 3. Rate limiting and payload validation
  
  DateTime? _lastProductSync;

  /// Récupère les produits depuis le serveur (Delta Sync)
  Future<void> syncProductsFromServer() async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return;

    // DEBOUNCE: Eviter de spammer le serveur (max 1 fois toutes les 10 sec)
    if (_lastProductSync != null && DateTime.now().difference(_lastProductSync!).inSeconds < 10) {
      debugPrint('🕒 Synchro produits sautée (debounce)');
      return;
    }
    _lastProductSync = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt('last_product_sync') ?? 0;
      
      final response = await http.get(Uri.parse('$baseUrl/sync/products?since=$lastSync'), headers: _getHeaders());
      if (response.statusCode == 200) {
        // OPTIMISATION: compute pour le décodage JSON lourd
        final List<dynamic> productsJson = await compute((String body) => jsonDecode(body) as List<dynamic>, response.body);
        if (productsJson.isEmpty) return;
        
        final db = await _ref.read(databaseServiceProvider).database;

        // OPTIMISATION: Transaction unique pour tout le batch
        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final productMap in productsJson) {
            final map = productMap as Map<String, dynamic>;
            if (map['is_deleted'] == 1) {
               batch.delete('products', where: 'id = ?', whereArgs: [map['id']]);
            } else {
               batch.insert(
                 'products',
                 map,
                 conflictAlgorithm: ConflictAlgorithm.replace,
               );
            }
          }
          await batch.commit(noResult: true);
        });
        
        // Sauvegarder le nouveau timestamp
        await prefs.setInt('last_product_sync', DateTime.now().millisecondsSinceEpoch);
        debugPrint('✅ Delta Sync: ${productsJson.length} produits mis à jour via Isolate/Batch');
      }
    } catch (e) {
      debugPrint('❌ Erreur synchro produits: $e');
    }
  }

  /// Télécharge une image vers le serveur central
  Future<String?> uploadImage(File file) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return null;

    try {
      final bytes = await file.readAsBytes();
      final extension = p.extension(file.path);
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$extension';

      final response = await http.post(
        Uri.parse('$baseUrl/sync/upload-image'),
        headers: {
          ..._getHeaders(),
          'content-type': 'application/octet-stream',
          'x-file-name': fileName,
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fileName'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur upload image: $e');
      return null;
    }
  }

  /// Envoie une vente locale au serveur central
  Future<bool> sendSaleToServer(Sale sale, List<SaleItem> items) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final payload = {
        'sale': sale.toMap(),
        'items': items.map((i) => i.toMap()).toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/sync/sale'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update(
          'sales',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [sale.id],
        );
        debugPrint('✅ Vente ${sale.id.substring(0, 8)} synchronisée sur le serveur');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi vente au serveur: $e');
      return false;
    }
  }

  /// Recherche et envoie toutes les ventes non synchronisées (Rattrapage)
  Future<void> syncPendingSales() async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return;

    try {
      final db = await _ref.read(databaseServiceProvider).database;
      
      // Récupérer les ventes non synchronisées (Optimisé par lots de 50 pour Option A)
      final List<Map<String, dynamic>> pendingSaleMaps = await db.query(
        'sales',
        where: 'is_synced = 0',
        limit: 50,
      );

      if (pendingSaleMaps.isEmpty) return;
      debugPrint('🔄 Rattrapage : ${pendingSaleMaps.length} ventes en attente de synchro...');

      for (final saleMap in pendingSaleMaps) {
        final sale = Sale.fromMap(saleMap);
        
        // Récupérer les items de cette vente
        final List<Map<String, dynamic>> itemMaps = await db.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [sale.id],
        );

        final items = itemMaps.map((m) => SaleItem.fromMap(m)).toList();
        
        // Tenter l'envoi
        final success = await sendSaleToServer(sale, items);
        if (!success) break; // Arrêter si le serveur est de nouveau injoignable
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du rattrapage des ventes: $e');
    }
  }

  /// Envoie un achat (SRM) au serveur central
  Future<bool> sendPurchaseToServer(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final payload = {
        'order': order.toMap(),
        'items': items.map((i) => i.toMap()).toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/sync/purchase-order'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('purchase_orders', {'is_synced': 1}, where: 'id = ?', whereArgs: [order.id]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi achat au serveur: $e');
      return false;
    }
  }

  /// Envoie un mouvement de stock au serveur central
  Future<bool> sendStockMovementToServer(StockMovement movement) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final payload = {
        'movement': movement.toMap(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/sync/stock-movement'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('stock_movements', {'is_synced': 1}, where: 'id = ?', whereArgs: [movement.id]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi mouvement stock au serveur: $e');
      return false;
    }
  }

  /// Envoie un paiement client au serveur central
  Future<bool> sendClientPaymentToServer(Map<String, dynamic> paymentMap) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/client-payment'),
        headers: _getHeaders(),
        body: jsonEncode(paymentMap),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('client_payments', {'is_synced': 1}, where: 'id = ?', whereArgs: [paymentMap['id']]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi paiement client au serveur: $e');
      return false;
    }
  }

  /// Envoie une transaction financière au serveur central
  Future<bool> sendFinancialTransactionToServer(Map<String, dynamic> txMap) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/financial-transaction'),
        headers: _getHeaders(),
        body: jsonEncode(txMap),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('financial_transactions', {'is_synced': 1}, where: 'id = ?', whereArgs: [txMap['id']]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi transaction financière au serveur: $e');
      return false;
    }
  }

  /// Envoie une session de caisse au serveur central
  Future<bool> sendSessionToServer(Map<String, dynamic> sessionMap) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/session'),
        headers: _getHeaders(),
        body: jsonEncode(sessionMap),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('cash_sessions', {'is_synced': 1}, where: 'id = ?', whereArgs: [sessionMap['id']]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi session au serveur: $e');
      return false;
    }
  }

  /// Envoie un produit au serveur central
  Future<bool> sendProductToServer(Product product) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/product'),
        headers: _getHeaders(),
        body: jsonEncode(product.toMap()),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('products', {'is_synced': 1}, where: 'id = ?', whereArgs: [product.id]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi produit au serveur: $e');
      return false;
    }
  }

  /// Envoie un client au serveur central
  Future<bool> sendClientToServer(Client client) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/client'),
        headers: _getHeaders(),
        body: jsonEncode(client.toMap()),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('clients', {'is_synced': 1}, where: 'id = ?', whereArgs: [client.id]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi client au serveur: $e');
      return false;
    }
  }

  /// Envoie un fournisseur au serveur central
  Future<bool> sendSupplierToServer(Supplier supplier) async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/supplier'),
        headers: _getHeaders(),
        body: jsonEncode(supplier.toMap()),
      );

      if (response.statusCode == 200) {
        final db = await _ref.read(databaseServiceProvider).database;
        await db.update('suppliers', {'is_synced': 1}, where: 'id = ?', whereArgs: [supplier.id]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur envoi fournisseur au serveur: $e');
      return false;
    }
  }

  /// Recherche et envoie toutes les données d'audit non synchronisées
  Future<void> syncPendingAuditData() async {
    final baseUrl = _getBaseUrl();
    if (baseUrl.isEmpty) return;

    try {
      final db = await _ref.read(databaseServiceProvider).database;
      
      // 1. Sessions
      final sessions = await db.query('cash_sessions', where: 'is_synced = 0', limit: 50);
      for (final s in sessions) {
        if (!await sendSessionToServer(s)) break;
      }

      // 2. Transactions Financières
      final txs = await db.query('financial_transactions', where: 'is_synced = 0', limit: 50);
      for (final tx in txs) {
        if (!await sendFinancialTransactionToServer(tx)) break;
      }
      
      // 3. Commandes d'Achat (SRM)
      final pos = await db.query('purchase_orders', where: 'is_synced = 0', limit: 50);
      for (final poMap in pos) {
        final po = PurchaseOrder.fromMap(poMap);
        final List<Map<String, dynamic>> items = await db.query('purchase_order_items', where: 'order_id = ?', whereArgs: [po.id]);
        final orderItems = items.map((m) => PurchaseOrderItem.fromMap(m)).toList();
        if (!await sendPurchaseToServer(po, orderItems)) break;
      }

      // 4. Mouvements de Stock
      final movements = await db.query('stock_movements', where: 'is_synced = 0', limit: 50);
      for (final moveMap in movements) {
        final move = StockMovement.fromMap(moveMap);
        if (!await sendStockMovementToServer(move)) break;
      }

      // 5. Paiements Clients (Dettes)
      final payments = await db.query('client_payments', where: 'is_synced = 0', limit: 50);
      for (final payMap in payments) {
        if (!await sendClientPaymentToServer(payMap)) break;
      }

      // 6. Ventes (Rattrapage classique)
      await syncPendingSales();

      // 7. Master Data (Produits, Clients, Fournisseurs) - NOUVEAU Migration v38
      // Synchroniser les produits créés localement
      final pendingProducts = await db.query('products', where: 'is_synced = 0', limit: 50);
      for (final pMap in pendingProducts) {
        if (!await sendProductToServer(Product.fromMap(pMap))) break;
      }

      // Synchroniser les clients créés localement
      final pendingClients = await db.query('clients', where: 'is_synced = 0', limit: 50);
      for (final cMap in pendingClients) {
        if (!await sendClientToServer(Client.fromMap(cMap))) break;
      }

      // Synchroniser les fournisseurs créés localement
      final pendingSuppliers = await db.query('suppliers', where: 'is_synced = 0', limit: 50);
      for (final sMap in pendingSuppliers) {
        if (!await sendSupplierToServer(Supplier.fromMap(sMap))) break;
      }
      
      debugPrint('✅ Synchronisation globale de l\'audit terminée');
    } catch (e) {
      debugPrint('❌ Erreur lors du rattrapage de l\'audit: $e');
    }
  }
}
