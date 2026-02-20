import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:path/path.dart';

// SQFLite imports (mobile/desktop)
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;

// Sembast imports (for web)
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_io.dart' as sembast_io;
import 'package:sembast_web/sembast_web.dart' as sembast_web;
import 'package:path_provider/path_provider.dart';
import '../services/logger_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;

  sqflite.Database? _db; // SQLite DB
  sembast.Database? _webDb; // Sembast DB for web
  Completer<void>? _initCompleter; // Prevents race conditions during init

  // Stores for Sembast
  final Map<String, sembast.StoreRef<String, Map<String, dynamic>>> _stores =
      {};

  final List<String> _tables = [
    "users",
    "customers",
    "supplier_companies",
    "suppliers",
    "categories",
    "products",
    "product_batches",
    "invoices",
    "invoice_items",
    "purchases",
    "purchase_items",
    "customer_payments",
    "supplier_payments",
    "expenses",
    "manual_entries",
    "ledger",
    "audit_logs",
    "attachments",
    "stock_disposal",
  ];

  /// ✅ Factory for tests — In-memory SQLite instance
  factory DatabaseHelper.testInstance() {
    final helper = DatabaseHelper._internal();
    sqflite_ffi.sqfliteFfiInit();
    sqflite.databaseFactory = sqflite_ffi.databaseFactoryFfi;
    helper._db = null; // Reset
    return helper;
  }

  /// ✅ For tests: open an in-memory database
  Future<sqflite.Database> openInMemoryDb() async {
    sqflite_ffi.sqfliteFfiInit();
    sqflite.databaseFactory = sqflite_ffi.databaseFactoryFfi;
    _db = await sqflite.openDatabase(sqflite.inMemoryDatabasePath, version: 1);
    return _db!;
  }

  /// ✅ For tests: delete the current DB
  Future<void> deleteDatabase() async {
    if (!kIsWeb && _db != null) {
      final dbPath = _db!.path;
      await sqflite.deleteDatabase(dbPath);
    }
    _db = null;
  }

  /// Initialize database
  Future<void> init() async {
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      if (kIsWeb) {
        // Web: Sembast
        _webDb = await sembast_web.databaseFactoryWeb.openDatabase(
          'invoice_app.db',
        );
        for (var table in _tables) {
          _stores[table] = sembast.stringMapStoreFactory.store(table);
        }
        logger.info('Database', "✅ Web database initialized");
      } else {
        // Desktop FFI initialization
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          sqflite_ffi.sqfliteFfiInit();
          sqflite.databaseFactory = sqflite_ffi.databaseFactoryFfi;
        }

        // Mobile/Desktop: SQLite
        String path;
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final appSupportDir = await getApplicationSupportDirectory();
          path = join(appSupportDir.path, "invoice_app.db");
          // Ensure directory exists
          await Directory(appSupportDir.path).create(recursive: true);
        } else {
          final dbPath = await sqflite.getDatabasesPath();
          path = join(dbPath, "invoice_app.db");
        }

        logger.info('Database', "📂 Opening database at: $path");

        _db = await sqflite.openDatabase(
          path,
          version: 1,
          singleInstance: true, // ✅ Prevent JNI locks on Android
          onConfigure: _onConfigure, // ✅ WAL mode
          onCreate: _onCreate,
        );

        logger.info('Database', "✅ Database opened successfully");

        // Run migrations manually for existing databases (since version is still 1)
        if (_db != null) {
          logger.info('Database', "🔄 Running database migrations...");
          try {
            // ✅ Wrap in transaction for atomicity and to prevent locks
            await _db!.transaction((txn) async {
              await _addColumnIfNotExistsDirect(
                txn,
                "users",
                "permissions",
                "TEXT",
              );
              await _addColumnIfNotExistsDirect(
                txn,
                "purchase_items",
                "cost_price",
                "REAL DEFAULT 0",
              );
              await _addColumnIfNotExistsDirect(
                txn,
                "purchase_items",
                "product_name",
                "TEXT",
              );
              await _addColumnIfNotExistsDirect(
                txn,
                "products",
                "is_deleted",
                "INTEGER DEFAULT 0",
              );

              await _addColumnIfNotExistsDirect(
                txn,
                "manual_entries",
                "category",
                "TEXT DEFAULT 'General'",
              );

              await _addColumnIfNotExistsDirect(
                txn,
                "invoice_items",
                "cost_price",
                "REAL NOT NULL DEFAULT 0",
              );

              // Data Migration: Populate existing invoice_items.cost_price from products.cost_price
              await txn.rawUpdate('''
                UPDATE invoice_items 
                SET cost_price = (
                  SELECT cost_price FROM products WHERE products.id = invoice_items.product_id
                )
                WHERE cost_price = 0 OR cost_price IS NULL
              ''');

              // Create manual_entries table if it doesn't exist
              await _createTableIfNotExistsTxn(txn, "manual_entries", '''
                  CREATE TABLE manual_entries (
                    id TEXT PRIMARY KEY,
                    description TEXT,
                    amount REAL,
                    type TEXT,
                    date TEXT,
                    category TEXT DEFAULT 'General'
                  )
                ''');

              // Create stock_disposal table if it doesn't exist
              await _createTableIfNotExistsTxn(txn, "stock_disposal", '''
                  CREATE TABLE stock_disposal (
                    id TEXT PRIMARY KEY,
                    batch_id TEXT NOT NULL,
                    product_id TEXT NOT NULL,
                    supplier_id TEXT,
                    qty INTEGER NOT NULL,
                    disposal_type TEXT NOT NULL,
                    cost_loss REAL NOT NULL,
                    refund_status TEXT,
                    refund_amount REAL DEFAULT 0,
                    notes TEXT,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(batch_id) REFERENCES product_batches(id) ON DELETE CASCADE,
                    FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
                    FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
                  )
                ''');

              // Add indexes for stock_disposal
              await txn.execute(
                'CREATE INDEX IF NOT EXISTS idx_stock_disposal_batch ON stock_disposal(batch_id)',
              );
              await txn.execute(
                'CREATE INDEX IF NOT EXISTS idx_stock_disposal_product ON stock_disposal(product_id)',
              );
              await txn.execute(
                'CREATE INDEX IF NOT EXISTS idx_stock_disposal_supplier ON stock_disposal(supplier_id)',
              );
            });

            logger.info('Database', "✅ Database migrations completed");
          } catch (e) {
            logger.warning('Database', "⚠️ Migration error (non-fatal): $e");
          }
        }

        logger.info('Database', "✅ SQLite database fully initialized");
      }
      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
    } catch (e, stackTrace) {
      logger.error(
        'Database',
        "❌ CRITICAL: Database initialization failed",
        error: e,
        stackTrace: stackTrace,
      );
      // Set databases to null to ensure app doesn't try to use them
      _db = null;
      _webDb = null;
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.completeError(e, stackTrace);
      }
      rethrow; // Re-throw to let main.dart handle it
    }
  }

  Future<dynamic> get db async {
    if (kIsWeb) {
      if (_webDb == null) throw Exception("Web database not initialized");
      return _webDb!;
    } else {
      if (_db == null) throw Exception("SQLite database not initialized");
      return _db!;
    }
  }

  /// Returns the file path for SQLite databases (mobile/desktop)
  Future<String?> get dbPath async {
    if (kIsWeb) return null; // Web does not have a physical file
    if (_db == null) throw Exception("Database not initialized");
    return _db!.path; // sqflite database path
  }

  /// Close the database safely (does nothing for web)
  Future<void> close() async {
    if (kIsWeb) return; // nothing to close for web
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // ================== CONFIGURATION ==================
  /// ✅ Configure WAL mode for performance
  Future<void> _onConfigure(sqflite.Database db) async {
    // WAL mode allows concurrent readers and writers
    await db.execute('PRAGMA foreign_keys = ON');

    if (!kIsWeb && Platform.isAndroid) {
      // WAL is especially beneficial on Android
      try {
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute(
          'PRAGMA synchronous = NORMAL',
        ); // Faster writes, slightly less safe on power loss but standard for mobile apps
      } catch (e) {
        logger.warning('Database', "⚠️ Failed to enable WAL mode: $e");
      }
    }
  }

  // ================== CREATE TABLES FOR SQLite ==================
  Future _onCreate(sqflite.Database db, int version) async {
    logger.info('Database', "🆕 Creating Schema (Version $version)...");
    final batch = db.batch();

    // USERS
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        password_hash TEXT,
        role TEXT,
        permissions TEXT, -- ✅ Added permissions
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // CUSTOMERS
    batch.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        pending_amount REAL DEFAULT 0,
        status TEXT DEFAULT 'active',
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // SUPPLIER COMPANIES
    batch.execute('''
      CREATE TABLE supplier_companies (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE,
        address TEXT,
        phone TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted INTEGER,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // SUPPLIERS
    batch.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        contact_person TEXT,
        company_id TEXT,
        address TEXT,
        pending_amount REAL DEFAULT 0,
        credit_limit REAL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        deleted INTEGER,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(company_id) REFERENCES supplier_companies(id) ON DELETE SET NULL
      )
    ''');
    // CATEGORIES
    batch.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        slug TEXT UNIQUE,
        description TEXT,
        parent_id TEXT,
        icon TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY(parent_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    batch.insert('categories', {
      'id': 'cat-001',
      'name': 'Uncategorized',
      'slug': 'uncategorized',
      'description': 'Default category for products without category',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_active': 1,
      'is_deleted': 0,
    });

    // PRODUCTS
    batch.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        sku TEXT,
        default_unit TEXT,
        cost_price REAL,
        sell_price REAL,
        quantity INTEGER DEFAULT 0,
        min_stock INTEGER DEFAULT 0,
        track_expiry INTEGER DEFAULT 0,
        supplier_id TEXT,
         category_id TEXT DEFAULT 'cat-001', -- NEW default
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0, -- ✅ Added directly to schema
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // PRODUCT BATCHES
    batch.execute('''
      CREATE TABLE product_batches (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        supplier_id TEXT,
        batch_no TEXT,
        expiry_date TEXT,
        qty INTEGER NOT NULL DEFAULT 0,
        purchase_price REAL,
        sell_price REAL,
        purchase_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL,
        FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE SET NULL
      )
    ''');

    // INVOICES
    batch.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        customer_name TEXT,
        invoice_no TEXT,
        total REAL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        paid REAL DEFAULT 0,
        pending REAL DEFAULT 0,
        status TEXT DEFAULT 'draft',
        date TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
      )
    ''');

    // INVOICE ITEMS
    batch.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT,
        product_id TEXT,
        qty INTEGER NOT NULL,
        price REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        batch_no TEXT,
        reserved_batches TEXT,
        cost_price REAL NOT NULL DEFAULT 0, -- ✅ Added for COGS accuracy
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // PURCHASES
    batch.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        supplier_id TEXT,
        invoice_no TEXT,
        total REAL,
        paid REAL DEFAULT 0,
        pending REAL DEFAULT 0,
        date TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
      )
    ''');

    // PURCHASE ITEMS
    batch.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT,
        product_id TEXT,
        qty INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        sell_price REAL,
        batch_no TEXT,
        expiry_date TEXT,
        product_name TEXT,     -- ✅ Added directly
        cost_price REAL DEFAULT 0, -- ✅ Added directly
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // CUSTOMER PAYMENTS
    batch.execute('''
      CREATE TABLE customer_payments (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        invoice_id TEXT,
        amount REAL NOT NULL,
        method TEXT DEFAULT 'cash',
        transaction_ref TEXT,
        note TEXT,
        date TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE SET NULL
      )
    ''');

    // SUPPLIER PAYMENTS
    batch.execute('''
      CREATE TABLE supplier_payments (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        purchase_id TEXT,
        amount REAL NOT NULL,
        method TEXT DEFAULT 'cash',
        transaction_ref TEXT,
        note TEXT,
        date TEXT,
        deleted INTEGER DEFAULT 0, 
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
        FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE SET NULL
      )
    ''');

    // EXPENSES
    batch.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        category TEXT DEFAULT 'general',
        amount REAL NOT NULL,
        date TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // MANUAL ENTRIES
    batch.execute('''
      CREATE TABLE manual_entries (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT DEFAULT 'General', -- ✅ Added for P&L breakdown
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // LEDGER
    batch.execute('''
      CREATE TABLE ledger (
        id TEXT PRIMARY KEY,
        entity_id TEXT,
        entity_type TEXT,
        date TEXT,
        description TEXT,
        debit REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        created_at TEXT
      )
    ''');

    // AUDIT LOGS
    batch.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        action TEXT,
        table_name TEXT,
        record_id TEXT,
        old_data TEXT,
        new_data TEXT,
        user_id TEXT,
        timestamp TEXT
      )
    ''');

    // ATTACHMENTS
    batch.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        entity_type TEXT,
        entity_id TEXT,
        file_path TEXT,
        file_name TEXT,
        file_type TEXT,
        created_at TEXT
      )
    ''');

    // STOCK DISPOSAL
    batch.execute('''
      CREATE TABLE stock_disposal (
        id TEXT PRIMARY KEY,
        batch_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        supplier_id TEXT,
        qty INTEGER NOT NULL,
        disposal_type TEXT NOT NULL,
        cost_loss REAL NOT NULL,
        refund_status TEXT,
        refund_amount REAL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(batch_id) REFERENCES product_batches(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
      )
    ''');
    // SYNC META TABLE
    batch.execute('''
    CREATE TABLE sync_meta (
      table_name TEXT PRIMARY KEY,
      last_synced_at TEXT
    )
  ''');

    // ==================== COMPREHENSIVE INDEXES ====================
    // Core name indexes (existing)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
    );

    // Date-based indexes for time-series queries (NEW)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_date ON purchases(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_payments_date ON customer_payments(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_payments_date ON supplier_payments(date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp)',
    );

    // Search optimization indexes (NEW)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_invoice_no ON invoices(invoice_no)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_phone ON suppliers(phone)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email)',
    );

    // Foreign key indexes for joins (existing + new)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON invoices(customer_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_supplier_id ON purchases(supplier_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_supplier_id ON products(supplier_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_batches_expiry ON product_batches(expiry_date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_batches_product_id ON product_batches(product_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_batches_supplier_id ON product_batches(supplier_id)',
    );

    // Status and filter indexes (NEW)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_track_expiry ON products(track_expiry)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_deleted ON suppliers(deleted)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_is_deleted ON products(is_deleted)',
    );

    // Inventory and stock management indexes (NEW)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_quantity ON products(quantity)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_min_stock ON products(min_stock)',
    );

    // Composite indexes for common query patterns (NEW)
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_customer_date ON invoices(customer_id, date DESC)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_supplier_date ON purchases(supplier_id, date DESC)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_batches_product_expiry ON product_batches(product_id, expiry_date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_supplier_deleted ON products(supplier_id, is_deleted)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_company_deleted ON suppliers(company_id, deleted)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_invoices_status_date ON invoices(status, date DESC)',
    );

    // Products extra column
    await addColumnIfNotExists(
      db,
      "products",
      "is_deleted",
      "INTEGER DEFAULT 0",
    );

    // Purchase items extra columns
    await addColumnIfNotExists(db, "purchase_items", "product_name", "TEXT");
    await addColumnIfNotExists(
      db,
      "purchase_items",
      "cost_price",
      "REAL DEFAULT 0",
    );
    // Users permissions
    await addColumnIfNotExists(db, "users", "permissions", "TEXT");

    await batch.commit(noResult: true);
    logger.info('Database', "✅ Schema created successfully");
  }

  /// Helper to add column if it doesn't exist (DIRECT VERSION - for use during init)
  /// Uses db parameter directly instead of getter to avoid circular dependency
  Future<void> _addColumnIfNotExistsDirect(
    sqflite.DatabaseExecutor db,
    String table,
    String column,
    String columnType,
  ) async {
    try {
      final result = await db.rawQuery("PRAGMA table_info($table);");
      final exists = result.any((row) => row['name'] == column);
      if (!exists) {
        logger.info('Database', "➕ Adding column $column to $table");
        await db.execute("ALTER TABLE $table ADD COLUMN $column $columnType;");
      }
    } catch (e) {
      logger.warning(
        'Database',
        "⚠️ Failed to add column $column to $table: $e",
      );
      // Don't rethrow - column might already exist
    }
  }

  /// Helper to add column if it doesn't exist (PUBLIC VERSION - for use after init)
  Future<void> addColumnIfNotExists(
    sqflite.Database db,
    String table,
    String column,
    String columnType,
  ) async {
    final result = await db.rawQuery("PRAGMA table_info($table);");
    final exists = result.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute("ALTER TABLE $table ADD COLUMN $column $columnType;");
    }
  }

  // ================== GENERIC CRUD ==================
  Future<int> insert(String table, Map<String, dynamic> row) async {
    if (kIsWeb) {
      await _stores[table]!.record(row['id']).put(_webDb!, row);
      return 1;
    } else {
      final dbClient = await db;
      return await dbClient.insert(
        table,
        row,
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    if (kIsWeb) {
      final records = await _stores[table]!.find(_webDb!);
      return records.map((e) => e.value).toList();
    } else {
      final dbClient = await db;
      return await dbClient.query(table);
    }
  }

  Future<Map<String, dynamic>?> queryById(String table, String id) async {
    if (kIsWeb) {
      return await _stores[table]!.record(id).get(_webDb!);
    } else {
      final dbClient = await db;
      final res = await dbClient.query(table, where: "id = ?", whereArgs: [id]);
      return res.isNotEmpty ? res.first : null;
    }
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    if (kIsWeb) {
      final records = await _stores[table]!.find(_webDb!);
      final filtered = records.where((record) {
        final value = record.value;
        final conditions = where.split("AND").map((c) => c.trim()).toList();
        for (int i = 0; i < conditions.length; i++) {
          final parts = conditions[i].split("=").map((p) => p.trim()).toList();
          final col = parts[0];
          if (value[col].toString() != whereArgs[i].toString()) return false;
        }
        return true;
      }).toList();
      return filtered.map((r) => r.value).toList();
    } else {
      final dbClient = await db;
      return await dbClient.query(table, where: where, whereArgs: whereArgs);
    }
  }

  /// ✅ PARALLEL PARSING HELPER
  /// Runs the query and passes the result to a computation function in a background isolate.
  /// This prevents large dataset mapping from freezing the UI.
  Future<T> queryAndParse<T>(
    String table,
    T Function(List<Map<String, dynamic>>) parser, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final List<Map<String, dynamic>> rawData;

    if (kIsWeb) {
      // Web doesn't support Isolates nicely for this, run on main thread
      rawData = await queryWhere(table, where ?? '', whereArgs ?? []);
    } else {
      final dbClient = await db;
      rawData = await dbClient.query(table, where: where, whereArgs: whereArgs);
    }

    // Offload parsing to background isolate
    return await compute(parser, rawData);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (kIsWeb) {
      sql = sql.toLowerCase();
      if (sql.startsWith("select") && sql.contains("from")) {
        final table = sql.split("from")[1].trim().split(" ")[0];
        return (await _stores[table]!.find(
          _webDb!,
        )).map((r) => r.value).toList();
      } else {
        throw Exception("rawQuery is limited on web (Sembast)");
      }
    } else {
      final dbClient = await db;
      return await dbClient.rawQuery(sql, arguments);
    }
  }

  Future<int> update(String table, Map<String, dynamic> row, String id) async {
    if (kIsWeb) {
      await _stores[table]!.record(id).put(_webDb!, row);
      return 1;
    } else {
      final dbClient = await db;
      return await dbClient.update(
        table,
        row,
        where: "id = ?",
        whereArgs: [id],
      );
    }
  }

  Future<int> delete(String table, String id) async {
    if (kIsWeb) {
      await _stores[table]!.record(id).delete(_webDb!);
      return 1;
    } else {
      final dbClient = await db;
      return await dbClient.delete(table, where: "id = ?", whereArgs: [id]);
    }
  }

  Future<T> runInTransaction<T>(Future<T> Function(dynamic txn) action) async {
    if (kIsWeb) {
      return await action(_webDb!);
    } else {
      final dbClient = await db;
      return await dbClient.transaction<T>((txn) async {
        return await action(txn);
      });
    }
  }

  Future<int> rawUpdate(String sql, List<Object?> args) async {
    final dbClient = await db;
    return await dbClient.rawUpdate(sql, args);
  }

  /// Helper method to create a table if it doesn't exist (TRANSACTION VERSION)
  Future<void> _createTableIfNotExistsTxn(
    sqflite.Transaction txn,
    String tableName,
    String createTableSql,
  ) async {
    try {
      // Check if table exists
      final result = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );

      if (result.isEmpty) {
        logger.info('Database', "📋 Creating table: $tableName");
        await txn.execute(createTableSql);
        logger.info('Database', "✅ Table $tableName created successfully");
      }
    } catch (e) {
      logger.error('Database', "⚠️ Error creating table $tableName", error: e);
      rethrow;
    }
  }
}
