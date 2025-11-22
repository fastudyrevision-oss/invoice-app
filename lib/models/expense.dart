class Expense {
  final String id;
  final String description;
  final double amount;
  final String date;
  final String category;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.category = "General",
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "description": description,
    "amount": amount,
    "date": date,
    "category": category,
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map["id"],
    description: map["description"],
    amount: map["amount"],
    date: map["date"],
    category: map["category"] ?? "General",
  );
}
