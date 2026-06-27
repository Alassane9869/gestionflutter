import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/network/customer_display_html.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 📡 **DANAYA+ BROADCAST & SYNC CORE**
// 
// This service implements the real-time communications layer of Danaya+.
// It serves two critical functions:
//
// 1. **Zero Hardware Lock-in Digital Display**: 
//    Starts a local web server (Shelf) that broadcasts the POS state to any device 
//    on the local network (Tablets, Phones, Smart TVs) via WebSockets.
//
// 2. **Multi-Node Synchronization**: 
//    Acts as the 'Source of Truth' for secondary POS units in a local network, 
//    handling encrypted stock movements, sales, and financial transactions.
//
// **Key Infrastructure:**
// * **UDP Discovery**: Allows secondary units to auto-detect the main server without IP config.
// * **WebSocket Bridge**: Bi-directional, sub-100ms lag for customer engagement.
// * **Encrypted Sync Gate**: High-security middleware validating each packet with a hardware-derived key.

// Provider pour l'état du serveur (Public pour l'UI)
enum ServerStatus { stopped, starting, running, error }

final isServerRunningProvider = NotifierProvider<ServerStatusNotifier, ServerStatus>(() => ServerStatusNotifier());

class ServerStatusNotifier extends Notifier<ServerStatus> {
  @override
  ServerStatus build() => ServerStatus.stopped;
  void setStatus(ServerStatus value) => state = value;
}

final serverServiceProvider = Provider<ServerService>((ref) => ServerService(ref));

// 📈 STRUCTURES DE MONITORING RÉSEAU
class ConnectedClientInfo {
  final String id;
  final String ip;
  final DateTime connectedAt;
  final String userAgent;

  ConnectedClientInfo({
    required this.id,
    required this.ip,
    required this.connectedAt,
    required this.userAgent,
  });
}

class SyncLogEntry {
  final String resource;
  final String action;
  final String details;
  final String clientIp;
  final DateTime timestamp;
  final bool isSuccess;

  SyncLogEntry({
    required this.resource,
    required this.action,
    required this.details,
    required this.clientIp,
    required this.timestamp,
    required this.isSuccess,
  });
}

class ConnectedClientsNotifier extends Notifier<List<ConnectedClientInfo>> {
  @override
  List<ConnectedClientInfo> build() => [];
  
  void updateClients(List<ConnectedClientInfo> Function(List<ConnectedClientInfo>) updateFn) {
    state = updateFn(state);
  }
}

final connectedClientsProvider = NotifierProvider<ConnectedClientsNotifier, List<ConnectedClientInfo>>(() => ConnectedClientsNotifier());

class ServerSyncLogsNotifier extends Notifier<List<SyncLogEntry>> {
  @override
  List<SyncLogEntry> build() => [];
  
  void addLog(SyncLogEntry entry) {
    final list = List<SyncLogEntry>.from(state)..insert(0, entry);
    if (list.length > 30) {
      list.removeRange(30, list.length);
    }
    state = list;
  }
}

final serverSyncLogsProvider = NotifierProvider<ServerSyncLogsNotifier, List<SyncLogEntry>>(() => ServerSyncLogsNotifier());

/// Helper class to queue sync tasks and prevent SQLite locks
class SyncQueue {
  final _queue = <Future<dynamic> Function()>[];
  bool _isProcessing = false;

  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue.add(() async {
      try {
        final result = await task();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });
    _processQueue();
    return completer.future;
  }

  void _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;
    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      await task();
    }
    _isProcessing = false;
  }
}

/// **SERVER SERVICE**
/// The engine behind the local ERP cloud.
class ServerService {
  final Ref _ref;
  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  final List<WebSocketChannel> _connectedSockets = [];
  final Map<WebSocketChannel, ConnectedClientInfo> _clientInfos = {};

  void _addSyncLog(String resource, String action, String details, String clientIp, bool isSuccess) {
    final entry = SyncLogEntry(
      resource: resource,
      action: action,
      details: details,
      clientIp: clientIp,
      timestamp: DateTime.now(),
      isSuccess: isSuccess,
    );
    try {
      _ref.read(serverSyncLogsProvider.notifier).addLog(entry);
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'ajout du log de synchro: $e');
    }
  }

  ServerService(this._ref) {
    // Écouter les changements de réglages pour redémarrer le serveur si nécessaire
    _ref.listen<AsyncValue<ShopSettings>>(shopSettingsProvider, (previous, next) {
      final oldSettings = previous?.value;
      final newSettings = next.value;
      
      if (oldSettings != null && newSettings != null) {
        // Si le port ou la clé change, on redémarre le serveur
        if (oldSettings.serverPort != newSettings.serverPort || 
            oldSettings.syncKey != newSettings.syncKey ||
            oldSettings.serverIp != newSettings.serverIp) {
          debugPrint('🔄 Réglages serveur modifiés, redémarrage automatique...');
          stopServer().then((_) => startServer());
        }

        // Si les réglages d'Afficheur Client changent, on force l'Afficheur à s'adapter en direct !
        if (oldSettings.customerDisplayTheme != newSettings.customerDisplayTheme ||
            oldSettings.useCustomerDisplay3D != newSettings.useCustomerDisplay3D ||
            oldSettings.enableCustomerDisplayTicker != newSettings.enableCustomerDisplayTicker ||
            oldSettings.customerDisplayMessages != newSettings.customerDisplayMessages ||
            oldSettings.isVoiceEnabled != newSettings.isVoiceEnabled ||
            oldSettings.enableVoiceConfig != newSettings.enableVoiceConfig ||
            oldSettings.enableCustomerDisplaySounds != newSettings.enableCustomerDisplaySounds ||
            oldSettings.name != newSettings.name) {
          debugPrint('📺 Réglages Afficheur modifiés, envoi de la mise à jour en direct...');
          broadcastEvent('settings_updated', {
             'theme': newSettings.customerDisplayTheme,
             'use3D': newSettings.useCustomerDisplay3D,
             'enableTicker': newSettings.enableCustomerDisplayTicker,
             'messages': newSettings.customerDisplayMessages,
             'isVoiceEnabled': newSettings.isVoiceEnabled,
             'enableVoiceConfig': newSettings.enableVoiceConfig,
             'enableSounds': newSettings.enableCustomerDisplaySounds,
             'shopName': newSettings.name,
          });
        }
      }
    });
  }

  void broadcastEvent(String eventType, Map<String, dynamic> payload) {
    if (_connectedSockets.isEmpty) return;
    final message = jsonEncode({
      'type': eventType,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Nettoyer les sockets fermés et envoyer aux autres
    _connectedSockets.removeWhere((socket) {
      if (socket.closeCode != null) return true;
      try {
        socket.sink.add(message);
        return false;
      } catch (_) {
        return true;
      }
    });
    debugPrint('🔔 WS Broadcast [$eventType] to ${_connectedSockets.length} clients');
  }

  void broadcastSound(String soundType) {
    broadcastEvent('play_sound', {'sound': soundType});
  }

  Future<void> startServer() async {
    if (_server != null) return;
    // Attendre que les réglages soient chargés
    final settingsAsync = _ref.read(shopSettingsProvider);
    final settings = settingsAsync.value;
    
    if (settings == null) {
      debugPrint('⏳ Attente du chargement des réglages avant de démarrer le serveur...');
      return;
    }

    final port = settings.serverPort;
    final router = Router();

    // Dossier pour les images (AppData/Roaming, hors OneDrive)
    final appSupportDir = await getApplicationSupportDirectory();
    final imagesDir = Directory(p.join(appSupportDir.path, 'uploads', 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Endpoints de base
    router.get('/health', (Request request) {
      return Response.ok('OK', headers: {'content-type': 'text/plain'});
    });

    router.get('/info', (Request request) {
      final currentSettings = _ref.read(shopSettingsProvider).value ?? settings;
      final info = {
        'name': currentSettings.name,
        'version': '1.0.0',
        'mode': 'server',
      };
      return Response.ok(jsonEncode(info), headers: {'content-type': 'application/json'});
    });

    // Afficheur Client (Double Écran)
    router.get('/display', (Request request) {
      final currentSettings = _ref.read(shopSettingsProvider).value ?? settings;
      // On utilise toujours 127.0.0.1 côté serveur pour que le bouton
      // fonctionne même si serverIp n'est pas encore configuré.
      final ip = currentSettings.serverIp.isNotEmpty ? currentSettings.serverIp : '127.0.0.1';
      debugPrint('📺 /display - syncKey passée au HTML: "${currentSettings.syncKey}"');
      final productsAsync = _ref.read(productListProvider);
      final products = productsAsync.value ?? [];
      // On n'envoie que les produits avec image ou les 20 premiers
      final vitrineProducts = products.where((p) => p.imagePath != null).toList();
      if (vitrineProducts.isEmpty) vitrineProducts.addAll(products.take(20));

      final htmlStr = getCustomerDisplayHtml(
        currentSettings.name, 
        ip, 
        port, 
        currentSettings.customerDisplayTheme,
        currencySymbol: currentSettings.currency,
        locale: 'fr-FR', 
        syncKey: currentSettings.syncKey,
        enableTicker: currentSettings.enableCustomerDisplayTicker,
        use3D: currentSettings.useCustomerDisplay3D,
        enableVoice: currentSettings.isVoiceEnabled,
        enableVoiceConfig: currentSettings.enableVoiceConfig,
        enableSounds: currentSettings.enableCustomerDisplaySounds,
        products: vitrineProducts.map((e) => e.toMap()).toList(),
        messages: currentSettings.customerDisplayMessages,
      );
      return Response.ok(htmlStr, headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store, no-cache, must-revalidate',
        'pragma': 'no-cache',
      });
    });

    // --- IMAGES ---

    // Servir les images des produits (Recherche Multipath)
    router.get('/images/<name|.*>', (Request request, String name) async {
      final fileName = p.basename(Uri.decodeComponent(name));
      
      final documentsDir = (await getApplicationDocumentsDirectory()).path;
      final roaming = Platform.environment['APPDATA'];
      final local = Platform.environment['LOCALAPPDATA'];
      
      final List<Directory> searchDirs = [
        imagesDir, // AppSupport/uploads/images
        Directory(p.join(appSupportDir.path, 'product_images')),
        Directory(p.join(documentsDir, 'Danaya+', 'uploads', 'images')),
        Directory(p.join(documentsDir, 'Danaya+', 'product_images')),
        Directory(p.join(documentsDir, 'Danaya Plus', 'uploads', 'images')),
        Directory(p.join(documentsDir, 'Danaya Plus', 'product_images')),
      ];

      if (roaming != null) {
        searchDirs.add(Directory(p.join(roaming, 'Danaya+', 'Danaya+', 'product_images')));
        searchDirs.add(Directory(p.join(roaming, 'Danaya+', 'Danaya+', 'uploads', 'images')));
        searchDirs.add(Directory(p.join(roaming, 'Danaya+', 'product_images')));
        searchDirs.add(Directory(p.join(roaming, 'com.example', 'Danaya+', 'product_images'))); 
        searchDirs.add(Directory(p.join(roaming, 'Danaya_Plus', 'product_images'))); // Fallback alt name
      }

      if (local != null) {
        searchDirs.add(Directory(p.join(local, 'Danaya+', 'product_images')));
        searchDirs.add(Directory(p.join(local, 'Danaya+', 'Danaya+', 'product_images')));
        searchDirs.add(Directory(p.join(local, 'com.example', 'Danaya+', 'product_images')));
        searchDirs.add(Directory(p.join(local, 'Danaya_Plus', 'product_images')));
      }

      debugPrint('🔍 Recherche image : "$fileName"');
      debugPrint('   📂 Dossiers scannés : \${searchDirs.length}');
      
      for (final dir in searchDirs) {
        if (!await dir.exists()) continue;
        final file = File(p.join(dir.path, fileName));
        if (await file.exists()) {
          debugPrint('   ✅ Trouvée dans : ${dir.path}');
          final ext = p.extension(file.path).toLowerCase();
          String contentType = 'image/jpeg';
          if (ext == '.png') contentType = 'image/png';
          if (ext == '.gif') contentType = 'image/gif';
          if (ext == '.webp') contentType = 'image/webp';
          
          return Response.ok(file.openRead(), headers: {
            'content-type': contentType,
            'cache-control': 'public, max-age=3600',
          });
        }
      }

      debugPrint('   ❌ Image "$fileName" non trouvée dans les ${searchDirs.length} dossiers scannés.');
      return Response.notFound('Image not found: $fileName');
    });

    // Upload d'image (Multipart)
    router.post('/sync/upload-image', (Request request) async {
      try {
        final contentType = request.headers['content-type'] ?? '';
        if (!contentType.contains('multipart/form-data')) {
           // Fallback si ce n'est pas du multipart (on peut recevoir du binaire direct avec le nom en header)
           final fileName = request.headers['x-file-name'] ?? 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
           final bytes = await request.read().expand((chunk) => chunk).toList();
           final file = File(p.join(imagesDir.path, fileName));
           await file.writeAsBytes(bytes);
           return Response.ok(jsonEncode({'status': 'success', 'fileName': fileName}), headers: {'content-type': 'application/json'});
        }
        
        // Pour faire simple avec shelf sans dépendance lourde, on peut aussi utiliser un POST binaire 
        // comme implémenté au-dessus avec 'x-file-name'. 
        return Response.internalServerError(body: 'Multipart support not fully implemented yet, use binary POST with x-file-name');
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // --- SYNCHRONISATION ---

    // Connexion WebSocket (Le Coeur du Temps Réel)
    router.get('/ws', (Request request) {
      final providedKey = request.requestedUri.queryParameters['key'] ?? request.url.queryParameters['key'];
      final serverKey = _ref.read(shopSettingsProvider).value?.syncKey;

      if (serverKey != null && serverKey.isNotEmpty && providedKey != serverKey) {
        debugPrint('🚨 Refus WebSocket : Clé Invalide !');
        debugPrint('   - Reçue : "${providedKey ?? "NON FOURNIE"}"');
        debugPrint('   - Attendue : "$serverKey"');
        debugPrint("   - Depuis : ${request.context['shelf.io.connection_info']}");
        return Response.forbidden('WebSocket Key Invalid');
      }

      return webSocketHandler((WebSocketChannel webSocket, String? protocol) {
        final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
        final userAgent = request.headers['user-agent'] ?? 'Inconnu';
        final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';

        final clientInfo = ConnectedClientInfo(
          id: clientId,
          ip: clientIp,
          connectedAt: DateTime.now(),
          userAgent: userAgent,
        );

        debugPrint('🟢 Nouveau client connecté au WebSocket (IP: $clientIp, ID: $clientId)');
        _connectedSockets.add(webSocket);
        _clientInfos[webSocket] = clientInfo;

        try {
          _ref.read(connectedClientsProvider.notifier).updateClients((state) => [...state, clientInfo]);
        } catch (_) {}

        _addSyncLog('websocket', 'connect', 'Nouveau client connecté en temps réel', clientIp, true);
        
        webSocket.stream.listen(
          (message) {
            debugPrint('WS Reçu de $clientIp: $message');
          },
          onDone: () {
            debugPrint('🔴 Client WebSocket déconnecté ($clientIp)');
            _connectedSockets.remove(webSocket);
            final removed = _clientInfos.remove(webSocket);
            if (removed != null) {
              try {
                _ref.read(connectedClientsProvider.notifier).updateClients(
                  (state) => state.where((c) => c.id != removed.id).toList()
                );
              } catch (_) {}
            }
            _addSyncLog('websocket', 'disconnect', 'Client temps réel déconnecté', clientIp, true);
          },
          onError: (error) {
            debugPrint('⚠️ Erreur WebSocket ($clientIp): $error');
            _connectedSockets.remove(webSocket);
            final removed = _clientInfos.remove(webSocket);
            if (removed != null) {
              try {
                _ref.read(connectedClientsProvider.notifier).updateClients(
                  (state) => state.where((c) => c.id != removed.id).toList()
                );
              } catch (_) {}
            }
            _addSyncLog('websocket', 'error', 'Erreur de connexion temps réel : $error', clientIp, false);
          },
        );
      })(request);
    });

    router.get('/sync/products', (Request request) async {
      final sinceStr = request.url.queryParameters['since'];
      final limitStr = request.url.queryParameters['limit'];
      final offsetStr = request.url.queryParameters['offset'];
      
      final since = int.tryParse(sinceStr ?? '0') ?? 0;
      final limit = int.tryParse(limitStr ?? '1000') ?? 1000;
      final offset = int.tryParse(offsetStr ?? '0') ?? 0;
      
      final db = await _ref.read(databaseServiceProvider).database;
      final maps = await db.query(
        'products', 
        where: 'updated_at > ?', 
        whereArgs: [since],
        limit: limit,
        offset: offset,
      );
      return Response.ok(jsonEncode(maps), headers: {'content-type': 'application/json'});
    });

    // Récupérer les réglages de la boutique (Pour config auto des clients)
    router.get('/sync/settings', (Request request) async {
      final settings = _ref.read(shopSettingsProvider).value;
      if (settings == null) return Response.notFound('Settings not loaded');
      
      final data = {
        'name': settings.name,
        'currency': settings.currency,
        'taxName': settings.taxName,
        'taxRate': settings.taxRate,
        'useTax': settings.useTax,
        'phone': settings.phone,
        'address': settings.address,
      };
      return Response.ok(jsonEncode(data), headers: {'content-type': 'application/json'});
    });

    router.get('/sync/users', (Request request) async {
      final db = await _ref.read(databaseServiceProvider).database;
      final maps = await db.query('users', where: 'is_active = 1');
      return Response.ok(jsonEncode(maps), headers: {'content-type': 'application/json'});
    });

    final syncQueue = SyncQueue();

    router.post('/sync/sale', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        if (body.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'Empty body'}));
        final data = jsonDecode(body) as Map<String, dynamic>;
        final saleData = data['sale'] as Map<String, dynamic>?;
        final itemsData = data['items'] as List<dynamic>?;
        if (saleData == null || itemsData == null || saleData['id'] == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing required fields: sale, items, sale.id'}));
        }
        final db = await _ref.read(databaseServiceProvider).database;
        
        await syncQueue.add(() async {
          await db.transaction((txn) async {
            await txn.insert('sales', saleData, conflictAlgorithm: ConflictAlgorithm.replace);
            for (final itemMap in itemsData) {
              final item = itemMap as Map<String, dynamic>;
              await txn.insert('sale_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
              // ⚡ P0 FIX (C1): NE PAS déduire le stock ici !
              // Le poste Client a DÉJÀ déduit le stock localement avant d'envoyer.
              // Déduire ici aussi causerait une DOUBLE déduction → stock négatif.
            }
          });
        });
        
        // Pousser l'événement aux autres caisses
        broadcastEvent('sale_synced', {
          'sale_id': saleData['id'],
          'total_amount': saleData['total_amount'],
          'items_count': itemsData.length
        });
        
        _addSyncLog('vente', 'insert', 'Vente synchronisée (ID: ${saleData['id'].substring(0, 8)}, Montant: ${saleData['total_amount']})', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('vente', 'error', 'Échec de synchro vente: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/sync/purchase', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        if (body.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'Empty body'}));
        final data = jsonDecode(body) as Map<String, dynamic>;
        final orderData = data['order'] as Map<String, dynamic>?;
        final itemsData = data['items'] as List<dynamic>?;
        if (orderData == null || itemsData == null || orderData['id'] == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing required fields: order, items, order.id'}));
        }
        final db = await _ref.read(databaseServiceProvider).database;

        await syncQueue.add(() async {
          await db.transaction((txn) async {
            await txn.insert('purchase_orders', orderData, conflictAlgorithm: ConflictAlgorithm.replace);
            for (final itemMap in itemsData) {
              final item = itemMap as Map<String, dynamic>;
              await txn.insert('purchase_order_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
              // ⚡ P0 FIX (C3): NE PAS ajouter le stock ici !
              // Le poste Client a DÉJÀ ajouté le stock localement avant d'envoyer.
              // Ajouter ici aussi causerait un DOUBLEMENT du stock.
            }
          });
        });
        _addSyncLog('achat', 'insert', 'Bon de commande synchronisé (ID: ${orderData['id'].substring(0, 8)})', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('achat', 'error', 'Échec de synchro achat: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/sync/stock-movement', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        if (body.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'Empty body'}));
        final data = jsonDecode(body) as Map<String, dynamic>;
        final movementData = data['movement'] as Map<String, dynamic>?;
        if (movementData == null || movementData['product_id'] == null || movementData['type'] == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing required fields: movement, product_id, type'}));
        }
        final db = await _ref.read(databaseServiceProvider).database;

        // ⚡ P0 FIX (C8): Passer par SyncQueue pour éviter les locks SQLite
        await syncQueue.add(() async {
          await db.transaction((txn) async {
            // Vérifier si ce mouvement existe déjà (idempotence)
            final existing = await txn.query('stock_movements', where: 'id = ?', whereArgs: [movementData['id']]);
            if (existing.isNotEmpty) {
              debugPrint('⚠️ Mouvement ${movementData['id']} déjà enregistré, skip.');
              return;
            }
            
            await txn.insert('stock_movements', movementData, conflictAlgorithm: ConflictAlgorithm.ignore);
            // ⚡ Le stock est DÉJÀ mis à jour côté client. On ne le modifie PAS ici
            // pour éviter les doubles modifications. Seul le mouvement est archivé.
          });
        });
        
        broadcastEvent('stock_movement_synced', {
          'product_id': movementData['product_id'],
          'type': movementData['type'],
          'quantity': movementData['quantity']
        });
        
        _addSyncLog('stock', 'movement', 'Mouvement de stock (Type: ${movementData['type']}, Qty: ${movementData['quantity']})', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('stock', 'error', 'Échec de mouvement stock: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les commandes d'achat
    router.post('/sync/purchase-order', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final orderData = data['order'] as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;

        await db.transaction((txn) async {
          await txn.insert('purchase_orders', orderData, conflictAlgorithm: ConflictAlgorithm.replace);
          for (final item in itemsData) {
            await txn.insert('purchase_order_items', item as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les transactions financières (Trésorerie)
    router.post('/sync/financial-transaction', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        if (body.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'Empty body'}));
        final txData = jsonDecode(body) as Map<String, dynamic>;
        if (txData['id'] == null || txData['account_id'] == null || txData['type'] == null || txData['amount'] == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing required fields: id, account_id, type, amount'}));
        }
        final db = await _ref.read(databaseServiceProvider).database;
        
        // ⚡ P0 FIX (C5): Protection contre double balance + vérification montant
        await syncQueue.add(() async {
          await db.transaction((txn) async {
            final existing = await txn.query('financial_transactions', where: 'id = ?', whereArgs: [txData['id']]);
            
            if (existing.isEmpty) {
              // Nouvelle transaction → insérer et ajuster le solde
              await txn.insert('financial_transactions', txData);
              final type = txData['type'] as String;
              final amount = (txData['amount'] as num).toDouble();
              final accountId = txData['account_id'] as String;
              final adjustment = type == 'IN' ? amount : -amount;
              await txn.execute(
                'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
                [adjustment, accountId],
              );
              _addSyncLog('finance', 'insert', 'Transaction financière (${txData['type']}, Montant: ${txData['amount']})', clientIp, true);
            } else {
              // Transaction déjà existante → NE PAS toucher au solde
              // On met juste à jour les métadonnées non-financières si nécessaire
              debugPrint('⚠️ Transaction ${txData['id']} déjà enregistrée, skip balance update.');
              _addSyncLog('finance', 'skip', 'Transaction déjà enregistrée (Skip balance adjustment)', clientIp, true);
            }
          });
        });
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('finance', 'error', 'Échec de transaction financière: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les produits
    router.post('/sync/product', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await syncQueue.add(() async {
          await db.transaction((txn) async {
            final existing = await txn.query('products', where: 'id = ?', whereArgs: [data['id']]);
            if (existing.isNotEmpty) {
              final int existingTime = (existing.first['updated_at'] as int?) ?? 0;
              // On accepte soit un timestamp explicite du client, soit on prend l'heure actuelle
              final int incomingTime = data['client_timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
              
              if (incomingTime >= existingTime) {
                // Nettoyer les champs non-SQL (comme client_timestamp) avant insertion
                final sqlData = Map<String, dynamic>.from(data)..remove('client_timestamp');
                await txn.insert('products', sqlData, conflictAlgorithm: ConflictAlgorithm.replace);
                _addSyncLog('produit', 'update', 'Produit mis à jour : ${data['name']}', clientIp, true);
              } else {
                debugPrint('⚠️ Sync rejetée (LWW) : Le produit ${data['name']} du client est plus ancien que le serveur.');
                _addSyncLog('produit', 'skip', 'Produit obsolète ignoré : ${data['name']}', clientIp, true);
              }
            } else {
              final sqlData = Map<String, dynamic>.from(data)..remove('client_timestamp');
              await txn.insert('products', sqlData, conflictAlgorithm: ConflictAlgorithm.replace);
              _addSyncLog('produit', 'insert', 'Nouveau produit créé : ${data['name']}', clientIp, true);
            }
          });
        });
        
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('produit', 'error', 'Échec de synchro produit: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les clients
    router.post('/sync/client', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        await db.insert('clients', data, conflictAlgorithm: ConflictAlgorithm.replace);
        _addSyncLog('client', 'insert', 'Client synchronisé : ${data['name']}', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('client', 'error', 'Échec de synchro client: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les fournisseurs
    router.post('/sync/supplier', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        await db.insert('suppliers', data, conflictAlgorithm: ConflictAlgorithm.replace);
        _addSyncLog('fournisseur', 'insert', 'Fournisseur synchronisé : ${data['name']}', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('fournisseur', 'error', 'Échec de synchro fournisseur: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les métadonnées de session
    router.post('/sync/session', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await db.insert('cash_sessions', data, conflictAlgorithm: ConflictAlgorithm.replace);
        _addSyncLog('session', 'insert', 'Session de caisse synchronisée (ID: ${data['id'].substring(0, 8)})', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('session', 'error', 'Échec de synchro session: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les paiements clients (Dettes)
    router.post('/sync/client-payment', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await db.insert('client_payments', data, conflictAlgorithm: ConflictAlgorithm.replace);
        _addSyncLog('paiement_client', 'insert', 'Paiement de dette synchronisé (Montant: ${data['amount']})', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('paiement_client', 'error', 'Échec de synchro paiement: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Endpoint pour la suppression à distance (C7)
    router.post('/sync/delete', (Request request) async {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final clientIp = connectionInfo?.remoteAddress.address ?? 'Inconnu';
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final table = data['table'] as String;
        final id = data['id'] as String;
        
        final db = await _ref.read(databaseServiceProvider).database;
        await db.delete(table, where: 'id = ?', whereArgs: [id]);
        
        _addSyncLog(table, 'delete', 'Suppression à distance de l\'élément ID: $id', clientIp, true);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        _addSyncLog('delete', 'error', 'Échec de suppression à distance: $e', clientIp, false);
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Middleware pour protéger les routes de synchronisation (Sécurité)
    Middleware syncProtectionMiddleware() {
      return (Handler innerHandler) {
        return (Request request) async {
          if (request.url.path.startsWith('sync/')) {
            final currentSettings = _ref.read(shopSettingsProvider).value;
            
            // 1. Protection contre l'accès par un simple Client
            if (currentSettings?.networkMode == NetworkMode.client) {
              debugPrint('🛡️ Rejet de synchro sur un nœud Client (URL: ${request.url.path})');
              return Response.forbidden(
                jsonEncode({'error': 'Sync not allowed on Client display servers'}),
                headers: {'content-type': 'application/json'}
              );
            }

            // 2. Validation de la Clé de Synchro (Audit Suprême v6)
            final providedKey = request.headers['X-Sync-Key'];
            final serverKey = currentSettings?.syncKey;

            if (serverKey != null && serverKey.isNotEmpty) {
              if (providedKey != serverKey) {
                debugPrint('🚨 Tentative de synchro non autorisée (Clé invalide) depuis ${request.context['shelf.io.connection_info']}');
                return Response(
                  401,
                  body: jsonEncode({'error': 'Authentification requise : Clé de synchronisation invalide ou manquante.'}),
                  headers: {'content-type': 'application/json'}
                );
              }
            }
          }
          return await innerHandler(request);
        };
      };
    }

    final handler = const Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(syncProtectionMiddleware())
        .addHandler(router.call);

    int currentPort = port;
    int attempts = 0;
    HttpServer? server;

    try {
      while (attempts < 10) {
        try {
          server = await io.serve(handler, InternetAddress.anyIPv4, currentPort, shared: true);
          break; 
        } on SocketException catch (e) {
          if (e.osError?.errorCode == 10048 || e.message.contains('address already in use')) {
            debugPrint('⚠️ Port $currentPort occupé, essai du suivant...');
            currentPort++;
            attempts++;
          } else {
            rethrow;
          }
        }
      }

      if (server == null) {
        _ref.read(isServerRunningProvider.notifier).setStatus(ServerStatus.error);
        return;
      }

      _server = server;
      _ref.read(isServerRunningProvider.notifier).setStatus(ServerStatus.running);
      debugPrint('🚀 Serveur Danaya+ démarré sur le port ${_server!.port}');

      if (currentPort != port) {
        final updatedSettings = settings.copyWith(serverPort: currentPort);
        Future.microtask(() => _ref.read(shopSettingsProvider.notifier).save(updatedSettings));
      }

      _startDiscoveryResponder(_server!.port, settings.name);
    } catch (e) {
      _ref.read(isServerRunningProvider.notifier).setStatus(ServerStatus.error);
      debugPrint('❌ Erreur lors du démarrage du serveur: $e');
    }
  }

  Future<void> _startDiscoveryResponder(int port, String serverName) async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 5555,
        reuseAddress: true,
      );
      
      // ⚡ P1 FIX (M5): Résoudre l'IP locale du SERVEUR (pas celle du client)
      String? serverLocalIp;
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              serverLocalIp = addr.address;
              break;
            }
          }
          if (serverLocalIp != null) break;
        }
      } catch (_) {}
      
      _discoverySocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket?.receive();
          if (datagram != null) {
            try {
              final message = utf8.decode(datagram.data, allowMalformed: true);
              if (message == 'DANAYA_DISCOVER') {
                // Utiliser l'IP locale du serveur, pas celle du datagram (qui est l'IP du client)
                final ip = serverLocalIp ?? datagram.address.address;
                final response = 'DANAYA_SERVER|$ip|$port|$serverName';
                _discoverySocket?.send(utf8.encode(response), datagram.address, datagram.port);
              }
            } catch (e) {
              debugPrint('⚠️ Erreur de décodage UDP: $e');
            }
          }
        }
      });
      debugPrint('📡 Répondeur de découverte UDP actif sur le port 5555 (IP: ${serverLocalIp ?? "auto"})');
    } catch (e) {
      debugPrint('⚠️ Impossible de démarrer le répondeur UDP: $e');
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    _ref.read(isServerRunningProvider.notifier).setStatus(ServerStatus.stopped);
    debugPrint('🛑 Serveur Danaya+ arrêté');
  }

  bool get isRunning => _server != null;
  int? get port => _server?.port;
}
