class ManualEntry {
  final String id;
  final String description;
  final double amount;
  final String type; // 'income' or 'expense'
  final DateTime date;

  ManualEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
    };
  }

  factory ManualEntry.fromMap(Map<String, dynamic> map) {
    return ManualEntry(
      id: map['id'],
      description: map['description'],
      amount: map['amount'],
      type: map['type'],
      date: DateTime.parse(map['date']),
    );
  }
}
