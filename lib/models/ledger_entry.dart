class LedgerEntry {
  final String id;
  final String entityId; // customer_id or supplier_id
  final String entityType; // "customer" or "supplier"
  final String date;
  final String description;
  final double debit; // money out (expense, purchase)
  final double credit; // money in (sale, payment)
  final double balance;

  LedgerEntry({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.date,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    this.balance = 0.0,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "entity_id": entityId,
    "entity_type": entityType,
    "date": date,
    "description": description,
    "debit": debit,
    "credit": credit,
    "balance": balance,
  };

  factory LedgerEntry.fromMap(Map<String, dynamic> map) => LedgerEntry(
    id: map["id"]?.toString() ?? "",
    entityId: map["entity_id"]?.toString() ?? "",
    entityType: map["entity_type"]?.toString() ?? "unknown",
    date: map["date"]?.toString() ?? DateTime.now().toIso8601String(),
    description: map["description"]?.toString() ?? "",
    debit: (map["debit"] ?? 0.0).toDouble(),
    credit: (map["credit"] ?? 0.0).toDouble(),
    balance: (map["balance"] ?? 0.0).toDouble(),
  );
}
