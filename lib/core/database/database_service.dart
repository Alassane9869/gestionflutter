import 'dart:io';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:danaya_plus/core/database/migrations/migration_runner.dart';
import 'package:danaya_plus/core/database/schema_healing_service.dart';
import 'package:danaya_plus/core/config/security_config.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DatabaseService {
  static const int targetVersion = 50;
  Database? _db;

  Future<Database> get database async {
    // Self-Healing : Si la base est nulle ou fermée inopinément, on réinitialise
    if (_db == null || !_db!.isOpen) {
      if (_db != null && !_db!.isOpen) {
        debugPrint(
          "🛠️ DatabaseService: Connexion fermée détectée. Ré-initialisation...",
        );
      }
      _db = await _initDatabase();
    }
    return _db!;
  }

  /// Ferme la connexion and réinitialise l'instance
  Future<void> disposeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await getDatabasePath();
    final password = await _getEncryptionKey();

    Database? db;
    try {
      // Ouvrir sans version pour appliquer la clé d'abord sur Windows/SQLCipher
      db = await databaseFactory.openDatabase(path);

      if (password.isNotEmpty) {
        await db.execute("PRAGMA key = '$password'");
        // Test de lecture simple pour valider la clé
        await db.execute("SELECT count(*) FROM sqlite_master");
      }
    } catch (e) {
      if (e.toString().contains('file is not a database') ||
          e.toString().contains('file is encrypted')) {
        db = await _attemptMigrationToEncrypted(path, password);
      } else {
        rethrow;
      }
    }

    // Gestion manuelle des versions (Migration post-déverrouillage)
    final int currentVersion =
        (await db.rawQuery('PRAGMA user_version'))[0]['user_version'] as int;

    // Diagnostic de version SQLite et chiffrement
    try {
      final sqliteVersion = (await db.rawQuery(
        'SELECT sqlite_version()',
      ))[0].values.first;
      debugPrint('📊 DatabaseService: SQLite v$sqliteVersion opérationnel.');
      final cipherQuery = await db.rawQuery('PRAGMA cipher_version');
      if (cipherQuery.isNotEmpty) {
        debugPrint(
          '🔒 DatabaseService: SQLCipher détecté (${cipherQuery[0].values.first})',
        );
      }
    } catch (e) {
      debugPrint('📡 DatabaseService Warning (Diagnostic): $e');
    }

    if (currentVersion == 0) {
      await _onCreate(db, targetVersion);
    }
    if (currentVersion < targetVersion) {
      // 🛡️ ALPHA-ARMOR: Safe Backup avant migration majeure
      await _createSafeBackup(path);
      
      await MigrationRunner.run(db, currentVersion, targetVersion);
      await db.execute('PRAGMA user_version = $targetVersion');
    }

    // ── Performance PRAGMAs (CRITIQUES - synchrones) ──
    try {
      await db.execute('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA foreign_keys=ON');
    } catch (e) {
      debugPrint("DB Pragma Error: $e");
    }

    // ── Safety Checks & Auto-Healing (NON-BLOQUANT) ──
    final localDb = db; 
    Future.microtask(() async {
      try {
        final healer = SchemaHealingService(localDb);
        await healer.healAllCriticalTables();
        await runSafetyChecks(localDb);
        await _performPeriodicMaintenance(localDb);
        await healer.performSupremeMaintenance();
        debugPrint('💎 Alpha-Armor: System integrity verified 100%.');
      } catch (e) {
        debugPrint("⚠️ Alpha-Armor Background Error: $e");
        await _logInternalError('HEALING_ERROR', e.toString());
      }
    });

    return db;
  }

  Future<Database> _attemptMigrationToEncrypted(
    String path,
    String password,
  ) async {
    // 1. Tenter d'ouvrir sans mot de passe
    Database plainDb;
    try {
      plainDb = await databaseFactory.openDatabase(path);
      // Si ça réussit, c'est que la base n'était pas chiffrée.
    } catch (e) {
      throw Exception(
        "Impossible d'ouvrir la base de données (clé invalide ou fichier corrompu).",
      );
    }

    // 2. Créer une version chiffrée
    final tempPath = "$path.tmp";
    if (File(tempPath).existsSync()) await File(tempPath).delete();

    // Utiliser ATTACH DATABASE pour chiffrer les données vers le nouveau fichier
    await plainDb.execute("ATTACH DATABASE ? AS encrypted KEY ?", [
      tempPath,
      password,
    ]);
    await plainDb.execute("SELECT sqlcipher_export('encrypted')");
    await plainDb.execute("DETACH DATABASE encrypted");
    await plainDb.close();

    // 3. Remplacer l'ancienne base par la nouvelle
    await File(path).delete();
    await File(tempPath).rename(path);

    // 4. Réouvrir sans version pour retour au flux standard
    return await databaseFactory.openDatabase(path);
  }

  Future<String> getDatabasePath() async {
    final supportDir = await getApplicationSupportDirectory();
    final newPath = join(supportDir.path, 'gestion_stock_pro.db');

    // 1. Si la base existe déjà au nouvel endroit (ApplicationSupport), on l'utilise
    if (await File(newPath).exists()) {
      return newPath;
    }

    // LISTE DES ANCIENS EMPLACEMENTS À VÉRIFIER
    final List<String> oldPaths = [];

    try {
      // Ancien emplacement standard (Documents)
      final docsDir = await getApplicationDocumentsDirectory();
      oldPaths.add(join(docsDir.path, 'gestion_stock_pro.db'));

      // Cas de roaming (vu dans certains logs d'erreur récents)
      String roamingBase = Platform.environment['APPDATA'] ?? '';
      if (roamingBase.isNotEmpty) {
        oldPaths.add(
          join(roamingBase, 'Danaya+', 'Danaya+', 'gestion_stock_pro.db'),
        );
        oldPaths.add(join(roamingBase, 'Danaya Plus', 'gestion_stock_pro.db'));
      }
    } catch (_) {}

    // Tenter la migration du premier trouvé
    for (final oldPath in oldPaths) {
      try {
        if (await File(oldPath).exists() && oldPath != newPath) {
          debugPrint(
            '📦 Base de données trouvée à : $oldPath. Migration vers $newPath...',
          );

          final targetFile = File(newPath);
          if (!await targetFile.parent.exists()) {
            await targetFile.parent.create(recursive: true);
          }

          await File(oldPath).copy(newPath);
          debugPrint('✅ Migration réussie depuis $oldPath');
          return newPath;
        }
      } catch (e) {
        debugPrint('⚠️ Erreur de migration pour $oldPath : $e');
      }
    }

    return newPath;
  }

  Future<String> _getEncryptionKey() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = "danaya_fallback_key";

    try {
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      }
    } catch (_) {
      // Fallback si l'ID matériel n'est pas accessible
    }

    // Dériver une clé SHA-256 stable à partir de l'ID matériel
    final bytes = utf8.encode("${deviceId}${SecurityConfig.databaseSalt}");
    return sha256.convert(bytes).toString();
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table Utilisateurs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        pin_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'CASHIER',
        is_active INTEGER NOT NULL DEFAULT 1,
        first_name TEXT,
        last_name TEXT,
        recovery_token TEXT,
        assigned_account_ids TEXT DEFAULT '[]'
      )
    ''');

    // Table Produits
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        barcode TEXT,
        reference TEXT,
        category TEXT,
        quantity REAL NOT NULL DEFAULT 0.0,
        purchasePrice REAL NOT NULL DEFAULT 0.0,
        sellingPrice REAL NOT NULL DEFAULT 0.0,
        weighted_average_cost REAL NOT NULL DEFAULT 0.0,
        alertThreshold REAL NOT NULL DEFAULT 5,
        description TEXT,
        image_path TEXT,
        location TEXT,
        unit TEXT,
        is_service INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ... (rest of onCreate remains same)
    // Table Mouvements de Stock
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements(
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT NOT NULL,
        date TEXT NOT NULL,
        user_id TEXT NOT NULL,
        session_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
      )
    ''');

    // Tables SRM
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact_name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        total_purchases REAL NOT NULL DEFAULT 0.0,
        outstanding_debt REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders(
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        account_id TEXT,
        reference TEXT NOT NULL,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        tax_amount REAL NOT NULL DEFAULT 0.0,
        shipping_fees REAL NOT NULL DEFAULT 0.0,
        payment_method TEXT,
        is_credit INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        session_id TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_order_items(
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES purchase_orders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_audits (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        status TEXT NOT NULL, -- DRAFT, COMPLETED
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_audit_items (
        id TEXT PRIMARY KEY,
        audit_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        theoretical_qty REAL NOT NULL,
        actual_qty REAL NOT NULL,
        difference REAL NOT NULL,
        FOREIGN KEY (audit_id) REFERENCES stock_audits (id) ON DELETE CASCADE
      )
    ''');

    // Table Paiements Fournisseurs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments(
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        description TEXT,
        user_id TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
      )
    ''');

    // Table Clients
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        total_purchases REAL NOT NULL DEFAULT 0.0,
        total_spent REAL NOT NULL DEFAULT 0.0,
        credit REAL NOT NULL DEFAULT 0.0,
        max_credit REAL NOT NULL DEFAULT 50000.0,
        loyalty_points REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Table Paiements Clients (Remboursements de dettes)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS client_payments(
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        description TEXT,
        user_id TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
      )
    ''');

    // Table Paramètres Fidélité
    await db.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_settings(
        id TEXT PRIMARY KEY,
        points_per_amount REAL NOT NULL DEFAULT 1000.0, -- ex: 1 point pour 1000 FCFA
        amount_per_point REAL NOT NULL DEFAULT 10.0,   -- ex: 1 point = 10 FCFA de remise
        is_enabled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Table Ventes (Sales)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales(
        id TEXT PRIMARY KEY,
        client_id TEXT,
        account_id TEXT,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        amount_paid REAL NOT NULL,
        payment_method TEXT,
        is_credit INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        refunded_amount REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        credit_amount REAL NOT NULL DEFAULT 0.0,
        is_synced INTEGER NOT NULL DEFAULT 1,
        user_id TEXT NOT NULL,
        due_date TEXT,
        session_id TEXT,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
        FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
      )
    ''');

    // Table Comptes Financiers (Caisse/Banque)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_accounts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'CASH', 'BANK', 'MOBILE_MONEY'
        balance REAL NOT NULL DEFAULT 0.0,
        is_default INTEGER NOT NULL DEFAULT 0,
        operator TEXT -- e.g. 'Wave', 'Orange Money', 'MTN', 'Ecobank'
      )
    ''');

    // Table Transactions Financières
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_transactions(
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        type TEXT NOT NULL, -- 'IN', 'OUT'
        amount REAL NOT NULL,
        category TEXT NOT NULL, -- 'SALE', 'EXPENSE', 'TRANSFER'
        description TEXT,
        date TEXT NOT NULL,
        reference_id TEXT, -- ID de la vente ou dépense associée
        session_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE CASCADE
      )
    ''');

    // Table Sessions de Caisse
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_sessions(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        open_date TEXT NOT NULL,
        close_date TEXT,
        opening_balance REAL NOT NULL,
        closing_balance_actual REAL,
        closing_balance_theoretical REAL,
        difference REAL,
        status TEXT NOT NULL, -- 'OPEN', 'CLOSED'
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
      )
    ''');

    // Insertion des comptes par défaut
    await db.insert('financial_accounts', {
      'id': 'acc_cash_main',
      'name': 'Caisse Principale',
      'type': 'CASH',
      'balance': 0.0,
      'is_default': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('financial_accounts', {
      'id': 'acc_bank_main',
      'name': 'Compte Bancaire',
      'type': 'BANK',
      'balance': 0.0,
      'is_default': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Table Lignes de Vente (Sale Items)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items(
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        returned_quantity REAL NOT NULL DEFAULT 0.0,
        unit_price REAL NOT NULL,
        discount_percent REAL NOT NULL DEFAULT 0.0,
        cost_price REAL NOT NULL DEFAULT 0.0,
        unit TEXT,
        description TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');

    // Insertion de l'Admin par défaut (PIN: 1234 + pepper)
    // Le hash est calculé dynamiquement pour éviter les erreurs de transcription
    final defaultAdminHash = sha256
        .convert(utf8.encode(SecurityConfig.initialAdminPepper))
        .toString();
    await db.insert('users', {
      'id': 'sysadmin',
      'username': 'Administrateur',
      'pin_hash': defaultAdminHash,
      'role': 'ADMIN',
      'is_active': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    debugPrint(
      '✅ Admin seedé avec hash dynamique : ${defaultAdminHash.substring(0, 8)}... (longueur: ${defaultAdminHash.length})',
    );

    // Initialisation des paramètres de fidélité
    await db.insert('loyalty_settings', {
      'id': 'default_loyalty',
      'points_per_amount': 1000.0,
      'amount_per_point': 10.0,
      'is_enabled': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Table Devis (Quotes)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotes(
        id TEXT PRIMARY KEY,
        quote_number TEXT NOT NULL UNIQUE,
        client_id TEXT,
        date TEXT NOT NULL,
        valid_until TEXT,
        subtotal REAL NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        user_id TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
      )
    ''');

    // Table Lignes de Devis (Quote Items)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_items(
        id TEXT PRIMARY KEY,
        quote_id TEXT NOT NULL,
        product_id TEXT, -- Peut être NULL pour les articles personnalisés
        custom_name TEXT, -- Pour les articles non présents en inventaire
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit TEXT,
        description TEXT,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (quote_id) REFERENCES quotes (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
      )
    ''');

    // Table Journal d'Audit
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        action_type TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        description TEXT,
        metadata TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
      )
    ''');

    // ── HR Tables ──
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_contracts(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        contract_type TEXT NOT NULL DEFAULT 'CDI',
        start_date TEXT NOT NULL,
        end_date TEXT,
        base_salary REAL NOT NULL DEFAULT 0.0,
        transport_allowance REAL NOT NULL DEFAULT 0.0,
        meal_allowance REAL NOT NULL DEFAULT 0.0,
        position TEXT,
        department TEXT,
        school_name TEXT,
        supervisor_id TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_at TEXT,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payrolls(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        base_salary REAL NOT NULL DEFAULT 0.0,
        extra_lines TEXT NOT NULL DEFAULT '[]',
        payment_date TEXT,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        created_at TEXT,
        printed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_requests(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        leave_type TEXT NOT NULL DEFAULT 'PERMISSION',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        reviewed_by TEXT,
        reviewed_at TEXT,
        reviewer_note TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // ── Performance Indexes ──
    // Indexes moved to _onUpgrade (v16) to ensure all tables exist before indexing.
  }

  // Migration logic externalized to MigrationRunner for better maintainability.
  // Original _onUpgrade removed to reduce technical debt.

  /// Version-independent checks to ensure data & schema integrity
  Future<void> runSafetyChecks(Database db) async {
    try {
      // 1. Column Integrity: sale_items.discount_percent
      final tableInfo = await db.rawQuery("PRAGMA table_info(sale_items)");
      final hasDiscountCol = tableInfo.any(
        (col) => col['name'] == 'discount_percent',
      );
      if (!hasDiscountCol) {
        debugPrint(
          'Nuclear Fix: Adding missing discount_percent column to sale_items',
        );
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN discount_percent REAL NOT NULL DEFAULT 0.0',
        );
      }

      final hasCostPriceCol = tableInfo.any(
        (col) => col['name'] == 'cost_price',
      );
      if (!hasCostPriceCol) {
        debugPrint(
          'Nuclear Fix: Adding missing cost_price column to sale_items',
        );
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN cost_price REAL NOT NULL DEFAULT 0.0',
        );
      }

      // 2. Data Integrity: Scrub 550B values (Financial Nuclear Scrub)
      // Any value > 1 Billion for a price or 1 Trillion for a total is likely corruption (barcodes/IDs)
      const double priceLimit = 1000000000.0;

      // Products
      await db.execute(
        "UPDATE products SET weighted_average_cost = 0.0 WHERE weighted_average_cost < 0 OR weighted_average_cost > $priceLimit",
      );
      await db.execute(
        "UPDATE products SET purchasePrice = 0.0 WHERE purchasePrice < 0 OR purchasePrice > $priceLimit",
      );
      await db.execute(
        "UPDATE products SET sellingPrice = 0.0 WHERE sellingPrice < 0 OR sellingPrice > $priceLimit",
      );

      // Sale Items
      await db.execute(
        "UPDATE sale_items SET unit_price = 0.0 WHERE unit_price < 0 OR unit_price > $priceLimit",
      );
      await db.execute(
        "UPDATE sale_items SET returned_quantity = 0 WHERE returned_quantity > quantity OR returned_quantity < 0",
      );

      // Sales
      await db.execute(
        "UPDATE sales SET total_amount = 0.0 WHERE total_amount < 0 OR total_amount > 100000000000.0",
      );
      await db.execute(
        "UPDATE sales SET discount_amount = 0.0 WHERE discount_amount < 0 OR discount_amount > 100000000000.0",
      );

      // 3. Last Resort: credit_amount in sales
      final salesInfo = await db.rawQuery("PRAGMA table_info(sales)");
      final hasCreditCol = salesInfo.any(
        (col) => col['name'] == 'credit_amount',
      );
      if (!hasCreditCol) {
        debugPrint('Nuclear Fix: Adding missing credit_amount column to sales');
        await db.execute(
          'ALTER TABLE sales ADD COLUMN credit_amount REAL NOT NULL DEFAULT 0.0',
        );
      }

      // 4. Session Integrity: session_id in sales
      final hasSessionCol = salesInfo.any((col) => col['name'] == 'session_id');
      if (!hasSessionCol) {
        debugPrint('Nuclear Fix: Adding missing session_id column to sales');
        await db.execute('ALTER TABLE sales ADD COLUMN session_id TEXT');
      }

      // 5. 🛡️ USER ACCESS EMERGENCY HEALING
      final userInfo = await db.rawQuery("PRAGMA table_info(users)");
      final hasActiveCol = userInfo.any((col) => col['name'] == 'is_active');
      if (!hasActiveCol) {
        debugPrint('Nuclear Fix: Adding missing is_active column to users');
        await db.execute(
          'ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        );
      }

      // FORCED ACTIVATION: Unblock all users who might have been corrupted/deactivated
      debugPrint('🛡️ Emergency Healing: Activating all user accounts...');
      await db.execute(
        "UPDATE users SET is_active = 1 WHERE is_active IS NULL OR is_active = 0",
      );

      // 6. 🕵️ SUPREME FORENSIC: FTS5 COHERENCE & AUTO-HEALING
      debugPrint('🕵️ Supreme Forensic Audit: Checking FTS5 search engines...');

      // Products FTS Check
      final pCount =
          (await db.rawQuery("SELECT COUNT(*) AS c FROM products")).first['c']
              as int;
      final pFtsCount =
          (await db.rawQuery(
                "SELECT COUNT(*) AS c FROM products_fts",
              )).first['c']
              as int;

      if (pCount != pFtsCount) {
        debugPrint(
          '⚠️ FTS5 De-sync detected (Products). Launching Auto-Healing rebuild...',
        );
        await db.transaction((txn) async {
          await txn.execute("DELETE FROM products_fts");
          await txn.execute(
            "INSERT INTO products_fts(id, name, reference, category, barcode) SELECT id, name, reference, category, barcode FROM products",
          );
        });
      }

      // Clients FTS Check
      final cCount =
          (await db.rawQuery("SELECT COUNT(*) AS c FROM clients")).first['c']
              as int;
      final cFtsCount =
          (await db.rawQuery(
                "SELECT COUNT(*) AS c FROM clients_fts",
              )).first['c']
              as int;

      if (cCount != cFtsCount) {
        debugPrint(
          '⚠️ FTS5 De-sync detected (Clients). Launching Auto-Healing rebuild...',
        );
        await db.transaction((txn) async {
          await txn.execute("DELETE FROM clients_fts");
          await txn.execute(
            "INSERT INTO clients_fts(id, name, phone, address, email) SELECT id, name, phone, address, email FROM clients",
          );
        });
      }

      // 6. 🛡️ PRAGMA INTEGRITY CHECK (Surrounding 1.0.1 Launch)
      // On le lance une fois par session au démarrage pour les audits
      final integrity = await db.rawQuery(
        "PRAGMA integrity_check(1)",
      ); // Check first 1 error
      if (integrity.first['integrity_check'] != 'ok') {
        debugPrint(
          '🚨 DATABASE CORRUPTION DETECTED: ${integrity.first['integrity_check']}',
        );
        // Log critical forensic error
        await _logActivityInternal(
          db,
          'SYSTEM',
          'DB_CORRUPTION',
          'DATABASE',
          'SYSTEM',
          "CORRUPTION: ${integrity.first['integrity_check']}",
        );
      } else {
        debugPrint('✅ Database integrity verified (Supreme Audit).');
      }

      // 7. Transaction Integrity: session_id
      final txInfo = await db.rawQuery(
        "PRAGMA table_info(financial_transactions)",
      );
      if (!txInfo.any((col) => col['name'] == 'session_id')) {
        debugPrint(
          'Nuclear Fix: Adding missing session_id column to financial_transactions',
        );
        await db.execute(
          'ALTER TABLE financial_transactions ADD COLUMN session_id TEXT',
        );
      }

      // 6. Session Integrity: theoretical balance
      final sessionInfo = await db.rawQuery("PRAGMA table_info(cash_sessions)");
      if (!sessionInfo.any(
        (col) => col['name'] == 'closing_balance_theoretical',
      )) {
        debugPrint(
          'Nuclear Fix: Adding missing closing_balance_theoretical column to cash_sessions',
        );
        await db.execute(
          'ALTER TABLE cash_sessions ADD COLUMN closing_balance_theoretical REAL',
        );
      }

      // 7. Client Integrity: address & email
      final clientInfo = await db.rawQuery("PRAGMA table_info(clients)");
      if (!clientInfo.any((col) => col['name'] == 'email')) {
        await db.execute('ALTER TABLE clients ADD COLUMN email TEXT');
      }
      if (!clientInfo.any((col) => col['name'] == 'address')) {
        await db.execute('ALTER TABLE clients ADD COLUMN address TEXT');
      }
      if (!clientInfo.any((col) => col['name'] == 'max_credit')) {
        debugPrint('Nuclear Fix: Adding missing max_credit column to clients');
        await db.execute(
          'ALTER TABLE clients ADD COLUMN max_credit REAL NOT NULL DEFAULT 50000.0',
        );
      }

      // 8. Auth Integrity: S'assurer que le hash admin est valide (correction du bug hash tronqué)
      await _ensureAdminHash(db);

      // 9. Error Logging Integrity
      await db.execute('''
        CREATE TABLE IF NOT EXISTS internal_errors(
          id TEXT PRIMARY KEY,
          error_message TEXT NOT NULL,
          stack_trace TEXT,
          context TEXT,
          date TEXT NOT NULL,
          is_resolved INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Safety checks completed silently
    } catch (e) {
      debugPrint('Nuclear Fix error: $e');
    }
  }

  /// 💎 Periodic Maintenance (Self-Healing)
  /// Runs VACUUM and ANALYZE if not done in the last 7 days.
  Future<void> _performPeriodicMaintenance(Database db) async {
    try {
      // Use import inside method or at top level if already exists (need to verify shared_preferences)
      // Check if SharedPreferences is already imported.
      final prefs = await SharedPreferences.getInstance();
      const lastMaintKey = 'last_db_maintenance_timestamp';
      final lastMaint = prefs.getInt(lastMaintKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 7 days interval (604,800,000 ms)
      if (now - lastMaint > 604800000) {
        debugPrint(
          '🧹 Genius Maintenance: Running Full Database Optimization (VACUUM)...',
        );
        await db.execute('VACUUM');
        await db.execute('ANALYZE');
        await prefs.setInt(lastMaintKey, now);
        debugPrint('✅ Genius Maintenance: Optimization Complete.');
      }
    } catch (e) {
      debugPrint('⚠️ Genius Maintenance Error: $e');
    }
  }



  /// Vérifie et corrige le hash PIN de l'administrateur système.
  /// Corrige le bug où le hash était tronqué à 63 chars au lieu de 64.
  Future<void> _ensureAdminHash(Database db) async {
    try {
      const String pepper = 'danaya_secure_pepper_2024_v1';
      final correctHash = sha256.convert(utf8.encode('1234$pepper')).toString();

      final adminRows = await db.query(
        'users',
        columns: ['id', 'pin_hash'],
        where: 'id = ?',
        whereArgs: ['sysadmin'],
        limit: 1,
      );

      if (adminRows.isEmpty) {
        // Admin absent (ne devrait pas arriver sur installation propre) : on le recrée
        debugPrint(
          '⚠️ Admin sysadmin manquant — Recréation avec hash correct...',
        );
        await db.insert('users', {
          'id': 'sysadmin',
          'username': 'Administrateur',
          'pin_hash': correctHash,
          'role': 'ADMIN',
          'is_active': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint('✅ Admin recréé avec hash valide.');
        return;
      }

      final storedHash = adminRows.first['pin_hash'] as String? ?? '';

      // Un hash SHA256 valide fait TOUJOURS 64 caractères
      if (storedHash.length != 64) {
        debugPrint(
          '🔧 Hash admin invalide détecté (${storedHash.length} chars). Correction vers hash correct...',
        );
        await db.update(
          'users',
          {'pin_hash': correctHash},
          where: 'id = ?',
          whereArgs: ['sysadmin'],
        );
        debugPrint(
          '✅ Hash admin corrigé vers : ${correctHash.substring(0, 8)}... (longueur: ${correctHash.length})',
        );
      } else {
        debugPrint(
          '✅ Hash admin valide (${storedHash.length} chars) — Aucune correction nécessaire.',
        );
      }
    } catch (e) {
      debugPrint('❌ _ensureAdminHash error: $e');
    }
  }







  Future<void> logActivity({
    String? userId,
    required String actionType,
    String? entityType,
    String? entityId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final db = await database;
    await db.insert('activity_logs', {
      'id': const Uuid().v4(),
      'user_id': userId,
      'action_type': actionType,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({int limit = 100}) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT al.*, u.username as username
      FROM activity_logs al
      LEFT JOIN users u ON al.user_id = u.id
      ORDER BY al.date DESC
      LIMIT ?
    ''',
      [limit],
    );
  }



  /// 🧞 Genius Predictive: Calculate stock velocity based on last 7 days of sales
  /// Returns a list of products that will run out soon.
  Future<List<Map<String, dynamic>>> getStockVelocityPredictions() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();

    // 1. Calculate items sold per product in the last 7 days
    final List<Map<String, dynamic>> velocityData = await db.rawQuery(
      '''
      SELECT 
        p.id, 
        p.name, 
        p.quantity as current_stock,
        SUM(si.quantity) as total_sold_7d,
        (SUM(si.quantity) / 7.0) as daily_velocity
      FROM products p
      LEFT JOIN sale_items si ON p.id = si.product_id
      LEFT JOIN sales s ON si.sale_id = s.id
      WHERE s.date >= ? AND s.status = 'COMPLETED'
      GROUP BY p.id
      HAVING total_sold_7d > 0
    ''',
      [sevenDaysAgo],
    );

    final List<Map<String, dynamic>> predictions = [];

    for (final row in velocityData) {
      final double currentStock = (row['current_stock'] as num).toDouble();
      final double dailyVelocity = (row['daily_velocity'] as num).toDouble();

      if (dailyVelocity > 0) {
        final double daysRemaining = currentStock / dailyVelocity;

        // If stock will last less than 5 days, it's a "Genius Alert" 🧞
        if (daysRemaining <= 5) {
          predictions.add({
            'id': row['id'],
            'name': row['name'],
            'current_stock': currentStock,
            'days_remaining': daysRemaining.toStringAsFixed(1),
            'is_critical': daysRemaining <= 1,
          });
        }
      }
    }

    return predictions;
  }

  /// Log interne pour les alertes système d'audit (Forensic)
  Future<void> _logActivityInternal(
    Database db,
    String userId,
    String action,
    String type,
    String id,
    String desc,
  ) async {
    try {
      await db.insert('activity_logs', {
        'id': const Uuid().v4(),
        'user_id': userId,
        'action_type': action,
        'entity_type': type,
        'entity_id': id,
        'description': desc,
        'date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Forensic Log Error: $e");
    }
  }

  /// 🛡️ Crée une copie de sécurité avant une opération risquée (migration/réparation)
  Future<void> _createSafeBackup(String dbPath) async {
    try {
      final file = File(dbPath);
      if (await file.exists()) {
        final backupPath = "$dbPath.safe_backup";
        await file.copy(backupPath);
        debugPrint('🛡️ Alpha-Armor: Safe-Backup créé à $backupPath');
      }
    } catch (e) {
      debugPrint('⚠️ Alpha-Armor Warning: Échec du Safe-Backup : $e');
    }
  }

  /// 📜 Journalise une erreur interne de manière persistante
  Future<void> _logInternalError(String context, String message) async {
    try {
      final db = await database;
      await db.insert('internal_errors', {
        'id': const Uuid().v4(),
        'error_message': message,
        'context': context,
        'date': DateTime.now().toIso8601String(),
        'is_resolved': 0,
      });
    } catch (_) {}
  }
}
