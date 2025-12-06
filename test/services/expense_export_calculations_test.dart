import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/models/expense.dart';

void main() {
  group('Expense Export Calculations', () {
    group('Total Amount Calculation', () {
      test('empty list returns 0', () {
        final expenses = <Expense>[];
        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        expect(totalAmount, equals(0.0));
      });

      test('single expense', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Office Supplies',
            amount: 150.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
        ];
        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        expect(totalAmount, equals(150.0));
      });

      test('multiple expenses sum correctly', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Expense 1',
            amount: 100.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
          Expense(
            id: '2',
            description: 'Expense 2',
            amount: 250.50,
            date: DateTime.now().toIso8601String(),
            category: 'Travel',
          ),
          Expense(
            id: '3',
            description: 'Expense 3',
            amount: 49.50,
            date: DateTime.now().toIso8601String(),
            category: 'Utilities',
          ),
        ];
        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        expect(totalAmount, equals(400.0));
      });
    });

    group('Average Expense Calculation', () {
      test('empty list returns 0', () {
        final expenses = <Expense>[];
        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        final avgAmount = expenses.isEmpty
            ? 0.0
            : totalAmount / expenses.length;
        expect(avgAmount, equals(0.0));
      });

      test('single expense returns that value', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Test',
            amount: 150.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
        ];
        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        final avgAmount = totalAmount / expenses.length;
        expect(avgAmount, equals(150.0));
      });

      test('multiple expenses calculate correct average', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Expense 1',
            amount: 100.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
          Expense(
            id: '2',
            description: 'Expense 2',
            amount: 200.0,
            date: DateTime.now().toIso8601String(),
            category: 'Travel',
          ),
          Expense(
            id: '3',
            description: 'Expense 3',
            amount: 300.0,
            date: DateTime.now().toIso8601String(),
            category: 'Utilities',
          ),
        ];
        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );
        final avgAmount = totalAmount / expenses.length;
        expect(avgAmount, equals(200.0));
      });
    });

    group('Category Totals and Percentages', () {
      test('single category', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Expense 1',
            amount: 100.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
          Expense(
            id: '2',
            description: 'Expense 2',
            amount: 200.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
        ];

        final categoryTotals = <String, double>{};
        for (final expense in expenses) {
          final category = expense.category;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0) + expense.amount;
        }

        expect(categoryTotals.length, equals(1));
        expect(categoryTotals['Office'], equals(300.0));
      });

      test('multiple categories', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Expense 1',
            amount: 100.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
          Expense(
            id: '2',
            description: 'Expense 2',
            amount: 200.0,
            date: DateTime.now().toIso8601String(),
            category: 'Travel',
          ),
          Expense(
            id: '3',
            description: 'Expense 3',
            amount: 150.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
        ];

        final categoryTotals = <String, double>{};
        for (final expense in expenses) {
          final category = expense.category;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0) + expense.amount;
        }

        expect(categoryTotals.length, equals(2));
        expect(categoryTotals['Office'], equals(250.0));
        expect(categoryTotals['Travel'], equals(200.0));
      });

      test('percentage calculation accuracy', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Expense 1',
            amount: 100.0,
            date: DateTime.now().toIso8601String(),
            category: 'Office',
          ),
          Expense(
            id: '2',
            description: 'Expense 2',
            amount: 200.0,
            date: DateTime.now().toIso8601String(),
            category: 'Travel',
          ),
          Expense(
            id: '3',
            description: 'Expense 3',
            amount: 200.0,
            date: DateTime.now().toIso8601String(),
            category: 'Utilities',
          ),
        ];

        final categoryTotals = <String, double>{};
        for (final expense in expenses) {
          final category = expense.category;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0) + expense.amount;
        }

        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        // Calculate percentages
        final officePercent = (categoryTotals['Office']! / totalAmount) * 100;
        final travelPercent = (categoryTotals['Travel']! / totalAmount) * 100;
        final utilitiesPercent =
            (categoryTotals['Utilities']! / totalAmount) * 100;

        expect(officePercent, closeTo(20.0, 0.01));
        expect(travelPercent, closeTo(40.0, 0.01));
        expect(utilitiesPercent, closeTo(40.0, 0.01));
      });

      test('percentages sum to 100', () {
        final expenses = [
          Expense(
            id: '1',
            description: 'Expense 1',
            amount: 33.33,
            date: DateTime.now().toIso8601String(),
            category: 'A',
          ),
          Expense(
            id: '2',
            description: 'Expense 2',
            amount: 33.33,
            date: DateTime.now().toIso8601String(),
            category: 'B',
          ),
          Expense(
            id: '3',
            description: 'Expense 3',
            amount: 33.34,
            date: DateTime.now().toIso8601String(),
            category: 'C',
          ),
        ];

        final categoryTotals = <String, double>{};
        for (final expense in expenses) {
          final category = expense.category;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0) + expense.amount;
        }

        final totalAmount = expenses.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        double totalPercentage = 0;
        for (final total in categoryTotals.values) {
          totalPercentage += (total / totalAmount) * 100;
        }

        expect(totalPercentage, closeTo(100.0, 0.01));
      });
    });
  });
}
