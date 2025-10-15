import '../models/stock_report_model.dart';

class ChartService {
  List<Map<String, dynamic>> getBarChartData(List<StockReport> data) {
    return data.map((e) => {
      'name': e.productName,
      'remaining': e.remainingQty,
    }).toList();
  }
}
