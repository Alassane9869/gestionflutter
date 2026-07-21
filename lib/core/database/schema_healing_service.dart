import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 🛡️ ALPHA-ARMOR: Service de guérison et de maintenance préventive
/// Assure que la structure physique de la base de données correspond 
/// toujours aux besoins du code, peu importe la version rapportée.
class SchemaHealingService {
  final Database db;

  SchemaHealingService(this.db);

  /// Vérifie et corrige la structure d'une table de manière déclarative.
  Future<void> ensureTableStructure(String tableName, Map<String, String> requiredColumns) async {
    try {
      final info = await db.rawQuery("PRAGMA table_info($tableName)");
      final existingCols = info.map((c) => c['name'] as String).toSet();

      for (var entry in requiredColumns.entries) {
        if (!existingCols.contains(entry.key)) {
          debugPrint('🛡️ Alpha-Armor: Réparation de $tableName (Ajout de ${entry.key})...');
          try {
            await db.execute('ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('✅ Alpha-Armor: Colonne ${entry.key} ajoutée avec succès.');
          } catch (e) {
            debugPrint('⚠️ Alpha-Armor Warning ($tableName.${entry.key}): $e');
            // On continue pour les autres colonnes
          }
        }
      }
    } catch (e) {
       debugPrint('❌ Alpha-Armor Error ($tableName): $e');
    }
  }

  /// Aligne toutes les tables critiques du système.
  Future<void> healAllCriticalTables() async {
    debugPrint('🛡️ Alpha-Armor: Début de la vérification globale du schéma...');

    // 1. Table PRODUITS
    await ensureTableStructure('products', {
      'is_active': 'INTEGER NOT NULL DEFAULT 1',
      'is_synced': 'INTEGER NOT NULL DEFAULT 0',
      'unit': 'TEXT',
      'is_service': 'INTEGER NOT NULL DEFAULT 0',
      'reference': 'TEXT',
      'weighted_average_cost': 'REAL NOT NULL DEFAULT 0.0',
      'location': 'TEXT',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
    });

    // 2. Table VENTES
    await ensureTableStructure('sales', {
      'credit_amount': 'REAL NOT NULL DEFAULT 0.0',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
      'account_id': 'TEXT',
      'payment_method': 'TEXT',
    });

    // 3. Table LIGNES DE VENTE
    await ensureTableStructure('sale_items', {
      'cost_price': 'REAL NOT NULL DEFAULT 0.0',
      'unit': 'TEXT',
      'description': 'TEXT',
      'discount_percent': 'REAL NOT NULL DEFAULT 0.0',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
    });

    try {
      final columns = await db.rawQuery("PRAGMA table_info(sale_items)");
      final productIdCol = columns.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['name'] == 'product_id',
        orElse: () => <String, dynamic>{},
      );
      if (productIdCol.isNotEmpty && productIdCol['notnull'] == 1) {
        debugPrint('🛡️ Alpha-Armor: Healing sale_items (making product_id nullable)...');
        await db.transaction((txn) async {
          await txn.execute('PRAGMA foreign_keys = OFF');
          await txn.execute('ALTER TABLE sale_items RENAME TO sale_items_old');
          await txn.execute('''
            CREATE TABLE sale_items(
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL,
              product_id TEXT,
              quantity REAL NOT NULL,
              returned_quantity REAL NOT NULL DEFAULT 0.0,
              unit_price REAL NOT NULL,
              discount_percent REAL NOT NULL DEFAULT 0.0,
              cost_price REAL NOT NULL DEFAULT 0.0,
              unit TEXT,
              description TEXT,
              updated_at INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
              FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
            )
          ''');
          await txn.execute('''
            INSERT INTO sale_items (
              id, sale_id, product_id, quantity, returned_quantity, 
              unit_price, discount_percent, cost_price, unit, description, 
              updated_at, is_deleted
            )
            SELECT 
              id, sale_id, product_id, quantity, returned_quantity, 
              unit_price, discount_percent, cost_price, unit, description, 
              updated_at, is_deleted
            FROM sale_items_old
          ''');
          await txn.execute('DROP TABLE sale_items_old');
          await txn.execute('PRAGMA foreign_keys = ON');
        });
        debugPrint('✅ Alpha-Armor: sale_items healed successfully (product_id is now nullable).');
      }
    } catch (e) {
      debugPrint('⚠️ Alpha-Armor Warning (Healing sale_items nullable check): $e');
    }
    
    // 4. Table UTILISATEURS
    await ensureTableStructure('users', {
      'email': 'TEXT',
      'phone': 'TEXT',
      'address': 'TEXT',
      'birth_date': 'TEXT',
      'hire_date': 'TEXT',
      'nationality': 'TEXT',
      'permissions': 'TEXT NOT NULL DEFAULT "{}"',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
    });

    // 5. Table TRANSACTIONS FINANCIÈRES
    await ensureTableStructure('financial_transactions', {
      'session_id': 'TEXT',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
    });

    // 6. Table CLIENTS
    await ensureTableStructure('clients', {
      'email': 'TEXT',
      'address': 'TEXT',
      'max_credit': 'REAL NOT NULL DEFAULT 50000.0',
      'loyalty_points': 'REAL NOT NULL DEFAULT 0.0',
      'birth_date': 'TEXT',
      'last_purchase_date': 'TEXT',
      'last_marketing_reminder_date': 'TEXT',
      'is_synced': 'INTEGER NOT NULL DEFAULT 0',
      'updated_at': 'INTEGER NOT NULL DEFAULT 0',
      'is_deleted': 'INTEGER NOT NULL DEFAULT 0',
    });

    // 7. Table FOURNISSEURS
    await ensureTableStructure('suppliers', {
      'logo_path': 'TEXT',
    });

    // Ensure all cloud sync tables have their required syncing column and triggers
    
    // Table EMPLOYEE_CONTRACTS
    await ensureTableStructure('employee_contracts', {
      'school_name': 'TEXT',
    });

    final cloudSyncTables = [
      'users',
      'financial_accounts',
      'products',
      'clients',
      'suppliers',
      'sales',
      'stock_movements',
      'financial_transactions',
      'cash_sessions',
      'purchase_orders',
      'client_payments',
      'supplier_payments',
      'quotes',
      'loyalty_settings',
      'warehouses',
      'warehouse_stock',
      'stock_audits',
      'activity_logs',
      'employee_contracts',
      'payrolls',
      'leave_requests'
    ];

    for (final table in cloudSyncTables) {
      await ensureTableStructure(table, {
        'is_synced_to_cloud': 'INTEGER NOT NULL DEFAULT 0',
      });
      await _ensureCloudSyncTrigger(table);
    }

    debugPrint('🏁 Alpha-Armor: Système de données stabilisé.');
  }

  Future<void> _ensureCloudSyncTrigger(String tableName) async {
    try {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trigger_${tableName}_cloud_sync
        AFTER UPDATE ON $tableName
        FOR EACH ROW
        WHEN (old.is_synced_to_cloud = 1 AND new.is_synced_to_cloud = 1)
        BEGIN
          UPDATE $tableName SET is_synced_to_cloud = 0 WHERE id = old.id;
        END;
      ''');
    } catch (e) {
      debugPrint('⚠️ Alpha-Armor trigger healing warning ($tableName): $e');
    }
  }

  /// Maintenance "Nucléaire" pour restaurer les performances
  Future<void> performSupremeMaintenance() async {
    try {
      debugPrint('🧹 Alpha-Armor: Lancement maintenance suprême...');
      await db.execute('PRAGMA optimize');
      await db.execute('ANALYZE');
      debugPrint('✅ Alpha-Armor: Maintenance terminée.');
    } catch (e) {
      debugPrint('⚠️ Alpha-Armor Maintenance Warning: $e');
    }
  }
}
