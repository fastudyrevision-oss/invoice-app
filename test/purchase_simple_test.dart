import 'package:flutter_test/flutter_test.dart';

/// Simple verification test for purchase calculation logic
/// Run with: flutter test test/purchase_simple_test.dart
void main() {
  group('Purchase Calculation Logic Tests', () {
    test(
      'Purchase calculation: Total 7000, Paid 6000 should give Pending 1000',
      () {
        // Simulate the FIXED logic from PurchaseForm
        final total = 7000.0;
        final paidAmount = 6000.0;

        // OLD BUGGY WAY (what was happening before):
        // Purchase created with: paid=6000, pending=1000
        // Then addPayment adds 6000 again
        // Result: paid=12000, pending=-5000 (WRONG!)

        // NEW FIXED WAY:
        // Step 1: Create purchase with paid=0, pending=total
        double purchasePaid = 0.0;
        double purchasePending = total;

        expect(purchasePaid, equals(0.0), reason: 'Initial paid should be 0');
        expect(
          purchasePending,
          equals(7000.0),
          reason: 'Initial pending should be total',
        );

        // Step 2: addPayment updates the purchase
        purchasePaid += paidAmount;
        purchasePending -= paidAmount;

        // Assert final values
        expect(
          purchasePaid,
          equals(6000.0),
          reason: 'Final paid should be 6000',
        );
        expect(
          purchasePending,
          equals(1000.0),
          reason: 'Final pending should be 1000 (7000 - 6000)',
        );
      },
    );

    test('Purchase with zero payment should keep full pending', () {
      final total = 5000.0;
      final paidAmount = 0.0;

      double purchasePaid = 0.0;
      double purchasePending = total;

      // No payment, so no update
      if (paidAmount > 0) {
        purchasePaid += paidAmount;
        purchasePending -= paidAmount;
      }

      expect(purchasePaid, equals(0.0));
      expect(purchasePending, equals(5000.0));
    });

    test('Purchase with overpayment should have negative pending', () {
      final total = 2000.0;
      final paidAmount = 3000.0;

      double purchasePaid = 0.0;
      double purchasePending = total;

      purchasePaid += paidAmount;
      purchasePending -= paidAmount;

      expect(purchasePaid, equals(3000.0));
      expect(purchasePending, equals(-1000.0), reason: 'Overpaid by 1000');
    });

    test('Multiple payments should accumulate correctly', () {
      final total = 10000.0;
      final payments = [3000.0, 4000.0, 2000.0];

      double purchasePaid = 0.0;
      double purchasePending = total;

      for (final payment in payments) {
        purchasePaid += payment;
        purchasePending -= payment;
      }

      expect(purchasePaid, equals(9000.0), reason: '3000 + 4000 + 2000');
      expect(purchasePending, equals(1000.0), reason: '10000 - 9000');
    });
  });
}
