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
    
    // 4. Table UTILISATEURS
    await ensureTableStructure('users', {
      'email': 'TEXT',
      'phone': 'TEXT',
      'address': 'TEXT',
      'birth_date': 'TEXT',
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

    debugPrint('🏁 Alpha-Armor: Système de données stabilisé.');
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
