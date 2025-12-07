import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../db/database_helper.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/bulk_sync_service.dart';
import '../../services/database_seeder_service.dart';
import 'package:csv/csv.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_utils.dart';

//I am using here the syncTimeService to track last sync times for tables and for preparing bulk sysnc data i am using BulkSyncService.
//For now it is  just exposting or  prearing bulk sync for products table. You can extend it later to other tables as needed.
//i will add a dropdown later to select table for bulk sync.
// You can also add more error handling and user feedback as needed.

class BackupRestoreScreen extends StatefulWidget {
  final VoidCallback? onRestoreSuccess;

  const BackupRestoreScreen({super.key, this.onRestoreSuccess});

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

        // ✅ Notify parent to refresh connections
        if (mounted) {
          widget.onRestoreSuccess?.call();
        }
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

  Future<void> _exportTableCsv(String table) async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper.instance.db;
      final rows = await db.query(table);

      if (rows.isEmpty) {
        throw "Table $table is empty";
      }

      // Convert to List<List<dynamic>> for csv package
      List<List<dynamic>> csvData = [];
      // Headers
      csvData.add(rows.first.keys.toList());
      // Rows
      for (var row in rows) {
        csvData.add(row.values.toList());
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      // Save file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $table CSV',
        fileName: '${table}_${DateTime.now().millisecondsSinceEpoch}.csv',
        allowedExtensions: ['csv'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        // saveFile returns path (maybe?), or we use result.
        // FilePicker saveFile returns string nullable path.
        final file = File(outputFile);
        await file.writeAsString(csvString);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to $outputFile')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV Export failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkDeveloperPassword(VoidCallback onAuthorized) async {
    final auth = AuthService.instance;
    // If user is already developer, skip password
    if (auth.isDeveloper) {
      onAuthorized();
      return;
    }

    // Show password dialog
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Restricted Access"),
        content: TextField(
          controller: passCtrl,
          decoration: const InputDecoration(
            labelText: "Enter Developer Password",
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(onPressed: () {}, child: const Text("Unlock")),
        ],
      ),
    );
  }

  Future<void> _seedData() async {
    _checkDeveloperPassword(() async {
      setState(() => _loading = true);
      try {
        final seeder = DatabaseSeederService();
        await seeder.seedAll(
          onProgress: (status) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(status),
                duration: const Duration(milliseconds: 500),
              ),
            );
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Data Seeding Completed! Please restart app or restore to refresh cache.",
            ),
          ),
        );

        // Notify to refresh
        widget.onRestoreSuccess?.call();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Seeding failed: $e')));
      } finally {
        setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(title: const Text('Backup & Restore'), elevation: 0),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Backup Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.blue.withOpacity(0.05),
                            ],
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                            colors: [
                              Colors.white,
                              Colors.green.withOpacity(0.05),
                            ],
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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

                      const SizedBox(height: 16),

                      // Bulk Sync Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.purple.withOpacity(0.05),
                            ],
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
                          child: ExpansionTile(
                            // Collapsible for space
                            leading: Icon(
                              Icons.cloud_sync,
                              color: Colors.purple.shade600,
                            ),
                            title: const Text(
                              "Bulk Sync & CSV Export",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final tables = BulkSyncService()
                                            .getSyncableTables();
                                        for (var t in tables) {
                                          await _prepareBulkSync(t);
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "All tables prepared!",
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.sync),
                                      label: const Text(
                                        'Prepare ALL Tables for Sync',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const Text("Export to CSV"),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (var t in [
                                          'products',
                                          'customers',
                                          'suppliers',
                                          'invoices',
                                          'purchases',
                                        ])
                                          OutlinedButton.icon(
                                            onPressed: () => _exportTableCsv(t),
                                            icon: const Icon(
                                              Icons.table_chart,
                                              size: 16,
                                            ),
                                            label: Text(t.toUpperCase()),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Developer Options Card (Seeding)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.red.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
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
                                      Colors.red.shade600,
                                      Colors.red.shade400,
                                    ],
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.build,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Developer Options",
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
                                      Icons.storage,
                                      size: 64,
                                      color: Colors.red.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "Seed database with dummy data for performance testing",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: _seedData,
                                      icon: const Icon(Icons.add_chart),
                                      label: const Text('Seed Dummy Data'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
      },
    );
  }
}
