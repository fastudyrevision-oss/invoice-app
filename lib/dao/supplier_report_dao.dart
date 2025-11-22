import '../db/database_helper.dart';
import '../models/supplier_report.dart';

class SupplierReportDao {
  final dbHelper = DatabaseHelper();

  /// Supplier-wise report
  Future<List<SupplierReport>> getSupplierReports({
    required String startDate,
    required String endDate,
  }) async {
    final data = await dbHelper.rawQuery(
      """
      SELECT 
        s.id as supplier_id, 
        s.name as supplier_name, 
        c.name as company_name,
        IFNULL(SUM(p.total), 0) as total_purchases,
        IFNULL(SUM(p.paid), 0) as total_paid,
        IFNULL(SUM(p.pending), 0) as total_pending
      FROM suppliers s
      LEFT JOIN supplier_companies c ON s.company_id = c.id
      LEFT JOIN purchases p ON p.supplier_id = s.id
      WHERE p.date BETWEEN ? AND ?
      GROUP BY s.id, s.name, c.name
    """,
      [startDate, endDate],
    );

    return data.map((e) => SupplierReport.fromMap(e)).toList();
  }

  /// Company-wise report
  Future<List<SupplierReport>> getCompanyReports({
    required String startDate,
    required String endDate,
  }) async {
    final data = await dbHelper.rawQuery(
      """
      SELECT 
        c.id as supplier_id, 
        c.name as company_name,
        NULL as supplier_name,
        IFNULL(SUM(p.total), 0) as total_purchases,
        IFNULL(SUM(p.paid), 0) as total_paid,
        IFNULL(SUM(p.pending), 0) as total_pending
      FROM supplier_companies c
      LEFT JOIN suppliers s ON s.company_id = c.id
      LEFT JOIN purchases p ON p.supplier_id = s.id
      WHERE p.date BETWEEN ? AND ?
      GROUP BY c.id, c.name
    """,
      [startDate, endDate],
    );

    return data.map((e) => SupplierReport.fromMap(e)).toList();
  }

  /// 🔥 Combined method for repo (default: supplier-wise)
  Future<List<SupplierReport>> getReports(
    String startDate,
    String endDate, {
    bool byCompany = false,
  }) async {
    if (byCompany) {
      return getCompanyReports(startDate: startDate, endDate: endDate);
    } else {
      return getSupplierReports(startDate: startDate, endDate: endDate);
    }
  }

  /// Optional: return both supplier + company
  Future<Map<String, List<SupplierReport>>> getFullReport({
    required String startDate,
    required String endDate,
  }) async {
    final suppliers = await getSupplierReports(
      startDate: startDate,
      endDate: endDate,
    );
    final companies = await getCompanyReports(
      startDate: startDate,
      endDate: endDate,
    );

    return {"suppliers": suppliers, "companies": companies};
  }
}
