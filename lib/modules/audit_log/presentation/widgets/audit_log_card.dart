import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/audit_log_entry.dart';

class AuditLogCard extends StatelessWidget {
  final AuditLogEntry entry;
  final VoidCallback onTap;

  const AuditLogCard({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color actionColor;
    IconData actionIcon;

    switch (entry.action) {
      case 'CREATE':
        actionColor = Colors.green;
        actionIcon = Icons.add_circle_outline;
        break;
      case 'UPDATE':
        actionColor = Colors.orange;
        actionIcon = Icons.edit;
        break;
      case 'DELETE':
        actionColor = Colors.red;
        actionIcon = Icons.delete_outline;
        break;
      default:
        actionColor = Colors.grey;
        actionIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: actionColor.withOpacity(0.1),
          child: Icon(actionIcon, color: actionColor),
        ),
        title: Text(
          "${entry.action} - ${entry.tableName}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Record ID: ${entry.recordId}"),
            Text(
              DateFormat('dd MMM yyyy HH:mm').format(entry.timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
