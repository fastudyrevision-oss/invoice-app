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
    id: map["id"],
    entityId: map["entity_id"],
    entityType: map["entity_type"],
    date: map["date"],
    description: map["description"],
    debit: map["debit"],
    credit: map["credit"],
    balance: map["balance"],
  );
}
