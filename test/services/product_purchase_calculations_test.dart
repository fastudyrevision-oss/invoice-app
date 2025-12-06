import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/models/product.dart';
import 'package:invoice_app/models/purchase.dart';

void main() {
  group('Product Export Calculations', () {
    group('Stock Value Calculation', () {
      test('empty list returns 0', () {
        final products = <Product>[];
        final totalStockValue = products.fold<double>(
          0,
          (sum, p) => sum + (p.quantity * p.sellPrice),
        );
        expect(totalStockValue, equals(0.0));
      });

      test('single product', () {
        final products = [
          Product(
            id: '1',
            name: 'Product 1',
            description: 'Test product',
            sku: 'SKU001',
            defaultUnit: 'pcs',
            quantity: 10,
            sellPrice: 50.0,
            costPrice: 30.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalStockValue = products.fold<double>(
          0,
          (sum, p) => sum + (p.quantity * p.sellPrice),
        );
        expect(totalStockValue, equals(500.0));
      });

      test('multiple products sum correctly', () {
        final products = [
          Product(
            id: '1',
            name: 'Product 1',
            description: 'Test product 1',
            sku: 'SKU001',
            defaultUnit: 'pcs',
            quantity: 10,
            sellPrice: 50.0,
            costPrice: 30.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Product(
            id: '2',
            name: 'Product 2',
            description: 'Test product 2',
            sku: 'SKU002',
            defaultUnit: 'pcs',
            quantity: 20,
            sellPrice: 25.0,
            costPrice: 15.0,
            minStock: 10,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalStockValue = products.fold<double>(
          0,
          (sum, p) => sum + (p.quantity * p.sellPrice),
        );
        expect(totalStockValue, equals(1000.0));
      });

      test('zero stock products', () {
        final products = [
          Product(
            id: '1',
            name: 'Product 1',
            description: 'Test product 1',
            sku: 'SKU001',
            defaultUnit: 'pcs',
            quantity: 0,
            sellPrice: 50.0,
            costPrice: 30.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Product(
            id: '2',
            name: 'Product 2',
            description: 'Test product 2',
            sku: 'SKU002',
            defaultUnit: 'pcs',
            quantity: 10,
            sellPrice: 100.0,
            costPrice: 60.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalStockValue = products.fold<double>(
          0,
          (sum, p) => sum + (p.quantity * p.sellPrice),
        );
        expect(totalStockValue, equals(1000.0));
      });
    });

    group('Low Stock Count', () {
      test('no low stock items', () {
        final products = [
          Product(
            id: '1',
            name: 'Product 1',
            description: 'Test product 1',
            sku: 'SKU001',
            defaultUnit: 'pcs',
            quantity: 10,
            sellPrice: 50.0,
            costPrice: 30.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Product(
            id: '2',
            name: 'Product 2',
            description: 'Test product 2',
            sku: 'SKU002',
            defaultUnit: 'pcs',
            quantity: 20,
            sellPrice: 25.0,
            costPrice: 15.0,
            minStock: 10,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final lowStockCount = products
            .where((p) => p.quantity <= p.minStock)
            .length;
        expect(lowStockCount, equals(0));
      });

      test('all items low stock', () {
        final products = [
          Product(
            id: '1',
            name: 'Product 1',
            description: 'Test product 1',
            sku: 'SKU001',
            defaultUnit: 'pcs',
            quantity: 3,
            sellPrice: 50.0,
            costPrice: 30.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Product(
            id: '2',
            name: 'Product 2',
            description: 'Test product 2',
            sku: 'SKU002',
            defaultUnit: 'pcs',
            quantity: 5,
            sellPrice: 25.0,
            costPrice: 15.0,
            minStock: 10,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final lowStockCount = products
            .where((p) => p.quantity <= p.minStock)
            .length;
        expect(lowStockCount, equals(2));
      });

      test('mixed low and normal stock', () {
        final products = [
          Product(
            id: '1',
            name: 'Product 1',
            description: 'Test product 1',
            sku: 'SKU001',
            defaultUnit: 'pcs',
            quantity: 3,
            sellPrice: 50.0,
            costPrice: 30.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Product(
            id: '2',
            name: 'Product 2',
            description: 'Test product 2',
            sku: 'SKU002',
            defaultUnit: 'pcs',
            quantity: 20,
            sellPrice: 25.0,
            costPrice: 15.0,
            minStock: 10,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Product(
            id: '3',
            name: 'Product 3',
            description: 'Test product 3',
            sku: 'SKU003',
            defaultUnit: 'pcs',
            quantity: 5,
            sellPrice: 30.0,
            costPrice: 20.0,
            minStock: 5,
            trackExpiry: false,
            supplierId: 'S1',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final lowStockCount = products
            .where((p) => p.quantity <= p.minStock)
            .length;
        expect(lowStockCount, equals(2));
      });
    });
  });

  group('Purchase Export Calculations', () {
    group('Total Amount Calculation', () {
      test('empty list returns 0', () {
        final purchases = <Purchase>[];
        final totalAmount = purchases.fold<double>(
          0,
          (sum, p) => sum + p.total,
        );
        expect(totalAmount, equals(0.0));
      });

      test('single purchase', () {
        final purchases = [
          Purchase(
            id: '1',
            supplierId: 'S1',
            invoiceNo: 'INV001',
            total: 500.0,
            paid: 300.0,
            pending: 200.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalAmount = purchases.fold<double>(
          0,
          (sum, p) => sum + p.total,
        );
        expect(totalAmount, equals(500.0));
      });

      test('multiple purchases', () {
        final purchases = [
          Purchase(
            id: '1',
            supplierId: 'S1',
            invoiceNo: 'INV001',
            total: 500.0,
            paid: 500.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Purchase(
            id: '2',
            supplierId: 'S2',
            invoiceNo: 'INV002',
            total: 750.0,
            paid: 500.0,
            pending: 250.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalAmount = purchases.fold<double>(
          0,
          (sum, p) => sum + p.total,
        );
        expect(totalAmount, equals(1250.0));
      });
    });

    group('Total Paid and Pending Calculation', () {
      test('all paid purchases', () {
        final purchases = [
          Purchase(
            id: '1',
            supplierId: 'S1',
            invoiceNo: 'INV001',
            total: 500.0,
            paid: 500.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Purchase(
            id: '2',
            supplierId: 'S2',
            invoiceNo: 'INV002',
            total: 300.0,
            paid: 300.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPaid = purchases.fold<double>(0, (sum, p) => sum + p.paid);
        final totalPending = purchases.fold<double>(
          0,
          (sum, p) => sum + p.pending,
        );
        expect(totalPaid, equals(800.0));
        expect(totalPending, equals(0.0));
      });

      test('mixed paid and pending', () {
        final purchases = [
          Purchase(
            id: '1',
            supplierId: 'S1',
            invoiceNo: 'INV001',
            total: 500.0,
            paid: 300.0,
            pending: 200.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Purchase(
            id: '2',
            supplierId: 'S2',
            invoiceNo: 'INV002',
            total: 600.0,
            paid: 600.0,
            pending: 0.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          Purchase(
            id: '3',
            supplierId: 'S3',
            invoiceNo: 'INV003',
            total: 400.0,
            paid: 150.0,
            pending: 250.0,
            date: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ];
        final totalPaid = purchases.fold<double>(0, (sum, p) => sum + p.paid);
        final totalPending = purchases.fold<double>(
          0,
          (sum, p) => sum + p.pending,
        );
        expect(totalPaid, equals(1050.0));
        expect(totalPending, equals(450.0));
      });
    });
  });
}
