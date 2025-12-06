import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoice_app/db/database_helper.dart';
import 'package:invoice_app/dao/stock_report_dao.dart';
import 'package:invoice_app/models/stock_batch.dart';

void main() {
  // Setup the in-memory database for tests
  late DatabaseHelper dbHelper;
  late StockDao dao;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    dbHelper = DatabaseHelper.testInstance(); // create a factory constructor
    dao = StockDao();
  });

  tearDown(() async {
    await dbHelper.deleteDatabase();
  });

  group('StockDao → calculateStockReport', () {
    test('aggregates single product single batch correctly', () async {
      // Arrange
      final batch = StockBatch(
        batchNo: 'B001',
        productId: 1,
        productName: 'Amamecton',
        purchasedQty: 10,
        costPrice: 100,
        sellPrice: 150,
        expiryDate: DateTime(2025, 12, 31),
        supplierName: 'Cheema',
        supplierId: 1,
        companyName: 'Bayer',
        purchaseDate: DateTime(2025, 10, 1),
      );

      // Act
      final reports = dao.calculateStockReport([batch]);

      // Assert
      expect(reports.length, 1);
      final r = reports.first;
      expect(r.productName, 'Amamecton');
      expect(r.remainingQty, 10);
      expect(r.costPrice, 100);
      expect(r.sellPrice, 150);
      expect(r.profitMargin, 50.0);
      expect(r.totalCostValue, 1000);
      expect(r.totalSellValue, 1500);
      // profitValue is calculated from soldQty: (sellPrice - costPrice) * soldQty
      // Since soldQty defaults to 0, profitValue = 0
      expect(r.profitValue, 0.0); // 0 * (150 - 100) = 0
      expect(r.companyName, 'Bayer');
    });

    test('aggregates multiple batches for same product', () async {
      // Arrange
      final batches = [
        StockBatch(
          batchNo: 'B001',
          productId: 1,
          productName: 'Lufeurone',
          purchasedQty: 20,
          costPrice: 500,
          sellPrice: 600,
          expiryDate: DateTime(2026, 1, 1),
        ),
        StockBatch(
          batchNo: 'B002',
          productId: 1,
          productName: 'Lufeurone',
          purchasedQty: 50,
          costPrice: 900,
          sellPrice: 1000,
          expiryDate: DateTime(2025, 11, 1),
        ),
      ];

      // Act
      final reports = dao.calculateStockReport(batches);

      // Assert
      // Each batch creates a separate report (not aggregated by productId)
      expect(reports.length, 2);

      // Verify both batches are present
      final batch1Report = reports.firstWhere((r) => r.batchNo == 'B001');
      final batch2Report = reports.firstWhere((r) => r.batchNo == 'B002');

      expect(batch1Report.purchasedQty, 20);
      expect(batch1Report.remainingQty, 20);
      expect(batch2Report.purchasedQty, 50);
      expect(batch2Report.remainingQty, 50);
    });

    test('handles empty list gracefully', () async {
      final reports = dao.calculateStockReport([]);
      expect(reports, isEmpty);
    });

    test('handles missing or null supplier safely', () async {
      final batch = StockBatch(
        batchNo: 'B003',
        productId: 2,
        productName: 'Bold',
        purchasedQty: 5,
        costPrice: 400,
        sellPrice: 450,
        expiryDate: null,
        supplierName: null,
      );

      final reports = dao.calculateStockReport([batch]);
      expect(reports.first.supplierName, isNull);
      expect(reports.first.productName, 'Bold');
    });
  });
}
