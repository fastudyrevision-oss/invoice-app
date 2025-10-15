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

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance; // ✅ Add this


  sqflite.Database? _db; // SQLite DB
  sembast.Database? _webDb; // Sembast DB for web

  // Stores for Sembast
  final Map<String, sembast.StoreRef<String, Map<String, dynamic>>> _stores = {};

  final List<String> _tables = [
    "users",
    "customers",
    "supplier_companies",
    "suppliers",
    "products",
    "product_batches",
    "invoices",
    "invoice_items",
    "purchases",
    "purchase_items",
    "customer_payments",
    "supplier_payments",
    "expenses",
    "ledger",
    "audit_logs",
    "attachments"
  ];

  /// Initialize database
  Future<void> init() async {
    if (kIsWeb) {
      // Web: Sembast
      _webDb = await sembast_web.databaseFactoryWeb.openDatabase('invoice_app.db');
      for (var table in _tables) {
        _stores[table] = sembast.stringMapStoreFactory.store(table);
      }
    } else {
      // Desktop FFI initialization
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqflite_ffi.sqfliteFfiInit();
        sqflite.databaseFactory = sqflite_ffi.databaseFactoryFfi;
      }

      // Mobile/Desktop: SQLite
      final dbPath = await sqflite.getDatabasesPath();
      final path = join(dbPath, "invoice_app.db");
      _db = await sqflite.openDatabase(
        path,
        version: 1,
        onConfigure: (sqflite.Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      );
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


  // ================== CREATE TABLES FOR SQLite ==================
  Future _onCreate(sqflite.Database db, int version) async {
    // USERS
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        password_hash TEXT,
        role TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // CUSTOMERS
    await db.execute('''
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
    await db.execute('''
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
    await db.execute('''
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

    // PRODUCTS
    await db.execute('''
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
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE SET NULL
      )
    ''');

    // PRODUCT BATCHES
    await db.execute('''
      CREATE TABLE product_batches (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
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
        FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE SET NULL
      )
    ''');

    // INVOICES
    await db.execute('''
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
    await db.execute('''
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
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // PURCHASES
    await db.execute('''
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
    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT,
        product_id TEXT,
        qty INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        sell_price REAL,
        batch_no TEXT,
        expiry_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
      )
    ''');

    // CUSTOMER PAYMENTS
    await db.execute('''
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
    await db.execute('''
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
    await db.execute('''
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

    // LEDGER
    await db.execute('''
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
    await db.execute('''
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
    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        related_table TEXT,
        related_id TEXT,
        file_path TEXT,
        mime_type TEXT,
        uploaded_by TEXT,
        uploaded_at TEXT
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_product_batches_expiry ON product_batches(expiry_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON invoices(customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_purchases_supplier_id ON purchases(supplier_id)');
    await db.execute('ALTER TABLE products ADD COLUMN is_deleted INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE purchase_items ADD COLUMN product_name TEXT');
    await db.execute('ALTER TABLE purchase_items ADD COLUMN cost_price REAL DEFAULT 0');
  }

  // ================== GENERIC CRUD ==================
  Future<int> insert(String table, Map<String, dynamic> row) async {
    if (kIsWeb) {
      await _stores[table]!.record(row['id']).put(_webDb!, row);
      return 1;
    } else {
      final dbClient = await db;
      return await dbClient.insert(
          table, row,
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
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

  Future<List<Map<String, dynamic>>> queryWhere(String table, String where,
      List<Object?> whereArgs) async {
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

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
      [List<Object?>? arguments]) async {
    if (kIsWeb) {
      sql = sql.toLowerCase();
      if (sql.startsWith("select") && sql.contains("from")) {
        final table = sql.split("from")[1].trim().split(" ")[0];
        return (await _stores[table]!.find(_webDb!)).map((r) => r.value).toList();
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
      return await dbClient.update(table, row, where: "id = ?", whereArgs: [id]);
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


}
