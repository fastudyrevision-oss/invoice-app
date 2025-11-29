import 'dart:convert';

class AuditLogEntry {
  final String id;
  final String action; // CREATE, UPDATE, DELETE
  final String tableName;
  final String recordId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String userId;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.tableName,
    required this.recordId,
    this.oldData,
    this.newData,
    required this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'old_data': oldData != null ? jsonEncode(oldData) : null,
      'new_data': newData != null ? jsonEncode(newData) : null,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'],
      action: map['action'],
      tableName: map['table_name'],
      recordId: map['record_id'],
      oldData: map['old_data'] != null ? jsonDecode(map['old_data']) : null,
      newData: map['new_data'] != null ? jsonDecode(map['new_data']) : null,
      userId: map['user_id'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
