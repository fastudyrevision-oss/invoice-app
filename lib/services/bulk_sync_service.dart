import 'dart:convert';
import '../db/database_helper.dart';

class BulkSyncService {
  final dbHelper = DatabaseHelper.instance;

  /// Fetch all rows for a given table
  Future<List<Map<String, dynamic>>> fetchAllRows(String table) async {
    return await dbHelper.queryAll(table);
  }

  /// Prepare data in JSON format for Supabase
  Future<String> prepareJsonForBulkSync(String table) async {
    final rows = await fetchAllRows(table);

    // Optional: remove local-only fields like 'is_synced'
    final cleanedRows = rows.map((row) {
      final newRow = Map<String, dynamic>.from(row);
      newRow.remove('is_synced');
      return newRow;
    }).toList();

    return jsonEncode(cleanedRows);
  }

  /// Get list of tables that need syncing
  List<String> getSyncableTables() {
    return [
      'customers',
      'suppliers',
      'supplier_companies', // Added
      'products',
      'categories',
      'product_batches', // Added
      'invoices',
      'invoice_items', // Added
      'purchases',
      'purchase_items', // Added
      'customer_payments', // Added
      'supplier_payments', // Added
      'expenses', // Added
      'manual_entries', // Added
      'stock_disposal', // Added
    ];
  }
}
