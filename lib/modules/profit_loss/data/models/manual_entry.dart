class ManualEntry {
  final String id;
  final String description;
  final double amount;
  final String type; // 'income' or 'expense'
  final DateTime date;
  final String category; // Added for better classification

  ManualEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    this.category = 'General',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory ManualEntry.fromMap(Map<String, dynamic> map) {
    return ManualEntry(
      id: map['id'],
      description: map['description'],
      amount: map['amount'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      category: map['category'] ?? 'General',
    );
  }
}
