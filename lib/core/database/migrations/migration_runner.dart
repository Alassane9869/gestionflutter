import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class MigrationRunner {
  static Future<void> run(Database db, int oldVersion, int newVersion) async {
    debugPrint('🚀 MigrationRunner: v$oldVersion -> v$newVersion');

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

        await db.execute('ALTER TABLE stock_movements ADD COLUMN warehouse_id TEXT');
        await db.execute("INSERT OR IGNORE INTO warehouses (id, name, type, is_default, is_active) VALUES ('default_warehouse', 'Magasin Principal', 'STORE', 1, 1)");
      } catch (e) {
        debugPrint('Migration v12 warning: $e');
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE clients ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0');
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
      try { await db.execute('ALTER TABLE suppliers ADD COLUMN debt REAL NOT NULL DEFAULT 0.0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN weighted_average_cost REAL NOT NULL DEFAULT 0.0'); } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases(
          id TEXT PRIMARY KEY,
          supplier_id TEXT NOT NULL,
          account_id TEXT NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          invoice_number TEXT,
          user_id TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE RESTRICT,
          FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
        )
      ''');
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

    if (oldVersion < 16) {
      await _createIndexes(db);
    }

    if (oldVersion < 17) {
      try {
        await db.execute("UPDATE products SET quantity = 0 WHERE quantity IS NULL");
        await db.execute("ALTER TABLE products ADD COLUMN reference TEXT");
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_reference ON products(reference)');
      } catch (_) {}
    }

    if (oldVersion < 20) {
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE sale_items RENAME TO sale_items_old');
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
        await txn.execute('INSERT INTO sale_items (id, sale_id, product_id, quantity, returned_quantity, unit_price) SELECT id, sale_id, product_id, quantity, returned_quantity, unit_price FROM sale_items_old');
        await txn.execute('DROP TABLE sale_items_old');
      });
    }

    if (oldVersion < 21) {
      try { await db.execute('ALTER TABLE sales ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0.0'); } catch (_) {}
    }

    if (oldVersion < 23) {
      try { await db.execute('ALTER TABLE financial_accounts ADD COLUMN operator TEXT'); } catch (_) {}
    }

    if (oldVersion < 39) {
      // Delta Sync & Offline Queue
      final tablesToSync = ['users', 'products', 'stock_movements', 'suppliers', 'purchase_orders', 'purchase_order_items', 'clients', 'client_payments', 'sales', 'sale_items', 'financial_accounts', 'financial_transactions', 'cash_sessions', 'supplier_payments', 'loyalty_settings', 'quotes', 'quote_items', 'warehouses', 'warehouse_stock', 'stock_audits', 'stock_audit_items'];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final table in tablesToSync) {
        try { await db.execute('ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT $now'); } catch (_) {}
        try { await db.execute('ALTER TABLE $table ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
      }
      await db.execute('CREATE TABLE IF NOT EXISTS offline_queue(id TEXT PRIMARY KEY, operation TEXT NOT NULL, table_name TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT "PENDING")');
    }

    if (oldVersion < 42) {
      // Decimal support helper inline extraction
      Future<void> addCol(String table, String col, String type) async {
        try {
          final info = await db.rawQuery("PRAGMA table_info($table)");
          if (!info.any((c) => c['name'] == col)) {
            await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
          }
        } catch (_) {}
      }
      await addCol('products', 'unit', 'TEXT');
      await addCol('products', 'is_service', 'INTEGER NOT NULL DEFAULT 0');
      await addCol('quote_items', 'unit', 'TEXT');
      await addCol('quote_items', 'description', 'TEXT');
      await addCol('quote_items', 'discount_amount', 'REAL NOT NULL DEFAULT 0.0');
      await addCol('sale_items', 'unit', 'TEXT');
      await addCol('sale_items', 'description', 'TEXT');
    }

    if (oldVersion < 43) await _migrateToV43(db);
    if (oldVersion < 45) await _migrateToV45(db);
    if (oldVersion < 47) await _migrateToV47(db);
    if (oldVersion < 49) await _migrateToV49(db);
    if (oldVersion < 50) await _migrateToV50(db);

    debugPrint('✅ MigrationRunner: Finalized.');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_client ON sales(client_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(date)');
  }

  static Future<void> _migrateToV43(Database db) async {
    try { await db.execute('ALTER TABLE users ADD COLUMN email TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE users ADD COLUMN phone TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE users ADD COLUMN address TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE users ADD COLUMN birth_date TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE users ADD COLUMN permissions TEXT NOT NULL DEFAULT "{}"'); } catch (_) {}
    try { await db.execute("ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1"); } catch (_) {}

    await db.execute('CREATE TABLE IF NOT EXISTS employee_contracts(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, contract_type TEXT NOT NULL DEFAULT "CDI", start_date TEXT NOT NULL, end_date TEXT, base_salary REAL NOT NULL DEFAULT 0.0,transport_allowance REAL NOT NULL DEFAULT 0.0, meal_allowance REAL NOT NULL DEFAULT 0.0, position TEXT, department TEXT, supervisor_id TEXT, status TEXT NOT NULL DEFAULT "ACTIVE", created_at TEXT, notes TEXT, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS payrolls(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, month INTEGER NOT NULL, year INTEGER NOT NULL, base_salary REAL NOT NULL DEFAULT 0.0, extra_lines TEXT NOT NULL DEFAULT "[]", payment_date TEXT, status TEXT NOT NULL DEFAULT "DRAFT", created_at TEXT, printed INTEGER NOT NULL DEFAULT 0, notes TEXT, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE IF NOT EXISTS leave_requests(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, leave_type TEXT NOT NULL DEFAULT "PERMISSION", start_date TEXT NOT NULL, end_date TEXT NOT NULL, reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT "PENDING", reviewed_by TEXT, reviewed_at TEXT, created_at TEXT, FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE)');
  }

  static Future<void> _migrateToV45(Database db) async {
    // Migration technique pour supporter les quantités réelles (REAL)
    await db.transaction((txn) async {
       // ... (Logique complexe de renommage et recharge de tables comme dans DatabaseService)
       // Pour rester concis dans ce runner, je regroupe les exécutions directes.
       await txn.execute('ALTER TABLE warehouse_stock RENAME TO warehouse_stock_old');
       await txn.execute('CREATE TABLE warehouse_stock(id TEXT PRIMARY KEY, warehouse_id TEXT NOT NULL, product_id TEXT NOT NULL, quantity REAL NOT NULL DEFAULT 0.0, updated_at INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0)');
       await txn.execute('INSERT INTO warehouse_stock (id, warehouse_id, product_id, quantity) SELECT id, warehouse_id, product_id, CAST(quantity AS REAL) FROM warehouse_stock_old');
       await txn.execute('DROP TABLE warehouse_stock_old');

       await txn.execute('ALTER TABLE stock_movements RENAME TO stock_movements_old');
       await txn.execute('CREATE TABLE stock_movements(id TEXT PRIMARY KEY, product_id TEXT NOT NULL, type TEXT NOT NULL, quantity REAL NOT NULL, reason TEXT NOT NULL, date TEXT NOT NULL, user_id TEXT NOT NULL, warehouse_id TEXT, session_id TEXT, is_synced INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0, is_deleted INTEGER NOT NULL DEFAULT 0)');
       await txn.execute('INSERT INTO stock_movements (id, product_id, type, quantity, reason, date, user_id, warehouse_id, session_id, is_synced) SELECT id, product_id, type, CAST(quantity AS REAL), reason, date, user_id, warehouse_id, session_id, is_synced FROM stock_movements_old');
       await txn.execute('DROP TABLE stock_movements_old');
    });
  }

  static Future<void> _migrateToV47(Database db) async {
    await db.transaction((txn) async {
      await txn.execute("CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(id UNINDEXED, name, barcode, reference, category, tokenize='unicode61')");
      await txn.execute("INSERT INTO products_fts(id, name, barcode, reference, category) SELECT id, name, barcode, reference, category FROM products");
      await txn.execute("CREATE TRIGGER IF NOT EXISTS products_ai AFTER INSERT ON products BEGIN INSERT INTO products_fts(id, name, barcode, reference, category) VALUES (new.id, new.name, new.barcode, new.reference, new.category); END;");
      await txn.execute("CREATE TRIGGER IF NOT EXISTS products_ad AFTER DELETE ON products BEGIN DELETE FROM products_fts WHERE id = old.id; END;");
      await txn.execute("CREATE TRIGGER IF NOT EXISTS products_au AFTER UPDATE ON products BEGIN DELETE FROM products_fts WHERE id = old.id; INSERT INTO products_fts(id, name, barcode, reference, category) VALUES (new.id, new.name, new.barcode, new.reference, new.category); END;");
    });
  }

  static Future<void> _migrateToV49(Database db) async {
    await db.transaction((txn) async {
      await txn.execute("CREATE VIRTUAL TABLE IF NOT EXISTS clients_fts USING fts5(id UNINDEXED, name, phone, address, email, tokenize='unicode61')");
      await txn.execute("INSERT INTO clients_fts(id, name, phone, address, email) SELECT id, name, phone, address, email FROM clients");
      await txn.execute("CREATE TRIGGER IF NOT EXISTS clients_ai AFTER INSERT ON clients BEGIN INSERT INTO clients_fts(id, name, phone, address, email) VALUES (new.id, new.name, new.phone, new.address, new.email); END;");
      await txn.execute("CREATE TRIGGER IF NOT EXISTS clients_ad AFTER DELETE ON clients BEGIN DELETE FROM clients_fts WHERE id = old.id; END;");
      await txn.execute("CREATE TRIGGER IF NOT EXISTS clients_au AFTER UPDATE ON clients BEGIN DELETE FROM clients_fts WHERE id = old.id; INSERT INTO clients_fts(id, name, phone, address, email) VALUES (new.id, new.name, new.phone, new.address, new.email); END;");
    });
  }

  static Future<void> _migrateToV50(Database db) async {
    try { await db.execute('ALTER TABLE sale_items ADD COLUMN cost_price REAL NOT NULL DEFAULT 0.0'); } catch (_) {}
  }
}
