import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final cloudSyncServiceProvider = Provider((ref) {
  final service = CloudSyncService(ref);
  ref.onDispose(() => service.stopBackgroundSync());
  return service;
});

enum CloudSyncState { idle, syncing, success, error }

class CloudSyncStatus {
  final CloudSyncState state;
  final String message;
  final DateTime? lastSyncTime;
  final int pendingCount;

  CloudSyncStatus({
    required this.state,
    this.message = '',
    this.lastSyncTime,
    this.pendingCount = 0,
  });

  CloudSyncStatus copyWith({
    CloudSyncState? state,
    String? message,
    DateTime? lastSyncTime,
    int? pendingCount,
  }) {
    return CloudSyncStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

class CloudSyncStatusNotifier extends Notifier<CloudSyncStatus> {
  @override
  CloudSyncStatus build() {
    // Load last sync time from SharedPreferences asynchronously
    _loadLastSyncTime();
    return CloudSyncStatus(state: CloudSyncState.idle);
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt('last_cloud_sync_time');
      if (lastSyncMs != null) {
        state = state.copyWith(lastSyncTime: DateTime.fromMillisecondsSinceEpoch(lastSyncMs));
      }
    } catch (_) {}
  }

  void updateState({
    required CloudSyncState syncState,
    String message = '',
    DateTime? lastSyncTime,
    int? pendingCount,
  }) {
    state = state.copyWith(
      state: syncState,
      message: message,
      lastSyncTime: lastSyncTime,
      pendingCount: pendingCount,
    );

    if (lastSyncTime != null) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('last_cloud_sync_time', lastSyncTime.millisecondsSinceEpoch);
      });
    }
  }
}

final cloudSyncStatusProvider = NotifierProvider<CloudSyncStatusNotifier, CloudSyncStatus>(
  CloudSyncStatusNotifier.new,
);

class CloudSyncService {
  final Ref _ref;
  Timer? _syncTimer;
  bool _isSyncing = false;

  CloudSyncService(this._ref);

  String _buildUrl(String table, [String? id]) {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || settings.cloudEndpoint.isEmpty || settings.cloudSyncKey.isEmpty) {
      return '';
    }
    var endpoint = settings.cloudEndpoint;
    if (!endpoint.endsWith('/')) {
      endpoint += '/';
    }
    final key = Uri.encodeComponent(settings.cloudSyncKey);
    if (id != null) {
      return '$endpoint$key/$table/${Uri.encodeComponent(id)}.json';
    } else {
      return '$endpoint$key/$table.json';
    }
  }

  /// Start background periodic synchronization timer (e.g. every 5 minutes)
  void startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final settings = _ref.read(shopSettingsProvider).value;
      if (settings?.networkMode == NetworkMode.cloud) {
        debugPrint('☁️ Background cloud synchronization triggered...');
        await runFullSyncCycle();
      }
    });
  }

  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Valider une connexion Cloud (vérification uniquement, PAS d'enregistrement).
  /// Returns:
  /// - 'success' si la clé est enregistrée et le serveur joignable.
  /// - 'not_found' si la clé n'existe pas sur ce Firebase.
  /// - 'error:...' avec explication si la connexion échoue.
  Future<String> validateCloudConnection({
    required String endpoint,
    required String key,
  }) async {
    if (endpoint.isEmpty || key.isEmpty) {
      return "error:L'URL du cloud et la clé de boutique ne peuvent pas être vides.";
    }

    var base = endpoint;
    if (!base.endsWith('/')) {
      base += '/';
    }

    final keyEncoded = Uri.encodeComponent(key);

    try {
      // 1. Vérifier si des données existent sous cette clé (shallow = rapide, pas de téléchargement)
      final shallowUrl = '$base$keyEncoded.json?shallow=true';
      final response = await http.get(
        Uri.parse(shallowUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return "error:Le serveur Firebase a retourné une erreur (code: ${response.statusCode}).";
      }

      if (response.body == 'null' || response.body.isEmpty) {
        // Aucune donnée sous cette clé → la boutique n'existe pas
        return 'not_found';
      }

      // Des données existent (metadata, users, products, etc.) → clé valide
      return 'success';
    } on SocketException {
      return "error:Impossible de se connecter au serveur. Vérifiez votre connexion internet.";
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return "error:Le serveur Cloud ne répond pas (délai dépassé). Vérifiez l'URL.";
      }
      return "error:Impossible de se connecter au Cloud. Détails: $e";
    }
  }

  /// Enregistrer une nouvelle boutique sur le Cloud.
  /// Action séparée et explicite — doit être appelée UNIQUEMENT après vérification du PIN admin.
  Future<String> registerShopOnCloud({
    required String endpoint,
    required String key,
  }) async {
    if (endpoint.isEmpty || key.isEmpty) {
      return "error:L'URL et la clé ne peuvent pas être vides.";
    }

    // Sécurité : vérifier d'abord que la clé n'existe pas déjà
    final checkResult = await validateCloudConnection(endpoint: endpoint, key: key);
    if (checkResult == 'success') {
      return 'success'; // Déjà enregistrée, rien à faire
    }
    if (checkResult.startsWith('error:')) {
      return checkResult; // Erreur de connexion, on ne crée rien
    }

    // checkResult == 'not_found' → on peut enregistrer en toute sécurité
    var base = endpoint;
    if (!base.endsWith('/')) {
      base += '/';
    }
    final keyEncoded = Uri.encodeComponent(key);
    final urlStr = '$base$keyEncoded/metadata.json';

    try {
      final shopName = _ref.read(shopSettingsProvider).value?.name ?? 'Ma Boutique';
      final payload = {
        'registered': true,
        'shopName': shopName,
        'createdAt': DateTime.now().toIso8601String(),
        'version': 1,
      };
      final putResponse = await http.put(
        Uri.parse(urlStr),
        body: jsonEncode(payload),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        return 'success';
      } else {
        return "error:Échec de l'enregistrement (code: ${putResponse.statusCode}).";
      }
    } catch (e) {
      return "error:Erreur lors de l'enregistrement: $e";
    }
  }

  /// Run check of pending changes and push/pull in one run
  Future<void> runFullSyncCycle() async {
    if (_isSyncing) return;
    
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || settings.networkMode != NetworkMode.cloud) {
      return;
    }

    _isSyncing = true;
    _ref.read(cloudSyncStatusProvider.notifier).updateState(
      syncState: CloudSyncState.syncing,
      message: 'Vérification de la clé de boutique...',
    );

    try {
      // Validation de la connexion et de la clé (handshake)
      final checkResult = await validateCloudConnection(
        endpoint: settings.cloudEndpoint,
        key: settings.cloudSyncKey,
      );

      if (checkResult != 'success') {
        final remaining = await getPendingSyncCount();
        _ref.read(cloudSyncStatusProvider.notifier).updateState(
          syncState: CloudSyncState.error,
          message: checkResult == 'not_found'
              ? "Clé de boutique non enregistrée. Validez la connexion dans les paramètres."
              : checkResult.startsWith('error:') ? checkResult.substring(6) : checkResult,
          pendingCount: remaining,
        );
        _isSyncing = false;
        return;
      }

      final db = await _ref.read(databaseServiceProvider).database;
      final tables = [
        'users',
        'financial_accounts',
        'loyalty_settings',
        'warehouses',
        'warehouse_stock',
        'products',
        'clients',
        'suppliers',
        'sales',
        'purchase_orders',
        'client_payments',
        'supplier_payments',
        'quotes',
        'stock_movements',
        'financial_transactions',
        'cash_sessions',
        'stock_audits',
        'employee_contracts',
        'payrolls',
        'leave_requests'
      ];
      debugPrint('=== ☁️ DIAGNOSTIC CLOUD SYNC ===');
      for (final t in tables) {
        final totalRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM $t');
        final unsyncedRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM $t WHERE is_synced_to_cloud = 0');
        debugPrint('Table $t | Total: ${totalRes.first['cnt']} | Non-sync: ${unsyncedRes.first['cnt']}');
      }

      final pending = await getPendingSyncCount();
      _ref.read(cloudSyncStatusProvider.notifier).updateState(
        syncState: CloudSyncState.syncing,
        message: 'Envoi des données locales ($pending éléments)...',
        pendingCount: pending,
      );

      // 1. Push local edits to cloud
      await pushLocalChanges();

      // 2. Pull remote edits from cloud (products & clients)
      _ref.read(cloudSyncStatusProvider.notifier).updateState(
        syncState: CloudSyncState.syncing,
        message: 'Récupération des modifications distantes...',
      );
      await pullCloudChanges();

      final remaining = await getPendingSyncCount();
      _ref.read(cloudSyncStatusProvider.notifier).updateState(
        syncState: CloudSyncState.success,
        message: 'Synchronisation cloud terminée avec succès !',
        lastSyncTime: DateTime.now(),
        pendingCount: remaining,
      );
    } catch (e) {
      debugPrint('❌ Erreur de synchronisation cloud: $e');
      final remaining = await getPendingSyncCount();
      _ref.read(cloudSyncStatusProvider.notifier).updateState(
        syncState: CloudSyncState.error,
        message: 'Erreur: ${e.toString()}',
        pendingCount: remaining,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Count all unsynced items in key tables
  Future<int> getPendingSyncCount() async {
    try {
      final db = await _ref.read(databaseServiceProvider).database;
      final tables = [
        'users',
        'financial_accounts',
        'loyalty_settings',
        'warehouses',
        'warehouse_stock',
        'products',
        'clients',
        'suppliers',
        'sales',
        'purchase_orders',
        'client_payments',
        'supplier_payments',
        'quotes',
        'stock_movements',
        'financial_transactions',
        'cash_sessions',
        'stock_audits',
        'employee_contracts',
        'payrolls',
        'leave_requests'
      ];
      int total = 0;
      for (final table in tables) {
        final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table WHERE is_synced_to_cloud = 0');
        if (res.isNotEmpty) {
          total += (res.first['cnt'] as int? ?? 0);
        }
      }
      return total;
    } catch (e) {
      debugPrint('Error counting pending sync: $e');
      return 0;
    }
  }

  /// Compress product image to max 800px width/height and return base64
  Future<String?> _compressAndEncodeImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes < 80 * 1024) {
        return base64Encode(bytes);
      }

      // Decode and scale to max width of 800px
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 800,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return base64Encode(bytes);

      final compressedBytes = byteData.buffer.asUint8List();
      return base64Encode(compressedBytes);
    } catch (e) {
      debugPrint('⚠️ Image compression error: $e');
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return base64Encode(bytes);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Push all locally modified rows to Firebase in batches
  Future<void> pushLocalChanges() async {
    final db = await _ref.read(databaseServiceProvider).database;
    final tables = [
      'users',
      'financial_accounts',
      'loyalty_settings',
      'warehouses',
      'warehouse_stock',
      'products',
      'clients',
      'suppliers',
      'sales',
      'purchase_orders',
      'client_payments',
      'supplier_payments',
      'quotes',
      'stock_movements',
      'financial_transactions',
      'cash_sessions',
      'stock_audits',
      'employee_contracts',
      'payrolls',
      'leave_requests'
    ];

    int remaining = await getPendingSyncCount();
    const int batchSize = 100;

    for (final table in tables) {
      final rows = await db.query(
        table,
        where: 'is_synced_to_cloud = 0',
      );

      if (rows.isEmpty) continue;

      for (int i = 0; i < rows.length; i += batchSize) {
        final end = (i + batchSize < rows.length) ? i + batchSize : rows.length;
        final chunk = rows.sublist(i, end);

        final Map<String, dynamic> patchPayload = {};
        final List<String> chunkIds = [];

        for (final row in chunk) {
          final Map<String, dynamic> payload = Map.from(row);
          final id = payload['id']?.toString();
          if (id == null) continue;

          chunkIds.add(id);

          // Strip sqlite columns that shouldn't go to Firebase
          payload.remove('is_synced_to_cloud');

          // 🔒 SÉCURITÉ: Ne jamais envoyer les données sensibles au cloud
          if (table == 'users') {
            payload.remove('recovery_token');
            payload.remove('pin_hash');  // Ne JAMAIS synchroniser les hachés de PIN
          }

          // Handle image encoding for products
          if (table == 'products' && payload['image_path'] != null) {
            final String imagePath = payload['image_path'] as String;
            if (imagePath.isNotEmpty) {
              final base64Image = await _compressAndEncodeImage(imagePath);
              if (base64Image != null) {
                payload['image_base64'] = base64Image;
              }
            }
          }

          // For sales, purchase orders, quotes, stock audits, also include details if applicable
          if (table == 'sales') {
            final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [id]);
            payload['items'] = items;
          } else if (table == 'purchase_orders') {
            final items = await db.query('purchase_order_items', where: 'order_id = ?', whereArgs: [id]);
            payload['items'] = items;
          } else if (table == 'quotes') {
            final items = await db.query('quote_items', where: 'quote_id = ?', whereArgs: [id]);
            payload['items'] = items;
          } else if (table == 'stock_audits') {
            final items = await db.query('stock_audit_items', where: 'audit_id = ?', whereArgs: [id]);
            payload['items'] = items;
          }

          patchPayload[id] = payload;
        }

        if (patchPayload.isEmpty) continue;

        final urlStr = _buildUrl(table);
        if (urlStr.isEmpty) continue;

        final response = await http.patch(
          Uri.parse(urlStr),
          body: jsonEncode(patchPayload),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
          // Mark chunk as synced locally using a batch database update
          final batch = db.batch();
          for (final id in chunkIds) {
            batch.update(
              table,
              {'is_synced_to_cloud': 1},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
          await batch.commit(noResult: true);

          remaining -= chunkIds.length;
          if (remaining < 0) remaining = 0;
          _ref.read(cloudSyncStatusProvider.notifier).updateState(
            syncState: CloudSyncState.syncing,
            message: 'Envoi des données locales ($remaining restants)...',
            pendingCount: remaining,
          );
        } else {
          throw HttpException('Firebase server responded with status: ${response.statusCode}');
        }
      }
    }
  }

  /// Pull remote edits for all tables (merge logic)
  Future<void> pullCloudChanges() async {
    final db = await _ref.read(databaseServiceProvider).database;
    final tablesToPull = [
      'users',
      'financial_accounts',
      'loyalty_settings',
      'warehouses',
      'warehouse_stock',
      'products',
      'clients',
      'suppliers',
      'sales',
      'purchase_orders',
      'client_payments',
      'supplier_payments',
      'quotes',
      'stock_movements',
      'financial_transactions',
      'cash_sessions',
      'stock_audits',
      'employee_contracts',
      'payrolls',
      'leave_requests'
    ];

    final appDir = await getApplicationSupportDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'product_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Deactivate foreign keys temporarily for pull operation to prevent sqlite_error 787
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      for (final table in tablesToPull) {
        final urlStr = _buildUrl(table);
        if (urlStr.isEmpty) continue;

        final response = await http.get(
          Uri.parse(urlStr),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (response.body == 'null' || response.body.isEmpty) continue;

          final Map<String, dynamic> remoteData = jsonDecode(response.body);
          
          await db.transaction((txn) async {
            for (final entry in remoteData.entries) {
              final Map<String, dynamic> remoteRow = Map<String, dynamic>.from(entry.value as Map);
              
              // Handle nested items details
              if (table == 'sales' && remoteRow.containsKey('items')) {
                final itemsList = remoteRow['items'] as List?;
                if (itemsList != null) {
                  for (final item in itemsList) {
                    final itemMap = Map<String, dynamic>.from(item as Map);
                    // Ensure schema alignment for sale_items
                    final itemTableInfo = await txn.rawQuery('PRAGMA table_info(sale_items)');
                    final itemColumns = itemTableInfo.map((c) => c['name'] as String).toList();
                    final Map<String, dynamic> localItemPayload = {};
                    for (final col in itemColumns) {
                      if (itemMap.containsKey(col)) {
                        localItemPayload[col] = itemMap[col];
                      }
                    }
                    await txn.insert(
                      'sale_items',
                      localItemPayload,
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                  }
                }
              } else if (table == 'purchase_orders' && remoteRow.containsKey('items')) {
                final itemsList = remoteRow['items'] as List?;
                if (itemsList != null) {
                  for (final item in itemsList) {
                    final itemMap = Map<String, dynamic>.from(item as Map);
                    final itemTableInfo = await txn.rawQuery('PRAGMA table_info(purchase_order_items)');
                    final itemColumns = itemTableInfo.map((c) => c['name'] as String).toList();
                    final Map<String, dynamic> localItemPayload = {};
                    for (final col in itemColumns) {
                      if (itemMap.containsKey(col)) {
                        localItemPayload[col] = itemMap[col];
                      }
                    }
                    await txn.insert(
                      'purchase_order_items',
                      localItemPayload,
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                  }
                }
              } else if (table == 'quotes' && remoteRow.containsKey('items')) {
                final itemsList = remoteRow['items'] as List?;
                if (itemsList != null) {
                  for (final item in itemsList) {
                    final itemMap = Map<String, dynamic>.from(item as Map);
                    final itemTableInfo = await txn.rawQuery('PRAGMA table_info(quote_items)');
                    final itemColumns = itemTableInfo.map((c) => c['name'] as String).toList();
                    final Map<String, dynamic> localItemPayload = {};
                    for (final col in itemColumns) {
                      if (itemMap.containsKey(col)) {
                        localItemPayload[col] = itemMap[col];
                      }
                    }
                    await txn.insert(
                      'quote_items',
                      localItemPayload,
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                  }
                }
              } else if (table == 'stock_audits' && remoteRow.containsKey('items')) {
                final itemsList = remoteRow['items'] as List?;
                if (itemsList != null) {
                  for (final item in itemsList) {
                    final itemMap = Map<String, dynamic>.from(item as Map);
                    final itemTableInfo = await txn.rawQuery('PRAGMA table_info(stock_audit_items)');
                    final itemColumns = itemTableInfo.map((c) => c['name'] as String).toList();
                    final Map<String, dynamic> localItemPayload = {};
                    for (final col in itemColumns) {
                      if (itemMap.containsKey(col)) {
                        localItemPayload[col] = itemMap[col];
                      }
                    }
                    await txn.insert(
                      'stock_audit_items',
                      localItemPayload,
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                  }
                }
              }

              // Handle product image recovery from base64
              if (table == 'products' && remoteRow.containsKey('image_base64')) {
                final base64Str = remoteRow['image_base64'] as String?;
                if (base64Str != null && base64Str.isNotEmpty) {
                  try {
                    final productId = remoteRow['id'] as String;
                    final fileName = 'img_$productId.png';
                    final localPath = p.join(imagesDir.path, fileName);
                    
                    final file = File(localPath);
                    if (!await file.exists()) {
                      final bytes = base64Decode(base64Str);
                      await file.writeAsBytes(bytes);
                    }
                    remoteRow['image_path'] = localPath;
                  } catch (e) {
                    debugPrint('⚠️ Error decoding product image from cloud: $e');
                  }
                }
              }

              // Clean up any extra fields that might not match local columns
              remoteRow.remove('items'); // Embedded in parent payload but not a column
              remoteRow.remove('image_base64'); // base64 payload is helper for cloud
              
              // Set sync flags
              remoteRow['is_synced_to_cloud'] = 1;

              // Handle is_synced (multi-station)
              if (remoteRow.containsKey('is_synced')) {
                remoteRow['is_synced'] = 1;
              }

              // Ensure schema alignment
              final Map<String, dynamic> localPayload = {};
              final tableInfo = await txn.rawQuery('PRAGMA table_info($table)');
              final columns = tableInfo.map((c) => c['name'] as String).toList();

              for (final col in columns) {
                if (remoteRow.containsKey(col)) {
                  localPayload[col] = remoteRow[col];
                }
              }

              // 🔒 MERGE INTELLIGENT: Ne pas écraser les données locales non synchronisées
              final rowId = localPayload['id'];
              if (rowId != null) {
                final existing = await txn.query(table, where: 'id = ?', whereArgs: [rowId], limit: 1);
                if (existing.isEmpty) {
                  // Nouvelle donnée depuis le cloud → insérer
                  await txn.insert(table, localPayload, conflictAlgorithm: ConflictAlgorithm.ignore);
                } else {
                  final localRow = existing.first;
                  final localHasUnsavedChanges = (localRow['is_synced_to_cloud'] as int? ?? 1) == 0;
                  if (localHasUnsavedChanges) {
                    // ⚠️ Données locales non synchronisées → on garde la version locale
                    debugPrint('⚠️ Pull skip: $table/$rowId — modifications locales non envoyées');
                  } else {
                    // Données locales déjà synchronisées → accepter la version cloud
                    // 🔒 SÉCURITÉ: Ne JAMAIS écraser le recovery_token local
                    if (table == 'users') {
                      localPayload['recovery_token'] = localRow['recovery_token'];
                    }
                    await txn.update(table, localPayload, where: 'id = ?', whereArgs: [rowId]);
                  }
                }
              } else {
                // Pas d'ID → fallback insert
                await txn.insert(table, localPayload, conflictAlgorithm: ConflictAlgorithm.ignore);
              }
            }
          });
        }
      }
    } finally {
      // Re-enable foreign keys
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }
}
