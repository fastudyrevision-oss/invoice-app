import '../dao/stock_report_dao.dart';
import '../models/stock_report_model.dart';

class StockRepository {
  final StockDao _dao = StockDao();

  Future<List<StockReport>> fetchStockReport({
    bool includePrice = true,
    bool onlyLowStock = false,
  }) async {
    final list = await _dao.getStockReport();
    return list.where((s) {
      if (onlyLowStock) return s.remainingQty <= 5; // example threshold
      return true;
    }).toList();
  }
}
