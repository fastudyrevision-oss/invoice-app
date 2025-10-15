import '../dao/supplier_dao.dart';
import '../dao/supplier_payment_dao.dart';
import '../dao/supplier_report_dao.dart';
import '../dao/supplier_company_dao.dart';
import '../models/supplier.dart';
import '../models/supplier_payment.dart';
import '../models/supplier_report.dart';
import '../models/supplier_company.dart';

class SupplierRepository {
  final SupplierDao _supplierDao;
  final SupplierPaymentDao _paymentDao;
  final SupplierReportDao _reportDao;
  final SupplierCompanyDao _companyDao;

  SupplierRepository(
    this._supplierDao,
    this._paymentDao,
    this._reportDao,
    this._companyDao,
  );

  /// ===/// ===========================
/// SUPPLIERS
  /// ===========================
  Future<List<Supplier>> getAllSuppliers({bool showDeleted = false}) async {
    return _supplierDao.getAllSuppliers(showDeleted: showDeleted);
  }

  Future<Supplier?> getSupplierById(String id) async {
    return _supplierDao.getSupplierById(id);
  }

  Future<void> insertSupplier(Supplier supplier) async {
    final now = DateTime.now().toIso8601String();
    final newSupplier = supplier.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    await _supplierDao.insertSupplier(newSupplier);
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final updated = supplier.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _supplierDao.updateSupplier(updated);
  }

  /// Soft delete
  Future<void> deleteSupplier(String id) async {
    await _supplierDao.deleteSupplier(id); // soft delete
  }

  /// Restore previously deleted supplier
  Future<void> restoreSupplier(String id) async {
    await _supplierDao.restoreSupplier(id);
  }

  /// 🔍 Search suppliers by name/phone
  Future<List<Supplier>> searchSuppliers(String keyword, {bool showDeleted = false}) async {
    final all = await _supplierDao.getAllSuppliers(showDeleted: showDeleted);
    return all.where((s) =>
      s.name.toLowerCase().contains(keyword.toLowerCase()) ||
      (s.phone?.toLowerCase().contains(keyword.toLowerCase()) ?? false)
    ).toList();
  }


  /// ===========================
  /// PAYMENTS
  /// ===========================
  Future<List<SupplierPayment>> getPayments(String supplierId) async {
    return _paymentDao.getPayments(supplierId);
  }

  Future<void> addPayment(String supplierId, double amount, {String note = ""}) async {
    final payment = SupplierPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplierId: supplierId,
      amount: amount,
      date: DateTime.now().toIso8601String(),
      note: note,
    );

    await _paymentDao.insertPayment(payment);

    // ✅ Reduce supplier pending
    final supplier = await _supplierDao.getSupplierById(supplierId);
    if (supplier != null) {
      final updated = supplier.copyWith(
        pendingAmount: (supplier.pendingAmount - amount).clamp(0, double.infinity),
      );
      await _supplierDao.updateSupplier(updated);
    }
  }

  /// ===========================
  /// COMPANIES
  /// ===========================
  /// ===========================
/// COMPANIES
/// ===========================
  Future<List<SupplierCompany>> getAllCompanies({bool showDeleted = false}) {
  return _companyDao.getAllCompanies(showDeleted: showDeleted);
}


  Future<void> deleteCompany(String id) async {
    await _companyDao.deleteCompany(id); // soft delete
  }

  Future<void> restoreCompany(String id) async {
    await _companyDao.restoreCompany(id);
  }

  Future<SupplierCompany?> getCompanyById(String id) async {
    return _companyDao.getCompanyById(id);
  }

  Future<void> insertCompany(SupplierCompany company) async {
    final now = DateTime.now().toIso8601String();
    final newCompany = company.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    await _companyDao.insertCompany(newCompany);
  }

  Future<void> updateCompany(SupplierCompany company) async {
    final updated = company.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _companyDao.updateCompany(updated);
  }

  

  /// 🔍 Search companies by name / notes / phone
  Future<List<SupplierCompany>> searchCompanies(String keyword) async {
    final all = await _companyDao.getAllCompanies();
    return all.where((c) =>
      c.name.toLowerCase().contains(keyword.toLowerCase()) ||
      (c.phone?.toLowerCase().contains(keyword.toLowerCase()) ?? false) ||
      (c.notes?.toLowerCase().contains(keyword.toLowerCase()) ?? false)
    ).toList();
  }

  /// ===========================
  /// REPORTS
  /// ===========================
  Future<List<SupplierReport>> getSupplierReports(
      String startDate, String endDate) async {
    return _reportDao.getReports(startDate, endDate);
  }
}
