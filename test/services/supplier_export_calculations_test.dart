import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/models/supplier.dart';

void main() {
  group('Supplier Export Calculations', () {
    group('Total Pending Calculation', () {
      test('empty list returns 0', () {
        final suppliers = <Supplier>[];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        expect(totalPending, equals(0.0));
      });

      test('single supplier with pending', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Test Supplier',
            companyId: '1',
            pendingAmount: 150.50,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        expect(totalPending, equals(150.50));
      });

      test('multiple suppliers sum correctly', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 100.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 250.75,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '3',
            name: 'Supplier 3',
            companyId: '1',
            pendingAmount: 49.25,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        expect(totalPending, equals(400.0));
      });

      test('handles zero pending amounts', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 0.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 0.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        expect(totalPending, equals(0.0));
      });

      test('handles very large numbers', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 999999.99,
            creditLimit: 2000000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 888888.88,
            creditLimit: 2000000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        expect(totalPending, closeTo(1888888.87, 0.01));
      });

      test('decimal precision maintained', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 10.33,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 20.67,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        expect(totalPending, closeTo(31.0, 0.01));
      });
    });

    group('Average Pending Calculation', () {
      test('empty list returns 0 (avoids division by zero)', () {
        final suppliers = <Supplier>[];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        final avgPending = suppliers.isEmpty
            ? 0.0
            : totalPending / suppliers.length;
        expect(avgPending, equals(0.0));
      });

      test('single supplier returns that value', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Test Supplier',
            companyId: '1',
            pendingAmount: 150.50,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        final avgPending = totalPending / suppliers.length;
        expect(avgPending, equals(150.50));
      });

      test('multiple suppliers calculate correct average', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 100.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 200.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '3',
            name: 'Supplier 3',
            companyId: '1',
            pendingAmount: 300.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        final avgPending = totalPending / suppliers.length;
        expect(avgPending, equals(200.0));
      });

      test('handles decimal precision', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 100.33,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 200.67,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = suppliers.fold<double>(
          0,
          (sum, s) => sum + s.pendingAmount,
        );
        final avgPending = totalPending / suppliers.length;
        expect(avgPending, closeTo(150.50, 0.01));
      });
    });

    group('Suppliers With Pending Count', () {
      test('empty list returns 0', () {
        final suppliers = <Supplier>[];
        final count = suppliers.where((s) => s.pendingAmount > 0).length;
        expect(count, equals(0));
      });

      test('all suppliers with pending', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 100.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 200.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final count = suppliers.where((s) => s.pendingAmount > 0).length;
        expect(count, equals(2));
      });

      test('no suppliers with pending', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 0.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 0.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final count = suppliers.where((s) => s.pendingAmount > 0).length;
        expect(count, equals(0));
      });

      test('mixed pending and paid suppliers', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 100.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 0.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '3',
            name: 'Supplier 3',
            companyId: '1',
            pendingAmount: 250.0,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final count = suppliers.where((s) => s.pendingAmount > 0).length;
        expect(count, equals(2));
      });

      test('exactly 0.00 pending not counted', () {
        final suppliers = [
          Supplier(
            id: '1',
            name: 'Supplier 1',
            companyId: '1',
            pendingAmount: 0.00,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Supplier(
            id: '2',
            name: 'Supplier 2',
            companyId: '1',
            pendingAmount: 0.01,
            creditLimit: 1000.0,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final count = suppliers.where((s) => s.pendingAmount > 0).length;
        expect(count, equals(1));
      });
    });

    group('Filter Summary Generation', () {
      test('no filters returns empty list', () {
        final List<String> activeFilters = [];

        // Simulate no filters
        String? searchKeyword;
        String? companyName;
        bool? pendingFilter;
        double? minCredit;
        double? maxCredit;

        if (searchKeyword != null && searchKeyword.isNotEmpty) {
          activeFilters.add('Search: "$searchKeyword"');
        }
        if (companyName != null && companyName != 'All Companies') {
          activeFilters.add('Company: $companyName');
        }
        if (pendingFilter != null) {
          activeFilters.add(
            'Payment Status: ${pendingFilter ? "Pending Only" : "Paid Only"}',
          );
        }

        expect(activeFilters, isEmpty);
      });

      test('search keyword filter', () {
        final List<String> activeFilters = [];
        final searchKeyword = 'ABC Company';

        if (searchKeyword.isNotEmpty) {
          activeFilters.add('Search: "$searchKeyword"');
        }

        expect(activeFilters, contains('Search: "ABC Company"'));
        expect(activeFilters.length, equals(1));
      });

      test('company filter excludes All Companies', () {
        final List<String> activeFilters = [];

        // Test with "All Companies" - should not be added
        String? companyName = 'All Companies';
        if (companyName != null && companyName != 'All Companies') {
          activeFilters.add('Company: $companyName');
        }
        expect(activeFilters, isEmpty);

        // Test with actual company - should be added
        activeFilters.clear();
        companyName = 'XYZ Suppliers';
        if (companyName != null && companyName != 'All Companies') {
          activeFilters.add('Company: $companyName');
        }
        expect(activeFilters, contains('Company: XYZ Suppliers'));
      });

      test('payment status filters', () {
        // Test pending filter
        List<String> activeFilters = [];
        bool? pendingFilter = true;
        if (pendingFilter != null) {
          activeFilters.add(
            'Payment Status: ${pendingFilter ? "Pending Only" : "Paid Only"}',
          );
        }
        expect(activeFilters, contains('Payment Status: Pending Only'));

        // Test paid filter
        activeFilters.clear();
        pendingFilter = false;
        if (pendingFilter != null) {
          activeFilters.add(
            'Payment Status: ${pendingFilter ? "Pending Only" : "Paid Only"}',
          );
        }
        expect(activeFilters, contains('Payment Status: Paid Only'));
      });

      test('credit limit ranges', () {
        final List<String> activeFilters = [];

        // Both min and max
        double? minCredit = 10000.0;
        double? maxCredit = 50000.0;
        if (minCredit != null || maxCredit != null) {
          final min = minCredit?.toStringAsFixed(0) ?? '0';
          final max = maxCredit?.toStringAsFixed(0) ?? '∞';
          activeFilters.add('Credit Limit: Rs $min - Rs $max');
        }
        expect(activeFilters, contains('Credit Limit: Rs 10000 - Rs 50000'));

        // Only min
        activeFilters.clear();
        minCredit = 5000.0;
        maxCredit = null;
        if (minCredit != null || maxCredit != null) {
          final min = minCredit?.toStringAsFixed(0) ?? '0';
          final max = maxCredit?.toStringAsFixed(0) ?? '∞';
          activeFilters.add('Credit Limit: Rs $min - Rs $max');
        }
        expect(activeFilters, contains('Credit Limit: Rs 5000 - Rs ∞'));
      });

      test('multiple filters combined', () {
        final List<String> activeFilters = [];

        final searchKeyword = 'test';
        final companyName = 'ABC Corp';
        final pendingFilter = true;
        final minCredit = 1000.0;
        final maxCredit = 5000.0;

        if (searchKeyword.isNotEmpty) {
          activeFilters.add('Search: "$searchKeyword"');
        }
        if (companyName != 'All Companies') {
          activeFilters.add('Company: $companyName');
        }
        if (pendingFilter) {
          activeFilters.add('Payment Status: Pending Only');
        }
        if (minCredit != null || maxCredit != null) {
          final min = minCredit?.toStringAsFixed(0) ?? '0';
          final max = maxCredit?.toStringAsFixed(0) ?? '∞';
          activeFilters.add('Credit Limit: Rs $min - Rs $max');
        }

        expect(activeFilters.length, equals(4));
        expect(activeFilters, contains('Search: "test"'));
        expect(activeFilters, contains('Company: ABC Corp'));
        expect(activeFilters, contains('Payment Status: Pending Only'));
        expect(activeFilters, contains('Credit Limit: Rs 1000 - Rs 5000'));
      });
    });
  });
}
