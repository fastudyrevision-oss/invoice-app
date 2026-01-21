import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/models/invoice.dart';

void main() {
  group('Orders Export Calculations', () {
    group('Total Revenue Calculation', () {
      test('empty orders list returns 0', () {
        final orders = <Invoice>[];
        final totalRevenue = orders.fold<double>(
          0,
          (sum, order) => sum + order.total,
        );
        expect(totalRevenue, equals(0.0));
      });

      test('single order', () {
        final orders = [
          Invoice(
            id: '1',
            customerId: 'C1',
            customerName: 'Test Customer',
            total: 500.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalRevenue = orders.fold<double>(
          0,
          (sum, order) => sum + order.total,
        );
        expect(totalRevenue, equals(500.0));
      });

      test('multiple orders', () {
        final orders = [
          Invoice(
            id: '1',
            customerId: 'C1',
            customerName: 'Customer 1',
            total: 100.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '2',
            customerId: 'C2',
            customerName: 'Customer 2',
            total: 250.50,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '3',
            customerId: 'C3',
            customerName: 'Customer 3',
            total: 149.50,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalRevenue = orders.fold<double>(
          0,
          (sum, order) => sum + order.total,
        );
        expect(totalRevenue, equals(500.0));
      });

      test('decimal precision', () {
        final orders = [
          Invoice(
            id: '1',
            customerId: 'C1',
            customerName: 'Customer 1',
            total: 99.99,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '2',
            customerId: 'C2',
            customerName: 'Customer 2',
            total: 150.01,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalRevenue = orders.fold<double>(
          0,
          (sum, order) => sum + order.total,
        );
        expect(totalRevenue, closeTo(250.0, 0.01));
      });
    });

    group('Total Pending Calculation', () {
      test('all paid orders returns 0', () {
        final orders = [
          Invoice(
            id: '1',
            customerId: 'C1',
            customerName: 'Customer 1',
            total: 100.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '2',
            customerId: 'C2',
            customerName: 'Customer 2',
            total: 200.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = orders.fold<double>(
          0,
          (sum, order) => sum + order.pending,
        );
        expect(totalPending, equals(0.0));
      });

      test('all pending orders', () {
        final orders = [
          Invoice(
            id: '1',
            customerId: 'C1',
            customerName: 'Customer 1',
            total: 100.0,
            pending: 100.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '2',
            customerId: 'C2',
            customerName: 'Customer 2',
            total: 200.0,
            pending: 200.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = orders.fold<double>(
          0,
          (sum, order) => sum + order.pending,
        );
        expect(totalPending, equals(300.0));
      });

      test('mixed paid and pending', () {
        final orders = [
          Invoice(
            id: '1',
            customerId: 'C1',
            customerName: 'Customer 1',
            total: 100.0,
            pending: 50.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '2',
            customerId: 'C2',
            customerName: 'Customer 2',
            total: 200.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Invoice(
            id: '3',
            customerId: 'C3',
            customerName: 'Customer 3',
            total: 300.0,
            pending: 150.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPending = orders.fold<double>(
          0,
          (sum, order) => sum + order.pending,
        );
        expect(totalPending, equals(200.0));
      });
    });

    group('Filter Summary Generation', () {
      test('search query filter', () {
        final List<String> activeFilters = [];
        final searchQuery = 'John Doe';

        if (searchQuery.isNotEmpty) {
          activeFilters.add('Search: "$searchQuery"');
        }

        expect(activeFilters, contains('Search: "John Doe"'));
        expect(activeFilters.length, equals(1));
      });

      test('pending only filter', () {
        final List<String> activeFilters = [];
        final showPendingOnly = true;

        if (showPendingOnly) {
          activeFilters.add('Status: Pending Payments Only');
        }

        expect(activeFilters, contains('Status: Pending Payments Only'));
      });

      test('date range filter formatting', () {
        final List<String> activeFilters = [];
        final dateRange = DateTimeRange(
          start: DateTime(2025, 12, 1),
          end: DateTime(2025, 12, 6),
        );

        final startStr =
            '${dateRange.start.day.toString().padLeft(2, '0')} '
            '${_getMonthName(dateRange.start.month)} ${dateRange.start.year}';
        final endStr =
            '${dateRange.end.day.toString().padLeft(2, '0')} '
            '${_getMonthName(dateRange.end.month)} ${dateRange.end.year}';
        activeFilters.add('Date Range: $startStr - $endStr');

        expect(
          activeFilters,
          contains('Date Range: 01 Dec 2025 - 06 Dec 2025'),
        );
      });

      test('quick filter labels', () {
        // Test "today"
        List<String> activeFilters = [];
        String? quickFilter = 'today';
        final label = quickFilter == 'today'
            ? 'Today'
            : quickFilter == 'week'
            ? 'This Week'
            : 'This Month';
        activeFilters.add('Quick Filter: $label');
        expect(activeFilters, contains('Quick Filter: Today'));

        // Test "week"
        activeFilters.clear();
        quickFilter = 'week';
        final weekLabel = quickFilter == 'today'
            ? 'Today'
            : quickFilter == 'week'
            ? 'This Week'
            : 'This Month';
        activeFilters.add('Quick Filter: $weekLabel');
        expect(activeFilters, contains('Quick Filter: This Week'));

        // Test "month"
        activeFilters.clear();
        quickFilter = 'month';
        final monthLabel = quickFilter == 'today'
            ? 'Today'
            : quickFilter == 'week'
            ? 'This Week'
            : 'This Month';
        activeFilters.add('Quick Filter: $monthLabel');
        expect(activeFilters, contains('Quick Filter: This Month'));
      });

      test('multiple filters combined', () {
        final List<String> activeFilters = [];

        final searchQuery = 'test';
        final showPendingOnly = true;
        final quickFilter = 'week';

        if (searchQuery.isNotEmpty) {
          activeFilters.add('Search: "$searchQuery"');
        }
        if (showPendingOnly) {
          activeFilters.add('Status: Pending Payments Only');
        }
        final label = quickFilter == 'today'
            ? 'Today'
            : quickFilter == 'week'
            ? 'This Week'
            : 'This Month';
        activeFilters.add('Quick Filter: $label');

        expect(activeFilters.length, equals(3));
        expect(activeFilters, contains('Search: "test"'));
        expect(activeFilters, contains('Status: Pending Payments Only'));
        expect(activeFilters, contains('Quick Filter: This Week'));
      });
    });
  });
}

// Helper function for month names
String _getMonthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
