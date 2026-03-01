import '../dao/supplier_payment_dao.dart';
import '../models/supplier_payment.dart';
import '../dao/supplier_dao.dart';
import '../repositories/purchase_repo.dart';
import '../models/purchase.dart';
import '../services/logger_service.dart';

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

  LoggerService get logger => LoggerService.instance;

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
      final Purchase? purchase = await _purchaseRepo.getPurchaseById(
        purchaseId,
      );
      if (purchase != null) {
        final oldPaid = _toDouble(purchase.paid);
        final oldPending = _toDouble(purchase.pending);

        // ✅ Remove capping logic: Allow pending to become negative (overpaid)
        final newPaid = oldPaid + amount;
        final newPending = oldPending - amount;

        await _purchaseRepo.updatePurchase(
          purchase.copyWith(paid: newPaid, pending: newPending),
        );
      }
    }

    // 3️⃣ Recalculate supplier.pending from all purchases
    await recalculateSupplierBalance(supplierId);
  }

  /// Update an existing payment
  Future<void> updatePayment(SupplierPayment payment) async {
    // Get the old payment to compare amounts
    final oldPayments = await _paymentDao.getPayments(payment.supplierId);
    final oldPayment = oldPayments.firstWhere((p) => p.id == payment.id);

    // If amount or purchaseId changed, we need to update purchase balances
    if (oldPayment.amount != payment.amount ||
        oldPayment.purchaseId != payment.purchaseId) {
      // ✅ CASE 1: Editing payment for THE SAME purchase (only amount changed)
      if (oldPayment.purchaseId != null &&
          oldPayment.purchaseId == payment.purchaseId) {
        // Just apply the DIFFERENCE to avoid double-update
        final amountDifference = payment.amount - oldPayment.amount;

        final purchase = await _purchaseRepo.getPurchaseById(
          payment.purchaseId!,
        );
        if (purchase != null) {
          final newPaid = _toDouble(purchase.paid) + amountDifference;
          final newPending = _toDouble(purchase.pending) - amountDifference;

          await _purchaseRepo.updatePurchase(
            purchase.copyWith(
              paid: newPaid.clamp(0.0, double.infinity),
              pending: newPending,
            ),
          );
        }
      }
      // ✅ CASE 2: Moving payment to a DIFFERENT purchase
      else {
        // 1️⃣ Revert the old payment from old purchase
        if (oldPayment.purchaseId != null) {
          final oldPurchase = await _purchaseRepo.getPurchaseById(
            oldPayment.purchaseId!,
          );
          if (oldPurchase != null) {
            final newPaid = _toDouble(oldPurchase.paid) - oldPayment.amount;
            final newPending =
                _toDouble(oldPurchase.pending) + oldPayment.amount;
            await _purchaseRepo.updatePurchase(
              oldPurchase.copyWith(
                paid: newPaid.clamp(0.0, double.infinity),
                pending: newPending,
              ),
            );
          }
        }

        // 2️⃣ Apply the new payment to new purchase
        if (payment.purchaseId != null) {
          final newPurchase = await _purchaseRepo.getPurchaseById(
            payment.purchaseId!,
          );
          if (newPurchase != null) {
            final oldPaid = _toDouble(newPurchase.paid);
            final oldPending = _toDouble(newPurchase.pending);

            final newPaid = oldPaid + payment.amount;
            final newPending = oldPending - payment.amount;

            await _purchaseRepo.updatePurchase(
              newPurchase.copyWith(paid: newPaid, pending: newPending),
            );
          }
        }
      }

      // 3️⃣ Recalculate supplier pending
      await recalculateSupplierBalance(payment.supplierId);
    }

    // 4️⃣ Update the payment record
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
      final Purchase? purchase = await _purchaseRepo.getPurchaseById(
        payment.purchaseId!,
      );
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
    await recalculateSupplierBalance(payment.supplierId);
  }

  /// Restore a soft-deleted payment (mark deleted = 0)
  Future<void> restorePayment(SupplierPayment payment) async {
    await _paymentDao.restorePayment(payment.id);

    // 1️⃣ Apply payment to purchase if purchaseId exists
    if (payment.purchaseId != null) {
      final Purchase? purchase = await _purchaseRepo.getPurchaseById(
        payment.purchaseId!,
      );
      if (purchase != null) {
        final oldPaid = _toDouble(purchase.paid);
        final oldPending = _toDouble(purchase.pending);

        // ✅ Remove capping logic
        final newPaid = oldPaid + payment.amount;
        final newPending = oldPending - payment.amount;

        await _purchaseRepo.updatePurchase(
          purchase.copyWith(paid: newPaid, pending: newPending),
        );
      }
    }

    // 2️⃣ Recalculate supplier.pending from all purchases
    await recalculateSupplierBalance(payment.supplierId);
  }

  /// Search / filter payments
  Future<List<SupplierPayment>> searchPayments(
    String supplierId, {
    String? keyword,
    DateTime? start,
    DateTime? end,
    bool includeDeleted = false,
  }) async {
    final all = await _paymentDao.getPayments(
      supplierId,
      includeDeleted: includeDeleted,
    );

    return all.where((p) {
      final noteText = p.note ?? "";
      final refText = p.transactionRef ?? "";
      final displayIdText = p.displayId?.toString() ?? "";

      bool matchKeyword = true;
      if (keyword != null && keyword.isNotEmpty) {
        final cleanK = keyword.trim().toLowerCase();
        if (cleanK.startsWith('#')) {
          matchKeyword = displayIdText == cleanK.substring(1);
        } else {
          matchKeyword =
              noteText.toLowerCase().contains(cleanK) ||
              refText.toLowerCase().contains(cleanK) ||
              displayIdText == cleanK;
        }
      }

      final paymentDate = DateTime.parse(p.date);
      final matchDate =
          (start == null ||
              paymentDate.isAfter(start.subtract(const Duration(days: 1)))) &&
          (end == null ||
              paymentDate.isBefore(end.add(const Duration(days: 1))));

      return matchKeyword && matchDate;
    }).toList();
  }

  /// Export payments to CSV
  Future<String> exportPaymentsToCSV(
    String supplierId, {
    bool includeDeleted = false,
  }) async {
    final payments = await getPayments(
      supplierId,
      includeDeleted: includeDeleted,
    );

    final buffer = StringBuffer();
    buffer.writeln(
      "Date,Amount,Note,Purchase ID,Method,TransactionRef,Deleted",
    );

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

  /// Recalculate supplier.pending from all purchases and general payments
  /// ✅ Made public so UI can trigger recalculation when needed
  Future<void> recalculateSupplierBalance(String supplierId) async {
    // 1. Get total remaining debt from all purchases (Already accounts for UPFRONT payments)
    final allPurchases = await _purchaseRepo.getPurchasesForSupplier(
      supplierId,
    );
    final totalPurchasesPending = allPurchases
        .map((p) => _toDouble(p.pending))
        .fold(0.0, (a, b) => a + b);

    // 2. Get total of GENERAL payments (Payments NOT linked to a specific purchase)
    // Linked payments are already subtracted from Purchase.pending, so we don't count them again.
    final allPayments = await _paymentDao.getPayments(supplierId);
    final totalGeneralPayments = allPayments
        .where(
          (p) =>
              p.deleted == 0 && (p.purchaseId == null || p.purchaseId!.isEmpty),
        )
        .map((p) => p.amount)
        .fold(0.0, (a, b) => a + b);

    // 3. Final Supplier Balance = Sum(Purchase Pendings) - Sum(General Payments)
    final pendingAmount = totalPurchasesPending - totalGeneralPayments;

    // 🛑 DEBUG LOGGING
    logger.info(
      "SupplierPaymentRepo",
      "Recalculating Balance for $supplierId",
      context: {
        "purchases_checked": allPurchases.length,
        "sum_purchase_pending": totalPurchasesPending,
        "general_payments_sum": totalGeneralPayments,
        "final_balance": pendingAmount,
      },
    );

    final supplier = await _supplierDao.getSupplierById(supplierId);
    if (supplier != null) {
      final updated = supplier.copyWith(pendingAmount: pendingAmount);
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
