// lib/repositories/report_repository.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:invoice_app/db/database_helper.dart';
import 'package:invoice_app/models/reports/supplier_report.dart';
import 'package:invoice_app/models/reports/product_report.dart';
import 'package:invoice_app/models/reports/expense_report.dart';
import 'package:invoice_app/models/reports/expiry_report.dart';
import 'package:invoice_app/models/reports/payment_report.dart';

class ReportRepository {
  final dbHelper = DatabaseHelper.instance;

  // ---------- Helpers ----------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime(2100, 1, 1);

    final s = raw.toString().trim();

    try {
      // Case 1: full ISO or yyyy-MM-dd
      if (s.contains('-')) {
        return DateTime.parse(s);
      }

      // Case 2: only year, e.g. "2027"
      if (RegExp(r'^\d{4}$').hasMatch(s)) {
        return DateTime(int.parse(s), 12, 31); // assume end of year
      }

      // Case 3: yyyyMM (like 202712 → Dec 2027)
      if (RegExp(r'^\d{6}$').hasMatch(s)) {
        final year = int.parse(s.substring(0, 4));
        final month = int.parse(s.substring(4, 6));
        return DateTime(year, month, 28);
      }

      // fallback
      return DateTime.parse(s);
    } catch (e) {
      return DateTime(2100, 1, 1); // very far future to avoid crashes
    }
  }

  // ---------- Supplier Reports ----------
  // ---------- Supplier Reports ----------
  Future<List<SupplierReport>> getSupplierReports() async {
    if (!kIsWeb) {
      final sql = '''
        SELECT 
          s.id AS supplier_id,
          s.name AS supplier_name,
          IFNULL(SUM(p.total), 0) AS total_purchases,
          IFNULL(SUM(p.paid), 0) AS total_paid,
          IFNULL(SUM(p.pending), 0) AS balance
        FROM suppliers s
        LEFT JOIN purchases p ON s.id = p.supplier_id
        GROUP BY s.id
      ''';
      final rows = await dbHelper.rawQuery(sql);
      return rows.map((r) => SupplierReport.fromMap(r)).toList();
    } else {
      final suppliers = await dbHelper.queryAll('suppliers');
      final purchases = await dbHelper.queryAll('purchases');

      final List<SupplierReport> out = [];
      for (final s in suppliers) {
        final sid = s['id'];

        // Filter purchases of this supplier
        final supplierPurchases = purchases.where(
          (p) => p['supplier_id'] == sid,
        );

        // Calculate total purchases, paid, and balance from purchase-level data
        final totalPurchases = supplierPurchases
            .map((p) => _toDouble(p['total']))
            .fold(0.0, (a, b) => a + b);

        final totalPaid = supplierPurchases
            .map((p) => _toDouble(p['paid']))
            .fold(0.0, (a, b) => a + b);

        final balance = supplierPurchases
            .map((p) => _toDouble(p['pending']))
            .fold(0.0, (a, b) => a + b);

        out.add(
          SupplierReport.fromMap({
            'supplier_id': sid,
            'supplier_name': s['name'] ?? '',
            'total_purchases': totalPurchases,
            'total_paid': totalPaid,
            'balance': balance,
          }),
        );
      }
      return out;
    }
  }

  // ---------- Product Reports ----------
  Future<List<ProductReport>> getProductReports() async {
    if (!kIsWeb) {
      final sql = '''
        SELECT 
          pr.id AS product_id,
          pr.name AS product_name,
          IFNULL(SUM(pi.qty), 0) AS total_qty_purchased,
          IFNULL(SUM(pi.purchase_price * pi.qty), 0) AS total_spent
        FROM products pr
        LEFT JOIN purchase_items pi ON pr.id = pi.product_id
        GROUP BY pr.id
      ''';
      final rows = await dbHelper.rawQuery(sql);
      return rows.map((r) => ProductReport.fromMap(r)).toList();
    } else {
      final products = await dbHelper.queryAll('products');
      final items = await dbHelper.queryAll('purchase_items');

      final List<ProductReport> out = [];
      for (final pr in products) {
        final pid = pr['id'];
        final totalQty = items
            .where((it) => it['product_id'] == pid)
            .map((it) => _toDouble(it['qty']))
            .fold(0.0, (a, b) => a + b);
        final totalSpent = items
            .where((it) => it['product_id'] == pid)
            .map((it) => _toDouble(it['purchase_price']) * _toDouble(it['qty']))
            .fold(0.0, (a, b) => a + b);
        out.add(
          ProductReport.fromMap({
            'product_id': pid,
            'product_name': pr['name'] ?? '',
            'total_qty_purchased': totalQty,
            'total_spent': totalSpent,
          }),
        );
      }
      return out;
    }
  }

  // ---------- Expense Reports ----------
  Future<List<ExpenseReport>> getExpenseReports() async {
    if (!kIsWeb) {
      final sql = '''
        SELECT 
          category,
          IFNULL(SUM(amount), 0) AS total_spent
        FROM expenses
        GROUP BY category
      ''';
      final rows = await dbHelper.rawQuery(sql);
      return rows.map((r) => ExpenseReport.fromMap(r)).toList();
    } else {
      final expenses = await dbHelper.queryAll('expenses');
      final Map<String, double> grouped = {};
      for (final e in expenses) {
        final cat = (e['category'] ?? 'general').toString();
        grouped[cat] = (grouped[cat] ?? 0.0) + _toDouble(e['amount']);
      }
      return grouped.entries
          .map(
            (en) => ExpenseReport.fromMap({
              'category': en.key,
              'total_spent': en.value,
            }),
          )
          .toList();
    }
  }

  // ---------- Expiry Reports ----------
  Future<List<ExpiryReport>> getExpiryReports({int days = 30}) async {
    if (!kIsWeb) {
      final sql =
          '''
        SELECT 
          pr.name AS product_name,
          pb.batch_no,
          pb.expiry_date,
          pb.qty
        FROM product_batches pb
        JOIN products pr ON pb.product_id = pr.id
        WHERE DATE(pb.expiry_date) <= DATE('now', '+$days days')
        ORDER BY pb.expiry_date ASC
      ''';
      final rows = await dbHelper.rawQuery(sql);
      return rows.map((r) => ExpiryReport.fromMap(r)).toList();
    } else {
      final batches = await dbHelper.queryAll('product_batches');
      final products = await dbHelper.queryAll('products');
      final Map<String, Map<String, dynamic>> productById = {
        for (final p in products) p['id']: p,
      };

      final cutoff = DateTime.now().add(Duration(days: days));
      final List<ExpiryReport> out = [];

      for (final pb in batches) {
        final expiryRaw = pb['expiry_date'];
        final expiry = _parseDate(expiryRaw);
        if (expiry.isBefore(cutoff) || expiry.isAtSameMomentAs(cutoff)) {
          final prod = productById[pb['product_id']];
          final productName = prod != null ? (prod['name'] ?? '') : '';
          out.add(
            ExpiryReport.fromMap({
              'product_name': productName,
              'batch_no': pb['batch_no'] ?? '',
              'expiry_date': expiry.toIso8601String(),
              'qty': _toDouble(pb['qty']),
            }),
          );
        }
      }

      out.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return out;
    }
  }

  // ---------- Payment Reports ----------
  Future<List<PaymentReport>> getPaymentReports() async {
    if (!kIsWeb) {
      final sql = '''
        SELECT 
          s.name AS supplier_name,
          p.invoice_no AS reference,
          p.total AS debit,
          0 AS credit,
          p.date AS date
        FROM purchases p
        JOIN suppliers s ON s.id = p.supplier_id

        UNION ALL

        SELECT 
          s.name AS supplier_name,
          pay.transaction_ref AS reference,
          0 AS debit,
          pay.amount AS credit,
          pay.date AS date
        FROM supplier_payments pay
        JOIN suppliers s ON s.id = pay.supplier_id

        ORDER BY date ASC
      ''';
      final rows = await dbHelper.rawQuery(sql);
      return rows.map((r) => PaymentReport.fromMap(r)).toList();
    } else {
      final purchases = await dbHelper.queryAll('purchases');
      final payments = await dbHelper.queryAll('supplier_payments');

      final List<Map<String, dynamic>> merged = [];

      for (final p in purchases) {
        merged.add({
          'supplier_name': p['supplier_id'] != null
              ? (await _getSupplierName(p['supplier_id']))
              : '',
          'reference': p['invoice_no'] ?? '',
          'debit': _toDouble(p['total']),
          'credit': 0.0,
          'date': p['date'] ?? DateTime.now().toIso8601String(),
        });
      }

      for (final pay in payments) {
        merged.add({
          'supplier_name': pay['supplier_id'] != null
              ? (await _getSupplierName(pay['supplier_id']))
              : '',
          'reference': pay['transaction_ref'] ?? '',
          'debit': 0.0,
          'credit': _toDouble(pay['amount']),
          'date': pay['date'] ?? DateTime.now().toIso8601String(),
        });
      }

      merged.sort((a, b) {
        final da = _parseDate(a['date']);
        final dbt = _parseDate(b['date']);
        return da.compareTo(dbt);
      });

      return merged.map((m) => PaymentReport.fromMap(m)).toList();
    }
  }

  // ---------- Helper for Web ----------
  Future<String> _getSupplierName(String? supplierId) async {
    if (supplierId == null) return '';
    final rec = await dbHelper.queryById('suppliers', supplierId);
    return rec != null ? (rec['name'] ?? '') : '';
  }
}
