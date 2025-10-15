class AuditLog {
  final String id;
  final String action;      // e.g. INSERT, UPDATE, DELETE
  final String tableName;   // e.g. products, invoices
  final String recordId;    // id of affected record
  final String timestamp;
  final String userId;      // which user did this

  AuditLog({
    required this.id,
    required this.action,
    required this.tableName,
    required this.recordId,
    required this.timestamp,
    required this.userId,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "action": action,
        "table_name": tableName,
        "record_id": recordId,
        "timestamp": timestamp,
        "user_id": userId,
      };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
        id: map["id"],
        action: map["action"],
        tableName: map["table_name"],
        recordId: map["record_id"],
        timestamp: map["timestamp"],
        userId: map["user_id"],
      );
}
