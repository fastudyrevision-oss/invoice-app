import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../db/database_helper.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/bulk_sync_service.dart';

//I am using here the syncTimeService to track last sync times for tables and for preparing bulk sysnc data i am using BulkSyncService.
//For now it is  just exposting or  prearing bulk sync for products table. You can extend it later to other tables as needed.
//i will add a dropdown later to select table for bulk sync.
// You can also add more error handling and user feedback as needed.

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({Key? key}) : super(key: key);

  @override
  _BackupRestoreScreenState createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _loading = false;
  String? _lastBackupPath;

  @override
  void initState() {
    super.initState();
    _checkLastBackup();
  }

  Future<void> _checkLastBackup() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!backupDir.existsSync()) backupDir.createSync();
    final backups = backupDir.listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (backups.isNotEmpty) {
      setState(() {
        _lastBackupPath = backups.first.path;
      });
    }
  }

  Future<void> _backupDatabase() async {
    setState(() => _loading = true);
    try {
      final dbPath = await DatabaseHelper.instance.dbPath;
      if (dbPath == null) {
  // Web: handle differently
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Backup/restore is not supported on Web"))
  );
  return;
}
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dir.path, 'backups'));
      if (!backupDir.existsSync()) backupDir.createSync();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile = File(p.join(backupDir.path, 'backup_$timestamp.db'));
      await File(dbPath).copy(backupFile.path);
      setState(() {
        _lastBackupPath = backupFile.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup completed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restoreDatabase() async {
    setState(() => _loading = true);
    try {
      // Pick the backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        final selectedFile = File(result.files.single.path!);
        final dbPath = await DatabaseHelper.instance.dbPath;

        // Close the database before restoring
        await DatabaseHelper.instance.close();
        if (dbPath == null) {
  // Web: handle differently
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Backup/restore is not supported on Web"))
  );
  return;
}

        // Copy backup to actual db location
        await selectedFile.copy(dbPath);

        // Re-initialize DB
        await DatabaseHelper.instance.init();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database restored successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }
  Future<void> _prepareBulkSync(String table) async {
  setState(() => _loading = true);
  try {
    final bulkSyncService = BulkSyncService();
    final jsonData = await bulkSyncService.prepareJsonForBulkSync(table);

    // Optional: Save JSON to a file
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '$table-bulk.json'));
    await file.writeAsString(jsonData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bulk sync data for "$table" prepared at ${file.path}')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to prepare bulk sync: $e')),
    );
  } finally {
    setState(() => _loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _backupDatabase,
                    icon: const Icon(Icons.backup),
                    label: const Text('Backup Database'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _restoreDatabase,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Database'),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _lastBackupPath != null
                        ? 'Last backup: ${p.basename(_lastBackupPath!)}'
                        : 'No backups yet',
                    style: const TextStyle(fontSize: 14),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _prepareBulkSync('products'), // You can add a dropdown later for tables
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Prepare Bulk Sync for Products'),
                  ),
                  const SizedBox(height: 16),

                ],
              ),
      ),
    );
  }
}
