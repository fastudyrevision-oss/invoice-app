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
  const BackupRestoreScreen({super.key});

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
    final backups = backupDir.listSync().whereType<File>().toList()
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
          const SnackBar(
            content: Text("Backup/restore is not supported on Web"),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
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
            const SnackBar(
              content: Text("Backup/restore is not supported on Web"),
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
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
        SnackBar(
          content: Text('Bulk sync data for "$table" prepared at ${file.path}'),
        ),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Backup & Restore'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Backup Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.blue.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          // Header Strip
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.blue.shade400,
                                ],
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.backup,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Database Backup",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 64,
                                  color: Colors.blue.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Create a backup of your database",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _backupDatabase,
                                  icon: const Icon(Icons.backup),
                                  label: const Text('Create Backup'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Restore Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.green.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          // Header Strip
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade600,
                                  Colors.green.shade400,
                                ],
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.restore,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Database Restore",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.cloud_download,
                                  size: 64,
                                  color: Colors.green.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Restore database from a backup file",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _restoreDatabase,
                                  icon: const Icon(Icons.restore),
                                  label: const Text('Restore Database'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bulk Sync Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.purple.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          // Header Strip
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade600,
                                  Colors.purple.shade400,
                                ],
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Bulk Sync",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.sync,
                                  size: 64,
                                  color: Colors.purple.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Prepare bulk sync data for products",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _prepareBulkSync('products'),
                                  icon: const Icon(Icons.cloud_upload),
                                  label: const Text('Prepare Bulk Sync'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Last Backup Info
                  if (_lastBackupPath != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Last Backup",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.basename(_lastBackupPath!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "No backups yet",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
