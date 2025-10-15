class ExpenseReport {
  final String category;
  final double totalSpent;

  ExpenseReport({
    required this.category,
    required this.totalSpent,
  });

  factory ExpenseReport.fromMap(Map<String, dynamic> map) {
    return ExpenseReport(
      category: map['category'] ?? 'Unknown',
      totalSpent: (map['total_spent'] ?? 0).toDouble(),
    );
  }
}
