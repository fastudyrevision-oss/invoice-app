import '../dao/supplier_payment_dao.dart';
import '../models/supplier_payment.dart';
import '../dao/supplier_dao.dart';
import '../repositories/purchase_repo.dart';
import '../models/purchase.dart';

class SupplierPaymentRepository {
  //create a db instance
  
  final SupplierPaymentDao _paymentDao;
  final SupplierDao _supplierDao;
  final PurchaseRepository _purchaseRepo; // ✅ Inject purchase repo
   // your Database instance
  SupplierPaymentRepository(
    this._paymentDao,
    this._supplierDao,
    this._purchaseRepo,
  );

  /// Get all payments for a supplier
  Future<List<SupplierPayment>> getPayments(
    String supplierId, {
    bool includeDeleted = false,
  }) {
    return _paymentDao.getPayments(supplierId, includeDeleted: includeDeleted);
  }

  /// Add a new payment
  Future<void> addPayment(
    String supplierId,
    double amount, {
    String? purchaseId,
    String? note,
    String? method,
    String? transactionRef,
  }) async {
    if (amount <= 0) throw Exception("Payment must be greater than zero");

    final now = DateTime.now().toIso8601String();

    final payment = SupplierPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplierId: supplierId,
      purchaseId: purchaseId,
      amount: amount,
      method: method,
      transactionRef: transactionRef,
      note: note,
      date: now,
      createdAt: now,
      updatedAt: now,
    );

    // 1️⃣ Insert payment record
    await _paymentDao.insertPayment(payment);

    // 2️⃣ Update purchase invoice if purchaseId is provided
    if (purchaseId != null) {
      final Purchase? purchase = await _purchaseRepo.getPurchaseById(purchaseId);
      if (purchase != null) {
        final oldPaid = _toDouble(purchase.paid);
        final oldPending = _toDouble(purchase.pending);

        final paymentApplied = amount > oldPending ? oldPending : amount;
        final newPaid = oldPaid + paymentApplied;
        final newPending = oldPending - paymentApplied;

        await _purchaseRepo.updatePurchase(
          purchase.copyWith(paid: newPaid, pending: newPending),
        );
      }
    }

    // 3️⃣ Recalculate supplier.pending from all purchases
    await _recalculateSupplierPending(supplierId);
  }

  /// Update an existing payment
  Future<void> updatePayment(SupplierPayment payment) async {
    final updatedPayment = payment.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _paymentDao.updatePayment(updatedPayment);
  }

  /// Soft delete a payment (mark deleted = 1)
  Future<void> softDeletePayment(SupplierPayment payment) async {
    await _paymentDao.softDeletePayment(payment.id);

    // 1️⃣ Revert purchase paid/pending if purchaseId exists
    if (payment.purchaseId != null) {
      final Purchase? purchase = await _purchaseRepo.getPurchaseById(payment.purchaseId!);
      if (purchase != null) {
        final newPaid = _toDouble(purchase.paid) - payment.amount;
        final newPending = _toDouble(purchase.pending) + payment.amount;
        await _purchaseRepo.updatePurchase(
          purchase.copyWith(
            paid: newPaid.clamp(0.0, double.infinity),
            pending: newPending,
          ),
        );
      }
    }

    // 2️⃣ Recalculate supplier.pending from all purchases
    await _recalculateSupplierPending(payment.supplierId);
  }

  /// Restore a soft-deleted payment (mark deleted = 0)
  Future<void> restorePayment(SupplierPayment payment) async {
    await _paymentDao.restorePayment(payment.id);

    // 1️⃣ Apply payment to purchase if purchaseId exists
    if (payment.purchaseId != null) {
      final Purchase? purchase = await _purchaseRepo.getPurchaseById(payment.purchaseId!);
      if (purchase != null) {
        final oldPaid = _toDouble(purchase.paid);
        final oldPending = _toDouble(purchase.pending);

        final paymentApplied = payment.amount > oldPending ? oldPending : payment.amount;
        final newPaid = oldPaid + paymentApplied;
        final newPending = oldPending - paymentApplied;

        await _purchaseRepo.updatePurchase(
          purchase.copyWith(paid: newPaid, pending: newPending),
        );
      }
    }

    // 2️⃣ Recalculate supplier.pending from all purchases
    await _recalculateSupplierPending(payment.supplierId);
  }

  /// Search / filter payments
  Future<List<SupplierPayment>> searchPayments(
    String supplierId, {
    String? keyword,
    DateTime? start,
    DateTime? end,
    bool includeDeleted = false,
  }) async {
    final all = await _paymentDao.getPayments(supplierId, includeDeleted: includeDeleted);

    return all.where((p) {
      final noteText = p.note ?? "";
      final matchNote = keyword == null || noteText.toLowerCase().contains(keyword.toLowerCase());

      final paymentDate = DateTime.parse(p.date);
      final matchDate = (start == null || paymentDate.isAfter(start.subtract(const Duration(days: 1)))) &&
          (end == null || paymentDate.isBefore(end.add(const Duration(days: 1))));

      return matchNote && matchDate;
    }).toList();
  }

  /// Export payments to CSV
  Future<String> exportPaymentsToCSV(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    final payments = await getPayments(supplierId, includeDeleted: includeDeleted);

    final buffer = StringBuffer();
    buffer.writeln("Date,Amount,Note,Purchase ID,Method,TransactionRef,Deleted");

    for (final p in payments) {
      buffer.writeln(
        '${p.date},${p.amount},${p.note ?? ""},${p.purchaseId ?? ""},${p.method ?? ""},${p.transactionRef ?? ""},${p.deleted}',
      );
    }

    return buffer.toString();
  }

  // -----------------------------
  // Private helper methods
  // -----------------------------

  /// Recalculate supplier.pending from all purchases
  Future<void> _recalculateSupplierPending(String supplierId) async {
    final allPurchases = await _purchaseRepo.getPurchasesForSupplier(supplierId);
    final totalPending = allPurchases.map((p) => _toDouble(p.pending)).fold(0.0, (a, b) => a + b);

    final supplier = await _supplierDao.getSupplierById(supplierId);
    if (supplier != null) {
      final updated = supplier.copyWith(pendingAmount: totalPending);
      await _supplierDao.updateSupplier(updated);
    }
  }

  /// Safely convert dynamic to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
