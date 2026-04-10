import 'package:flutter/foundation.dart';
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

// Provider pour l'état du serveur (Public pour l'UI)
enum ServerStatus { stopped, starting, running, error }

final isServerRunningProvider = NotifierProvider<ServerStatusNotifier, ServerStatus>(() => ServerStatusNotifier());

class ServerStatusNotifier extends Notifier<ServerStatus> {
  @override
  ServerStatus build() => ServerStatus.stopped;
  void setStatus(ServerStatus value) => state = value;
}

final serverServiceProvider = Provider<ServerService>((ref) => ServerService(ref));

class ServerService {
  final Ref _ref;
  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  final List<WebSocketChannel> _connectedSockets = [];

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
            oldSettings.name != newSettings.name) {
          debugPrint('📺 Réglages Afficheur modifiés, envoi de la mise à jour en direct...');
          broadcastEvent('settings_updated', {
             'theme': newSettings.customerDisplayTheme,
             'use3D': newSettings.useCustomerDisplay3D,
             'enableTicker': newSettings.enableCustomerDisplayTicker,
             'messages': newSettings.customerDisplayMessages,
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
      debugPrint('📺 /display - syncKey passée au HTML: "\${currentSettings.syncKey}"');
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
        debugPrint('🟢 Nouveau client connecté au WebSocket');
        _connectedSockets.add(webSocket);
        
        webSocket.stream.listen(
          (message) {
            debugPrint('WS Reçu: $message');
          },
          onDone: () {
            debugPrint('🔴 Client WebSocket déconnecté');
            _connectedSockets.remove(webSocket);
          },
          onError: (error) {
            debugPrint('⚠️ Erreur WebSocket: $error');
            _connectedSockets.remove(webSocket);
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

    router.post('/sync/sale', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final saleData = data['sale'] as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await db.transaction((txn) async {
          await txn.insert('sales', saleData, conflictAlgorithm: ConflictAlgorithm.replace);
          for (final itemMap in itemsData) {
            final item = itemMap as Map<String, dynamic>;
            await txn.insert('sale_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
            if (item['product_id'] != null) {
              await txn.execute(
                'UPDATE products SET quantity = quantity - ? WHERE id = ?',
                [item['quantity'], item['product_id']],
              );
            }
          }
        });
        
        // Pousser l'événement aux autres caisses
        broadcastEvent('sale_synced', {
          'sale_id': saleData['id'],
          'total_amount': saleData['total_amount'],
          'items_count': itemsData.length
        });
        
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/sync/purchase', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final orderData = data['order'] as Map<String, dynamic>;
        final itemsData = data['items'] as List<dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;

        await db.transaction((txn) async {
          await txn.insert('purchase_orders', orderData, conflictAlgorithm: ConflictAlgorithm.replace);
          for (final itemMap in itemsData) {
            final item = itemMap as Map<String, dynamic>;
            await txn.insert('purchase_order_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
            // On ne met pas à jour le stock ici car le client l'a déjà fait localement
            // MAIS sur le serveur central (Admin), on DOIT mettre à jour le stock global
            if (item['product_id'] != null) {
              await txn.execute(
                'UPDATE products SET quantity = quantity + ? WHERE id = ?',
                [item['quantity'], item['product_id']],
              );
            }
          }
        });
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/sync/stock-movement', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final movementData = data['movement'] as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;

        await db.transaction((txn) async {
          await txn.insert('stock_movements', movementData, conflictAlgorithm: ConflictAlgorithm.replace);
          final type = movementData['type'] as String;
          final qty = movementData['quantity'] as num;
          final productId = movementData['product_id'] as String;

          if (type == 'IN') {
            await txn.execute('UPDATE products SET quantity = quantity + ? WHERE id = ?', [qty, productId]);
          } else if (type == 'OUT') {
            await txn.execute('UPDATE products SET quantity = quantity - ? WHERE id = ?', [qty, productId]);
          }
        });
        
        broadcastEvent('stock_movement_synced', {
          'product_id': movementData['product_id'],
          'type': movementData['type'],
          'quantity': movementData['quantity']
        });
        
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
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
      try {
        final body = await request.readAsString();
        final txData = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await db.transaction((txn) async {
          // Check if already exists to avoid double balancing
          final existing = await txn.query('financial_transactions', where: 'id = ?', whereArgs: [txData['id']]);
          
          await txn.insert('financial_transactions', txData, conflictAlgorithm: ConflictAlgorithm.replace);
          
          if (existing.isEmpty) {
            final type = txData['type'] as String;
            final amount = (txData['amount'] as num).toDouble();
            final accountId = txData['account_id'] as String;
            final adjustment = type == 'IN' ? amount : -amount;
            
            await txn.execute(
              'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
              [adjustment, accountId],
            );
          }
        });
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les produits
    router.post('/sync/product', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        await db.insert('products', data, conflictAlgorithm: ConflictAlgorithm.replace);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les clients
    router.post('/sync/client', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        await db.insert('clients', data, conflictAlgorithm: ConflictAlgorithm.replace);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les fournisseurs
    router.post('/sync/supplier', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        await db.insert('suppliers', data, conflictAlgorithm: ConflictAlgorithm.replace);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les métadonnées de session
    router.post('/sync/session', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await db.insert('cash_sessions', data, conflictAlgorithm: ConflictAlgorithm.replace);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // Synchroniser les paiements clients (Dettes)
    router.post('/sync/client-payment', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final db = await _ref.read(databaseServiceProvider).database;
        
        await db.insert('client_payments', data, conflictAlgorithm: ConflictAlgorithm.replace);
        return Response.ok(jsonEncode({'status': 'success'}), headers: {'content-type': 'application/json'});
      } catch (e) {
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
      _discoverySocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket?.receive();
          if (datagram != null) {
            try {
              final message = utf8.decode(datagram.data, allowMalformed: true);
              if (message == 'DANAYA_DISCOVER') {
                final response = 'DANAYA_SERVER|${datagram.address.address}|$port|$serverName';
                _discoverySocket?.send(utf8.encode(response), datagram.address, datagram.port);
              }
            } catch (e) {
              debugPrint('⚠️ Erreur de décodage UDP: $e');
            }
          }
        }
      });
      debugPrint('📡 Répondeur de découverte UDP actif sur le port 5555');
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
