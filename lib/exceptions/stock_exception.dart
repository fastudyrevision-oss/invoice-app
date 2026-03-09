class StockConstraintException implements Exception {
  final String message;
  final List<String> relatedInvoices;

  StockConstraintException(this.message, {this.relatedInvoices = const []});

  @override
  String toString() => "StockConstraintException: $message";
}
