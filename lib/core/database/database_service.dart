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
      await _onUpgrade(db, currentVersion, targetVersion);
      await db.execute('PRAGMA user_version = $targetVersion');
    }

    // ── Nuclear Fix: Version-independent safety checks ──
    await _ensureCreditAmountColumn(db);

    // ── Performance PRAGMAs (CRITIQUES - synchrones) ──
    try {
      await db.execute('PRAGMA journal_mode=WAL');
      debugPrint('⚡ DatabaseService: Journal mode = WAL');
      await db.execute('PRAGMA foreign_keys=ON');
    } catch (e) {
      debugPrint("DB Pragma Error: $e");
    }

    // ── Safety Checks & Maintenance (NON-BLOQUANT) ──
    // Exécuter en arrière-plan pour ne pas retarder le premier affichage du dashboard
    final localDb = db; // Capture non-nullable pour la closure
    Future.microtask(() async {
      try {
        await runSafetyChecks(localDb);
        await _performPeriodicMaintenance(localDb);
        await localDb.execute('PRAGMA optimize');
        debugPrint('💎 DatabaseService: Background maintenance completed.');
      } catch (e) {
        debugPrint("⚠️ Background maintenance error: $e");
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
    final bytes = utf8.encode("${deviceId}danaya_secure_salt_2024");
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
        .convert(utf8.encode('1234danaya_secure_pepper_2024_v1'))
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, pin_hash TEXT NOT NULL, role TEXT NOT NULL DEFAULT "CASHIER", is_active INTEGER NOT NULL DEFAULT 1)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS products(id TEXT PRIMARY KEY, name TEXT NOT NULL, barcode TEXT, category TEXT, quantity INTEGER NOT NULL DEFAULT 0, purchasePrice REAL NOT NULL DEFAULT 0.0, sellingPrice REAL NOT NULL DEFAULT 0.0, alertThreshold INTEGER NOT NULL DEFAULT 5, description TEXT, image_path TEXT)',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS stock_movements(id TEXT PRIMARY KEY, product_id TEXT NOT NULL, type TEXT NOT NULL, quantity INTEGER NOT NULL, reason TEXT NOT NULL, date TEXT NOT NULL, user_id TEXT NOT NULL, FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT)',
      );
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS suppliers(id TEXT PRIMARY KEY, name TEXT NOT NULL, contact_name TEXT, phone TEXT, email TEXT, address TEXT, total_purchases REAL NOT NULL DEFAULT 0.0, outstanding_debt REAL NOT NULL DEFAULT 0.0)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS purchase_orders(id TEXT PRIMARY KEY, supplier_id TEXT NOT NULL, reference TEXT NOT NULL, date TEXT NOT NULL, total_amount REAL NOT NULL, status TEXT NOT NULL, FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS purchase_order_items(id TEXT PRIMARY KEY, order_id TEXT NOT NULL, product_id TEXT NOT NULL, quantity INTEGER NOT NULL, unit_price REAL NOT NULL, FOREIGN KEY (order_id) REFERENCES purchase_orders (id) ON DELETE CASCADE, FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE)',
        );
      } catch (e) {
        debugPrint("Migration v4 error: $e");
      }
    }
    if (oldVersion < 5) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS clients(id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, total_purchases INTEGER NOT NULL DEFAULT 0, total_spent REAL NOT NULL DEFAULT 0.0, credit REAL NOT NULL DEFAULT 0.0)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS sales(id TEXT PRIMARY KEY, client_id TEXT, date TEXT NOT NULL, total_amount REAL NOT NULL, amount_paid REAL NOT NULL, is_credit INTEGER NOT NULL DEFAULT 0, user_id TEXT NOT NULL, FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT)',
      );
      await db.execute(
        'CREATE TABLE IF NOT EXISTS sale_items(id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT NOT NULL, quantity INTEGER NOT NULL, unit_price REAL NOT NULL, FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE, FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT)',
      );
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_accounts(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          balance REAL NOT NULL DEFAULT 0.0,
          is_default INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_transactions(
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          reference_id TEXT,
          FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute("ALTER TABLE sales ADD COLUMN account_id TEXT");
        await db.execute("ALTER TABLE sales ADD COLUMN payment_method TEXT");
      } catch (e) {
        debugPrint('Migration v7 warning: $e');
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN account_id TEXT',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN amount_paid REAL NOT NULL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN payment_method TEXT',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN is_credit INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        debugPrint("Migration v8 warning: $e");
      }
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cash_sessions(
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          open_date TEXT NOT NULL,
          close_date TEXT,
          opening_balance REAL NOT NULL,
          closing_balance_actual REAL,
          difference REAL,
          status TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
        )
      ''');
    }

    if (oldVersion < 11) {
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
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quote_items(
          id TEXT PRIMARY KEY,
          quote_id TEXT NOT NULL,
          product_id TEXT,
          custom_name TEXT,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          FOREIGN KEY (quote_id) REFERENCES quotes (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
        )
      ''');
    }

    if (oldVersion < 12) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS warehouses(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            type TEXT NOT NULL DEFAULT 'STORE',
            is_default INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS warehouse_stock(
            id TEXT PRIMARY KEY,
            warehouse_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
            UNIQUE(warehouse_id, product_id)
          )
        ''');

        // Add warehouse_id column to stock_movements
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN warehouse_id TEXT',
        );

        // Create default warehouse
        await db.execute('''
          INSERT OR IGNORE INTO warehouses (id, name, type, is_default, is_active)
          VALUES ('default_warehouse', 'Magasin Principal', 'STORE', 1, 1)
        ''');
      } catch (e) {
        debugPrint('Migration v12 warning: $e');
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute(
          'ALTER TABLE clients ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0',
        );
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
        await db.execute('''
          CREATE TABLE IF NOT EXISTS loyalty_settings(
            id TEXT PRIMARY KEY,
            points_per_amount REAL NOT NULL DEFAULT 1000.0,
            amount_per_point REAL NOT NULL DEFAULT 10.0,
            is_enabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.insert('loyalty_settings', {
          'id': 'default_loyalty',
          'points_per_amount': 1000.0,
          'amount_per_point': 10.0,
          'is_enabled': 1,
        });
      } catch (e) {
        debugPrint('Migration v13 warning: $e');
      }
    }

    if (oldVersion < 14) {
      // Add balance/debt to suppliers
      try {
        await db.execute(
          'ALTER TABLE suppliers ADD COLUMN debt REAL NOT NULL DEFAULT 0.0',
        );
      } catch (e) {
        debugPrint('Migration v14 warning (supplier debt): $e');
      }

      // Add weighted_average_cost to products
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN weighted_average_cost REAL NOT NULL DEFAULT 0.0',
        );
      } catch (e) {
        debugPrint('Migration v14 warning (weighted_average_cost): $e');
      }

      // Purchases table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases(
          id TEXT PRIMARY KEY,
          supplier_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL, -- PENDING, PARTIAL, PAID
          invoice_number TEXT,
          user_id TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE RESTRICT,
          FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
        )
      ''');

      // Purchase items table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_items(
          id TEXT PRIMARY KEY,
          purchase_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_cost REAL NOT NULL,
          FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');

      // Supplier payments table
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
    }

    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_audits (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_audit_items (
          id TEXT PRIMARY KEY,
          audit_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          theoretical_qty INTEGER NOT NULL,
          actual_qty INTEGER NOT NULL,
          difference INTEGER NOT NULL,
          FOREIGN KEY (audit_id) REFERENCES stock_audits (id) ON DELETE CASCADE
        )
      ''');
    }

    // v16: Add performance indexes to all tables
    if (oldVersion < 16) {
      await _createIndexes(db);
    }

    // v17: Add reference field to products
    if (oldVersion < 17) {
      try {
        await db.execute(
          "UPDATE products SET quantity = 0 WHERE quantity IS NULL",
        );
        await db.execute("ALTER TABLE products ADD COLUMN reference TEXT");
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_reference ON products(reference)',
        );
      } catch (e) {
        debugPrint('Migration v17 warning (product reference): $e');
      }
    }

    // v18: Add discount, tax, shipping to purchase orders
    if (oldVersion < 18) {
      try {
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN tax_amount REAL NOT NULL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN shipping_fees REAL NOT NULL DEFAULT 0.0',
        );
      } catch (e) {
        debugPrint('Migration v18 warning (purchase financials): $e');
      }
    }

    // v19: Reliable fix for purchase_orders & suppliers columns
    if (oldVersion < 19) {
      try {
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN tax_amount REAL NOT NULL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN shipping_fees REAL NOT NULL DEFAULT 0.0',
        );
      } catch (_) {}

      // Suppliers consistency
      try {
        await db.execute(
          'ALTER TABLE suppliers ADD COLUMN total_purchases REAL NOT NULL DEFAULT 0.0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE suppliers ADD COLUMN outstanding_debt REAL NOT NULL DEFAULT 0.0',
        );
      } catch (_) {}
    }

    if (oldVersion < 40) {
      try {
        await db.execute('ALTER TABLE clients ADD COLUMN birth_date TEXT');
        await db.execute(
          'ALTER TABLE clients ADD COLUMN last_purchase_date TEXT',
        );
      } catch (e) {
        debugPrint('Migration v40 warning (marketing fields): $e');
      }
    }

    if (oldVersion < 41) {
      try {
        await db.execute(
          'ALTER TABLE clients ADD COLUMN last_marketing_reminder_date TEXT',
        );
      } catch (e) {
        debugPrint('Migration v41 warning (last_marketing_reminder_date): $e');
      }
    }

    // Removed duplicate migration v34 (already handled)

    // v20: Make product_id nullable in sale_items (for custom items from quotes)
    if (oldVersion < 20) {
      await db.transaction((txn) async {
        // 1. Rename old table
        await txn.execute('ALTER TABLE sale_items RENAME TO sale_items_old');

        // 2. Create new table without NOT NULL on product_id
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS sale_items(
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            product_id TEXT,
            quantity INTEGER NOT NULL,
            returned_quantity INTEGER NOT NULL DEFAULT 0,
            unit_price REAL NOT NULL,
            FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
          )
        ''');

        // 3. Copy data explicitly
        await txn.execute(
          'INSERT INTO sale_items (id, sale_id, product_id, quantity, returned_quantity, unit_price) SELECT id, sale_id, product_id, quantity, returned_quantity, unit_price FROM sale_items_old',
        );

        // 4. Drop old table
        await txn.execute('DROP TABLE sale_items_old');

        // 5. Re-create indexes
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)',
        );
      });
    }

    // v21: Add discount_amount to sales
    if (oldVersion < 21) {
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0.0',
        );
      } catch (e) {
        debugPrint('Migration v21 warning: $e');
      }
    }

    // v22: Add category to stock_audits for partial audits
    if (oldVersion < 22) {
      try {
        await db.execute('ALTER TABLE stock_audits ADD COLUMN category TEXT');
      } catch (e) {
        debugPrint('Migration v22 warning (stock_audits category): $e');
      }
    }

    // v23: Add operator column to financial_accounts
    if (oldVersion < 23) {
      try {
        await db.execute(
          'ALTER TABLE financial_accounts ADD COLUMN operator TEXT',
        );
      } catch (e) {
        debugPrint('Migration v23 warning (financial_accounts operator): $e');
      }
    }

    // v24: Add location column to products
    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN location TEXT');
      } catch (e) {
        debugPrint('Migration v24 warning (product location): $e');
      }
    }

    if (oldVersion < 28) {
      try {
        // Force cleanup one more time to be absolutely sure
        await db.execute(
          "UPDATE products SET purchasePrice = 0.0 WHERE purchasePrice < 0 OR purchasePrice > 1000000000;",
        );
        await db.execute(
          "UPDATE products SET weighted_average_cost = 0.0 WHERE weighted_average_cost < 0 OR weighted_average_cost > 1000000000;",
        );
        // Also cleanup sale_items just in case
        await db.execute(
          "UPDATE sale_items SET unit_price = 0.0 WHERE unit_price < 0 OR unit_price > 1000000000;",
        );
        debugPrint('Migration v28: Final data scrub applied.');
      } catch (e) {
        debugPrint('Migration v28 error: $e');
      }
    }

    if (oldVersion < 29) {
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1',
        );
        debugPrint('Migration v29: Added is_synced column to sales.');
      } catch (e) {
        debugPrint('Migration v29 error: $e');
      }
    }

    if (oldVersion < 30) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN recovery_token TEXT');
        debugPrint('Migration v30: Added recovery_token column to users.');
      } catch (e) {
        debugPrint('Migration v30 error: $e');
      }
    }
    if (oldVersion < 31) {
      try {
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
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_activity_logs_date ON activity_logs(date)',
        );
        debugPrint('Migration v31: Created activity_logs table.');
      } catch (e) {
        debugPrint('Migration v31 error: $e');
      }
    }
    if (oldVersion < 32) {
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN credit_amount REAL NOT NULL DEFAULT 0.0',
        );
        debugPrint('Migration v32: Added credit_amount column to sales.');
      } catch (e) {
        debugPrint('Migration v32 error: $e');
      }
    }
    if (oldVersion < 34) {
      // Version 34 placeholder (already released without explicit upgrade block)
    }
    if (oldVersion < 35) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN session_id TEXT');
        debugPrint('Migration v35: Added session_id column to sales.');
      } catch (e) {
        debugPrint('Migration v35 error: $e');
      }
    }
    if (oldVersion < 36) {
      try {
        await db.execute(
          'ALTER TABLE financial_transactions ADD COLUMN session_id TEXT',
        );
        await db.execute(
          'ALTER TABLE cash_sessions ADD COLUMN closing_balance_theoretical REAL',
        );
        debugPrint(
          'Migration v36: Added session_id to transactions and closing_balance_theoretical to sessions.',
        );
      } catch (e) {
        debugPrint('Migration v36 error: $e');
      }
    }

    if (oldVersion < 37) {
      try {
        await db.execute(
          'ALTER TABLE financial_transactions ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE cash_sessions ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN session_id TEXT',
        );
        await db.execute(
          'ALTER TABLE purchase_orders ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN session_id TEXT',
        );
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE client_payments ADD COLUMN session_id TEXT',
        );
        await db.execute(
          'ALTER TABLE client_payments ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        debugPrint(
          'Migration v37: Full Audit Sync columns added to purchases, movements, and payments.',
        );
      } catch (e) {
        debugPrint('Migration v37 error: $e');
      }
    }

    if (oldVersion < 38) {
      try {
        await db.execute(
          'ALTER TABLE products ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE clients ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE suppliers ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
        );
        debugPrint(
          'Migration v38: Master Data Sync (Products/Clients/Suppliers) columns added.',
        );
      } catch (e) {
        debugPrint('Migration v38 error: $e');
      }
    }

    if (oldVersion < 39) {
      try {
        final tablesToSync = [
          'users',
          'products',
          'stock_movements',
          'suppliers',
          'purchase_orders',
          'purchase_order_items',
          'clients',
          'client_payments',
          'sales',
          'sale_items',
          'financial_accounts',
          'financial_transactions',
          'cash_sessions',
          'supplier_payments',
          'loyalty_settings',
          'quotes',
          'quote_items',
          'warehouses',
          'warehouse_stock',
          'stock_audits',
          'stock_audit_items',
        ];

        final now = DateTime.now().millisecondsSinceEpoch;

        for (final table in tablesToSync) {
          try {
            await db.execute(
              'ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now',
            );
          } catch (e) {
            debugPrint('Migration v39 warning ($table updated_at): $e');
          }
          try {
            await db.execute(
              'ALTER TABLE $table ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
            );
          } catch (e) {
            debugPrint('Migration v39 warning ($table is_deleted): $e');
          }
        }

        // Create the highly resilient offline queue table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS offline_queue(
            id TEXT PRIMARY KEY,
            operation TEXT NOT NULL, -- POST, PUT, DELETE
            table_name TEXT NOT NULL,
            payload TEXT NOT NULL, -- JSON string
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING'
          )
        ''');

        // Add index for fast querying of pending items
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_offline_queue_status ON offline_queue(status)',
        );

        debugPrint(
          'Migration v39: Delta Sync (updated_at) and Offline Queue implemented.',
        );
      } catch (e) {
        debugPrint('Migration v39 error: $e');
      }
    }

    if (oldVersion < 42) {
      // --- Helper for safe column addition ---
      Future<void> addCol(String table, String col, String type) async {
        try {
          final info = await db.rawQuery("PRAGMA table_info($table)");
          if (!info.any((c) => c['name'] == col)) {
            await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
          }
        } catch (e) {
          debugPrint('Migration v42 warning (Adding $col to $table): $e');
        }
      }

      await addCol('products', 'unit', 'TEXT');
      await addCol('products', 'is_service', 'INTEGER NOT NULL DEFAULT 0');

      await addCol('quote_items', 'unit', 'TEXT');
      await addCol('quote_items', 'description', 'TEXT');
      await addCol(
        'quote_items',
        'discount_amount',
        'REAL NOT NULL DEFAULT 0.0',
      );

      await addCol('sale_items', 'unit', 'TEXT');
      await addCol('sale_items', 'description', 'TEXT');

      debugPrint(
        'Migration v42: Units, Services and Decimal support implemented (Resilient Mode).',
      );
    }

    if (oldVersion < 43) {
      await _migrateToV43(db);
      debugPrint(
        'Migration v43: HR Module (Contracts, Payroll, Leaves) implemented.',
      );
    }

    if (oldVersion < 44) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN first_name TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN last_name TEXT');
        debugPrint('Migration v44: User first_name and last_name added.');
      } catch (e) {
        debugPrint('Migration v44 error: $e');
      }
    }

    if (oldVersion < 45) {
      await _migrateToV45(db);
    }

    if (oldVersion < 46) {
      try {
        await db.execute(
          "ALTER TABLE users ADD COLUMN assigned_account_ids TEXT DEFAULT '[]'",
        );
        debugPrint('Migration v46: User assigned_account_ids added.');
      } catch (e) {
        debugPrint('Migration v46 error: $e');
      }
    }

    if (oldVersion < 47) {
      await _migrateToV47(db);
    }

    if (oldVersion < 48) {
      try {
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN balance_before REAL',
        );
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN balance_after REAL',
        );
        debugPrint('Migration v48: Stock balance snapshots added.');
      } catch (e) {
        debugPrint('Migration v48 error: $e');
      }
    }

    if (oldVersion < 49) {
      await _migrateToV49(db);
    }
    if (oldVersion < 50) {
      await _migrateToV50(db);
    }
  }

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
        await db.execute('ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
      }
      
      // FORCED ACTIVATION: Unblock all users who might have been corrupted/deactivated
      debugPrint('🛡️ Emergency Healing: Activating all user accounts...');
      await db.execute("UPDATE users SET is_active = 1 WHERE is_active IS NULL OR is_active = 0");

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

  Future<void> _migrateToV45(Database db) async {
    debugPrint('🚀 Migration v45 (REAL Quantities) starting...');
    await db.transaction((txn) async {
      // Helper pour détecter les colonnes présentes dans la table obsolète
      Future<Map<String, String>> getOldCols(String table) async {
        final info = await txn.rawQuery("PRAGMA table_info($table)");
        final names = info.map((c) => c['name'] as String).toSet();
        return {
          'updated_at': names.contains('updated_at') ? 'updated_at' : '0',
          'is_deleted': names.contains('is_deleted') ? 'is_deleted' : '0',
        };
      }

      // 1. Table warehouse_stock
      await txn.execute(
        'ALTER TABLE warehouse_stock RENAME TO warehouse_stock_old',
      );
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS warehouse_stock(
          id TEXT PRIMARY KEY,
          warehouse_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity REAL NOT NULL DEFAULT 0.0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
          UNIQUE(warehouse_id, product_id)
        )
      ''');
      final cols1 = await getOldCols('warehouse_stock_old');
      await txn.execute(
        'INSERT INTO warehouse_stock (id, warehouse_id, product_id, quantity, updated_at, is_deleted) SELECT id, warehouse_id, product_id, CAST(quantity AS REAL), ${cols1['updated_at']}, ${cols1['is_deleted']} FROM warehouse_stock_old',
      );
      await txn.execute('DROP TABLE warehouse_stock_old');

      // 2. Table stock_movements
      await txn.execute(
        'ALTER TABLE stock_movements RENAME TO stock_movements_old',
      );
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS stock_movements(
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          type TEXT NOT NULL,
          quantity REAL NOT NULL,
          reason TEXT NOT NULL,
          date TEXT NOT NULL,
          user_id TEXT NOT NULL,
          warehouse_id TEXT,
          session_id TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
        )
      ''');
      final cols2 = await getOldCols('stock_movements_old');
      await txn.execute(
        'INSERT INTO stock_movements (id, product_id, type, quantity, reason, date, user_id, warehouse_id, session_id, is_synced, updated_at, is_deleted) SELECT id, product_id, type, CAST(quantity AS REAL), reason, date, user_id, warehouse_id, session_id, is_synced, ${cols2['updated_at']}, ${cols2['is_deleted']} FROM stock_movements_old',
      );
      await txn.execute('DROP TABLE stock_movements_old');

      // 3. Table sale_items
      await txn.execute('ALTER TABLE sale_items RENAME TO sale_items_old');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS sale_items(
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          product_id TEXT,
          quantity REAL NOT NULL,
          returned_quantity REAL NOT NULL DEFAULT 0.0,
          unit_price REAL NOT NULL,
          discount_percent REAL NOT NULL DEFAULT 0.0,
          unit TEXT,
          description TEXT,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
        )
      ''');
      final cols3 = await getOldCols('sale_items_old');
      await txn.execute(
        'INSERT INTO sale_items (id, sale_id, product_id, quantity, returned_quantity, unit_price, discount_percent, unit, description, updated_at, is_deleted) SELECT id, sale_id, product_id, CAST(quantity AS REAL), CAST(returned_quantity AS REAL), unit_price, discount_percent, unit, description, ${cols3['updated_at']}, ${cols3['is_deleted']} FROM sale_items_old',
      );
      await txn.execute('DROP TABLE sale_items_old');

      // 4. Table purchase_order_items
      await txn.execute(
        'ALTER TABLE purchase_order_items RENAME TO purchase_order_items_old',
      );
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS purchase_order_items(
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (order_id) REFERENCES purchase_orders (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
      final cols4 = await getOldCols('purchase_order_items_old');
      await txn.execute(
        'INSERT INTO purchase_order_items (id, order_id, product_id, quantity, unit_price, updated_at, is_deleted) SELECT id, order_id, product_id, CAST(quantity AS REAL), unit_price, ${cols4['updated_at']}, ${cols4['is_deleted']} FROM purchase_order_items_old',
      );
      await txn.execute('DROP TABLE purchase_order_items_old');

      // 5. Table purchase_items
      await txn.execute(
        'ALTER TABLE purchase_items RENAME TO purchase_items_old',
      );
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS purchase_items(
          id TEXT PRIMARY KEY,
          purchase_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_cost REAL NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
      final cols5 = await getOldCols('purchase_items_old');
      await txn.execute(
        'INSERT INTO purchase_items (id, purchase_id, product_id, quantity, unit_cost, updated_at, is_deleted) SELECT id, purchase_id, product_id, CAST(quantity AS REAL), unit_cost, ${cols5['updated_at']}, ${cols5['is_deleted']} FROM purchase_items_old',
      );
      await txn.execute('DROP TABLE purchase_items_old');

      // 6. Table quote_items
      await txn.execute('ALTER TABLE quote_items RENAME TO quote_items_old');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS quote_items(
          id TEXT PRIMARY KEY,
          quote_id TEXT NOT NULL,
          product_id TEXT,
          custom_name TEXT,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          unit TEXT,
          description TEXT,
          discount_amount REAL NOT NULL DEFAULT 0.0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (quote_id) REFERENCES quotes (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
        )
      ''');
      final cols6 = await getOldCols('quote_items_old');
      await txn.execute(
        'INSERT INTO quote_items (id, quote_id, product_id, custom_name, quantity, unit_price, unit, description, discount_amount, updated_at, is_deleted) SELECT id, quote_id, product_id, custom_name, CAST(quantity AS REAL), unit_price, unit, description, discount_amount, ${cols6['updated_at']}, ${cols6['is_deleted']} FROM quote_items_old',
      );
      await txn.execute('DROP TABLE quote_items_old');

      // 7. Table stock_audit_items
      await txn.execute(
        'ALTER TABLE stock_audit_items RENAME TO stock_audit_items_old',
      );
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS stock_audit_items (
          id TEXT PRIMARY KEY,
          audit_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          theoretical_qty REAL NOT NULL,
          actual_qty REAL NOT NULL,
          difference REAL NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (audit_id) REFERENCES stock_audits (id) ON DELETE CASCADE
        )
      ''');
      final cols7 = await getOldCols('stock_audit_items_old');
      await txn.execute(
        'INSERT INTO stock_audit_items (id, audit_id, product_id, theoretical_qty, actual_qty, difference, updated_at, is_deleted) SELECT id, audit_id, product_id, CAST(theoretical_qty AS REAL), CAST(actual_qty AS REAL), CAST(difference AS REAL), ${cols7['updated_at']}, ${cols7['is_deleted']} FROM stock_audit_items_old',
      );
      await txn.execute('DROP TABLE stock_audit_items_old');

      // Re-create all indexes lost during drop/create
      await _createIndexes(txn);
    });
    debugPrint('✅ Migration v45 completed successfully.');
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

  Future<void> _ensureCreditAmountColumn(Database db) async {
    try {
      final salesInfo = await db.rawQuery("PRAGMA table_info(sales)");
      final hasCreditCol = salesInfo.any(
        (col) => col['name'] == 'credit_amount',
      );
      if (!hasCreditCol) {
        debugPrint(
          'Manual Fix: Adding missing credit_amount column explicitly',
        );
        await db.execute(
          'ALTER TABLE sales ADD COLUMN credit_amount REAL NOT NULL DEFAULT 0.0',
        );
      }
    } catch (e) {
      debugPrint('Error in _ensureCreditAmountColumn: $e');
    }
  }

  /// Creates all performance indexes. Called by both _onCreate and _onUpgrade v16.
  Future<void> _createIndexes(DatabaseExecutor db) async {
    // Products: search by name, barcode, category
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)',
    );

    // Sales: search by date, client, status
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_client ON sales(client_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_user ON sales(user_id)',
    );

    // Sale items: join on sale_id and product_id
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)',
    );

    // Stock movements: search by product and date
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(date)',
    );

    // Financial transactions: search by account, date, category
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_account ON financial_transactions(account_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON financial_transactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON financial_transactions(category)',
    );

    // Purchase orders
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier ON purchase_orders(supplier_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_order_items_order ON purchase_order_items(order_id)',
    );

    // Purchases (v14+)
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON purchases(supplier_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id)',
    );

    // Warehouse stock
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON warehouse_stock(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)',
    );

    // Quotes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quotes_client ON quotes(client_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quote_items_quote ON quote_items(quote_id)',
    );

    // Client & supplier payments
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_client_payments_client ON client_payments(client_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_payments_supplier ON supplier_payments(supplier_id)',
    );

    // Cash sessions
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cash_sessions_user ON cash_sessions(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cash_sessions_status ON cash_sessions(status)',
    );

    // Stock audits
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_audit_items_audit ON stock_audit_items(audit_id)',
    );

    // Activity Logs
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_logs_date ON activity_logs(date)',
    );

    // HR
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contracts_user ON employee_contracts(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payrolls_user ON payrolls(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_leave_requests_user ON leave_requests(user_id)',
    );
  }

  // v43: HR Module
  Future<void> _migrateToV43(Database db) async {
    // Add user HR profile columns
    try {
      await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN birth_date TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN hire_date TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN nationality TEXT');
    } catch (_) {}
    try {
      await db.execute(
        "ALTER TABLE users ADD COLUMN permissions TEXT NOT NULL DEFAULT '{}'",
      );
    } catch (_) {}

    // Create HR tables
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

    // HR indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contracts_user ON employee_contracts(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payrolls_user ON payrolls(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_leave_requests_user ON leave_requests(user_id)',
    );
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

  Future<void> _migrateToV47(Database db) async {
    debugPrint('🚀 Migration v47 (SUPREME Performance: FTS5) starting...');
    await db.transaction((txn) async {
      // 1. Create Virtual Table for Products
      await txn.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(
          id UNINDEXED, 
          name, 
          barcode, 
          reference, 
          category,
          tokenize='unicode61'
        );
      ''');

      // 2. Initial synchronization: Hydrate FTS table from existing products
      await txn.execute('''
        INSERT INTO products_fts(id, name, barcode, reference, category)
        SELECT id, name, barcode, reference, category FROM products;
      ''');

      // 3. Automated Sync Triggers (Supreme Reliability)
      // Insert
      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS products_ai AFTER INSERT ON products BEGIN
          INSERT INTO products_fts(id, name, barcode, reference, category) 
          VALUES (new.id, new.name, new.barcode, new.reference, new.category);
        END;
      ''');

      // Delete
      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS products_ad AFTER DELETE ON products BEGIN
          DELETE FROM products_fts WHERE id = old.id;
        END;
      ''');

      // Update
      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS products_au AFTER UPDATE ON products BEGIN
          DELETE FROM products_fts WHERE id = old.id;
          INSERT INTO products_fts(id, name, barcode, reference, category) 
          VALUES (new.id, new.name, new.barcode, new.reference, new.category);
        END;
      ''');
    });
    debugPrint('✅ Migration v47 (FTS5 Engine) completed successfully.');
  }

  Future<void> _migrateToV49(Database db) async {
    debugPrint(
      '🚀 Migration v49 (SUPREME Performance: Clients FTS5) starting...',
    );
    await db.transaction((txn) async {
      // 1. Create Virtual Table for Clients
      await txn.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS clients_fts USING fts5(
          id UNINDEXED, 
          name, 
          phone, 
          address,
          email,
          tokenize='unicode61'
        );
      ''');

      // 2. Initial synchronization
      await txn.execute('''
        INSERT INTO clients_fts(id, name, phone, address, email)
        SELECT id, name, phone, address, email FROM clients;
      ''');

      // 3. Triggers
      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS clients_ai AFTER INSERT ON clients BEGIN
          INSERT INTO clients_fts(id, name, phone, address, email) 
          VALUES (new.id, new.name, new.phone, new.address, new.email);
        END;
      ''');

      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS clients_ad AFTER DELETE ON clients BEGIN
          DELETE FROM clients_fts WHERE id = old.id;
        END;
      ''');

      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS clients_au AFTER UPDATE ON clients BEGIN
          DELETE FROM clients_fts WHERE id = old.id;
          INSERT INTO clients_fts(id, name, phone, address, email) 
          VALUES (new.id, new.name, new.phone, new.address, new.email);
        END;
      ''');
    });
    debugPrint('✅ Migration v49 (Clients FTS5) completed successfully.');
  }

  Future<void> _migrateToV50(Database db) async {
    debugPrint('🚀 Migration v50 (Adding cost_price to sale_items)...');
    try {
      await db.execute(
        'ALTER TABLE sale_items ADD COLUMN cost_price REAL NOT NULL DEFAULT 0.0',
      );
      debugPrint('✅ Migration v50 completed successfully.');
    } catch (e) {
      if (e.toString().contains('duplicate column name')) {
        debugPrint('⚠️ Migration v50: Column cost_price already exists.');
      } else {
        rethrow;
      }
    }
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
}
