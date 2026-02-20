import 'package:sqflite/sqflite.dart';
import '../models/stock_disposal.dart';
import '../services/logger_service.dart';

class StockDisposalDao {
  final DatabaseExecutor db;
  StockDisposalDao(this.db);

  String get _detailedQuery => '''
    SELECT sd.*, 
           p.name as product_name, p.sku as product_code,
           pb.batch_no as batch_no,
           s.name as supplier_name
    FROM stock_disposal sd
    LEFT JOIN products p ON sd.product_id = p.id
    LEFT JOIN product_batches pb ON sd.batch_id = pb.id
    LEFT JOIN suppliers s ON COALESCE(sd.supplier_id, pb.supplier_id, p.supplier_id) = s.id
  ''';

  /// Insert a new disposal record
  Future<void> insert(StockDisposal disposal) async {
    await db.insert(
      'stock_disposal',
      disposal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    logger.info('StockDisposalDao', 'Inserted disposal: ${disposal.id}');
  }

  /// Get all disposal records with full details
  Future<List<StockDisposal>> getAll() async {
    final result = await db.rawQuery(
      '$_detailedQuery ORDER BY sd.created_at DESC',
    );
    return result.map((row) => StockDisposal.fromMap(row)).toList();
  }

  /// Get disposals by date range with full details
  Future<List<StockDisposal>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery(
      '$_detailedQuery WHERE sd.created_at >= ? AND sd.created_at <= ? ORDER BY sd.created_at DESC',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return result.map((row) => StockDisposal.fromMap(row)).toList();
  }

  /// Search disposals with full details (optimized for large datasets)
  Future<List<StockDisposal>> search({
    String? query,
    DateTime? start,
    DateTime? end,
    String? disposalType,
  }) async {
    List<String> where = [];
    List<dynamic> args = [];

    if (query != null && query.isNotEmpty) {
      where.add('(p.name LIKE ? OR p.sku LIKE ? OR pb.batch_no LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }

    if (start != null && end != null) {
      where.add('sd.created_at >= ? AND sd.created_at <= ?');
      args.addAll([start.toIso8601String(), end.toIso8601String()]);
    }

    if (disposalType != null) {
      where.add('sd.disposal_type = ?');
      args.add(disposalType);
    }

    String whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final result = await db.rawQuery(
      '$_detailedQuery $whereClause ORDER BY sd.created_at DESC',
      args,
    );

    return result.map((row) => StockDisposal.fromMap(row)).toList();
  }

  /// Get total loss for a date range
  Future<Map<String, double>> getTotalLoss({
    DateTime? start,
    DateTime? end,
  }) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (start != null && end != null) {
      whereClause = 'WHERE created_at >= ? AND created_at <= ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    }

    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN disposal_type = 'write_off' THEN cost_loss ELSE 0 END) as write_offs,
        SUM(CASE WHEN disposal_type = 'return' AND refund_status = 'pending' THEN cost_loss ELSE 0 END) as pending_refunds,
        SUM(CASE WHEN disposal_type = 'return' AND refund_status = 'received' THEN refund_amount ELSE 0 END) as received_refunds,
        SUM(CASE WHEN disposal_type = 'return' AND refund_status = 'rejected' THEN cost_loss ELSE 0 END) as rejected_returns
      FROM stock_disposal
      $whereClause
    ''', whereArgs);

    if (result.isEmpty) {
      return {
        'write_offs': 0.0,
        'pending_refunds': 0.0,
        'received_refunds': 0.0,
        'rejected_returns': 0.0,
        'net_loss': 0.0,
      };
    }

    final row = result.first;
    final writeOffs = ((row['write_offs'] ?? 0) as num).toDouble();
    final pendingRefunds = ((row['pending_refunds'] ?? 0) as num).toDouble();
    final receivedRefunds = ((row['received_refunds'] ?? 0) as num).toDouble();
    final rejectedReturns = ((row['rejected_returns'] ?? 0) as num).toDouble();

    return {
      'write_offs': writeOffs,
      'pending_refunds': pendingRefunds,
      'received_refunds': receivedRefunds,
      'rejected_returns': rejectedReturns,
      'net_loss':
          writeOffs + pendingRefunds + rejectedReturns - receivedRefunds,
    };
  }

  /// Update refund status
  Future<void> updateRefundStatus(
    String id,
    String status,
    double amount,
  ) async {
    await db.update(
      'stock_disposal',
      {'refund_status': status, 'refund_amount': amount},
      where: 'id = ?',
      whereArgs: [id],
    );
    logger.info('StockDisposalDao', 'Updated refund status for $id: $status');
  }

  /// Delete a disposal record
  Future<void> delete(String id) async {
    await db.delete('stock_disposal', where: 'id = ?', whereArgs: [id]);
  }
}
