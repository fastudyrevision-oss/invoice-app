import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../db/database_helper.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/bulk_sync_service.dart';
import '../../services/database_seeder_service.dart';
import 'package:csv/csv.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/platform_file_helper.dart';
import '../../services/logger_service.dart';
import '../../services/backup_service.dart';

//I am using here the syncTimeService to track last sync times for tables and for preparing bulk sysnc data i am using BulkSyncService.
//For now it is  just exposting or  prearing bulk sync for products table. You can extend it later to other tables as needed.
//i will add a dropdown later to select table for bulk sync.
// You can also add more error handling and user feedback as needed.

class BackupRestoreScreen extends StatefulWidget {
  final VoidCallback? onRestoreSuccess;

  const BackupRestoreScreen({super.key, this.onRestoreSuccess});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _loading = false;
  String? _lastBackupPath;
  DateTime? _lastBackupTime;
  int? _lastBackupSize;

  // Online Backup Logs
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.add("${DateFormat('HH:mm:ss').format(DateTime.now())}: $message");
    });
    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
        final file = backups.first;
        _lastBackupPath = file.path;
        _lastBackupTime = file.lastModifiedSync();
        _lastBackupSize = file.lengthSync();
      });
    }
  }

  Future<void> _backupDatabase() async {
    // Ask user for backup location
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Backup Location'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'default'),
            child: const ListTile(
              leading: Icon(Icons.storage, color: Colors.blue),
              title: Text('Default Folder'),
              subtitle: Text('Internal app storage'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'custom'),
            child: const ListTile(
              leading: Icon(Icons.folder_open, color: Colors.orange),
              title: Text('Custom Folder'),
              subtitle: Text('Select a specific folder'),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setState(() => _loading = true);
    try {
      final dbPath = await DatabaseHelper.instance.dbPath;
      if (dbPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Backup/restore is not supported on Web"),
            ),
          );
        }
        return;
      }

      String? targetPath;

      if (choice == 'custom') {
        targetPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Backup Folder',
        );
        if (targetPath == null) {
          setState(() => _loading = false);
          return;
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final backupDir = Directory(p.join(dir.path, 'backups'));
        if (!backupDir.existsSync()) backupDir.createSync();
        targetPath = backupDir.path;
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final backupFile = File(p.join(targetPath, 'backup_$timestamp.db'));

      await File(dbPath).copy(backupFile.path);

      setState(() {
        _lastBackupPath = backupFile.path;
        _lastBackupTime = backupFile.lastModifiedSync();
        _lastBackupSize = backupFile.lengthSync();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to: ${backupFile.path}')),
        );
      }
    } catch (e) {
      logger.error('BackupScreen', 'Backup failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
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
        await _performDbRestore(selectedFile);
      }
    } catch (e) {
      logger.error('BackupScreen', 'Restore failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _performDbRestore(File sourceFile) async {
    final dbPath = await DatabaseHelper.instance.dbPath;

    // Close the database before restoring
    await DatabaseHelper.instance.close();

    if (dbPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Backup/restore is not supported on Web"),
          ),
        );
      }
      return;
    }

    // Copy backup to actual db location
    await sourceFile.copy(dbPath);

    // Re-initialize DB
    await DatabaseHelper.instance.init();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database restored successfully')),
      );
    }

    // ✅ Notify parent to refresh connections
    if (mounted) {
      widget.onRestoreSuccess?.call();
    }
  }

  Future<void> _uploadBackupOnline() async {
    _logs.clear();
    _addLog("Starting online backup process...");

    // Check developer/admin permission if needed, or just proceed
    // Assuming current user context is sufficient
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _addLog("Error: No user logged in.");
      return;
    }

    setState(() => _loading = true);
    try {
      final dbPath = await DatabaseHelper.instance.dbPath;
      if (dbPath == null) {
        _addLog("Error: Web not supported.");
        return;
      }

      final dbFile = File(dbPath);
      if (!dbFile.existsSync()) {
        _addLog("Error: Database file not found.");
        return;
      }

      _addLog("Requesting upload URL from server...");
      final backupService = BackupService();

      // Filename: backup_USERID_TIMESTAMP.db
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'backup_${user.id}_$timestamp.db';

      final presignedUrl = await backupService.getPresignedUrl(
        user.id.toString(),
        fileName,
      );

      if (presignedUrl == null) {
        _addLog("Error: Could not get upload URL.");
        return;
      }

      _addLog("Uploading database file...");
      await backupService.uploadDbBackup(dbFile, presignedUrl);

      _addLog("✅ Backup uploaded successfully!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Online Backup Successful!')),
        );
      }
    } catch (e) {
      _addLog("❌ Error: $e");
      logger.error('BackupScreen', 'Online backup failed', error: e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restoreBackupOnline() async {
    // Re-confirm locally before starting since it's destructive
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Online?'),
        content: const Text(
          '⚠️ Warning: This will overwrite your current database with the latest online backup. All unsaved changes will be lost.\n\nAre you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Restore Online'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _logs.clear();
    _addLog("Starting online restore process...");

    final user = AuthService.instance.currentUser;
    if (user == null) {
      _addLog("Error: No user logged in.");
      return;
    }

    setState(() => _loading = true);
    try {
      _addLog("Requesting restore URL from server...");
      final backupService = BackupService();
      final restoreInfo = await backupService.getRestoreUrl(user.id.toString());

      if (restoreInfo == null) {
        _addLog("Error: No online backup found.");
        return;
      }

      final downloadUrl = restoreInfo['url']!;
      final fileName =
          restoreInfo['file_name']!; // Used for temp file naming if desired

      _addLog("Downloading backup file...");

      // Download to temp file
      final request = await HttpClient().getUrl(Uri.parse(downloadUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, 'online_restore_temp.db'));
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        final bytes = await response.fold<List<int>>(
          [],
          (p, e) => p..addAll(e),
        );
        await tempFile.writeAsBytes(bytes);

        _addLog("File downloaded successfully.");

        if (!mounted) return;

        final choice = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Downloaded'),
            content: Text(
              'The backup "$fileName" has been fetched. What would you like to do?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('Save to Device'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'restore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restore Locally'),
              ),
            ],
          ),
        );

        if (choice == 'save') {
          _addLog("Saving file to device...");
          final savedFile = await PlatformFileHelper.saveFile(
            bytes: Uint8List.fromList(bytes),
            suggestedName: fileName,
            extension: 'db',
            dialogTitle: 'Save Database Backup',
          );
          if (savedFile != null) {
            _addLog("✅ File saved to: ${savedFile.path}");
          } else {
            _addLog("ℹ️ Save cancelled by user.");
          }
        } else if (choice == 'restore') {
          _addLog("Restoring database...");
          await _performDbRestore(tempFile);
          _addLog("✅ Restore completed successfully!");
        } else {
          _addLog("ℹ️ Operation cancelled.");
        }

        // Cleanup temp
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        _addLog("Error: Download failed with status ${response.statusCode}");
      }
    } catch (e) {
      _addLog("❌ Error: $e");
      logger.error('BackupScreen', 'Online restore failed', error: e);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bulk sync data for "$table" prepared at ${file.path}',
            ),
          ),
        );
      }
    } catch (e) {
      logger.error('BackupScreen', 'Failed to prepare bulk sync', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare bulk sync: $e')),
        );
      }
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

      // Use platform-aware file handling (Android: share, Desktop: file picker)
      final file = await PlatformFileHelper.saveCsvFile(
        csvContent: csvString,
        suggestedName: '${table}_${DateTime.now().millisecondsSinceEpoch}.csv',
        dialogTitle: 'Save $table CSV',
      );

      if (file != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported $table successfully')));
      }
    } catch (e) {
      if (!mounted) return;
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
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(status),
                  duration: const Duration(milliseconds: 500),
                ),
              );
            }
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Data Seeding Completed! Please restart app or restore to refresh cache.",
              ),
            ),
          );
        }

        // Notify to refresh
        widget.onRestoreSuccess?.call();
      } catch (e) {
        logger.error('BackupScreen', 'Seeding failed', error: e);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Seeding failed: $e')));
        }
      } finally {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text(
          '⚠️ Warning: This will overwrite your current database. All unsaved changes will be lost.\n\nAre you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _restoreDatabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text(
              'Backup & Restore',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Last Backup Info
                      if (_lastBackupPath != null) ...[
                        _buildLastBackupCard(),
                        const SizedBox(height: 24),
                      ],

                      // Grid for Actions
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Use grid layout on tablet/desktop, column on mobile
                          if (constraints.maxWidth > 600) {
                            return GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.5,
                              children: [
                                _ActionCard(
                                  title: "Database Backup",
                                  description:
                                      "Create a full backup of your invoices, products, and customers.",
                                  icon: Icons.cloud_upload_outlined,
                                  color: Colors.blue,
                                  buttonText: "Create Backup",
                                  onPressed: _backupDatabase,
                                ),
                                _ActionCard(
                                  title: "Database Restore",
                                  description:
                                      "Restore your data from a previous backup file.",
                                  icon: Icons.settings_backup_restore_outlined,
                                  color: Colors.orange,
                                  buttonText: "Restore Database",
                                  onPressed: _confirmRestore,
                                  isDangerous: true,
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _ActionCard(
                                title: "Database Backup",
                                description:
                                    "Create a full backup of your invoices, products, and customers.",
                                icon: Icons.cloud_upload_outlined,
                                color: Colors.blue,
                                buttonText: "Create Backup",
                                onPressed: _backupDatabase,
                              ),
                              const SizedBox(height: 16),
                              _ActionCard(
                                title: "Database Restore",
                                description:
                                    "Restore your data from a previous backup file.",
                                icon: Icons.settings_backup_restore_outlined,
                                color: Colors.orange,
                                buttonText: "Restore Database",
                                onPressed: _confirmRestore,
                                isDangerous: true,
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Bulk Sync Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.sync,
                              color: Colors.purple.shade600,
                            ),
                          ),
                          title: const Text(
                            "Bulk Sync & Export",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            "Prepare data for sync or export as CSV",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final tables = BulkSyncService()
                                          .getSyncableTables();
                                      for (var t in tables) {
                                        await _prepareBulkSync(t);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "All tables prepared!",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.sync),
                                    label: const Text('Prepare All Tables'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Export to CSV",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (var t
                                          in BulkSyncService()
                                              .getSyncableTables())
                                        ActionChip(
                                          avatar: Icon(
                                            Icons.table_chart_outlined,
                                            size: 14,
                                            color: Colors.grey[700],
                                          ),
                                          label: Text(
                                            t.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          onPressed: () => _exportTableCsv(t),
                                          backgroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      // Online Backup Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.cloud_upload,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Online Cloud Backup",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _loading
                                          ? null
                                          : _uploadBackupOnline,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text("Upload Backup"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _loading
                                          ? null
                                          : _restoreBackupOnline,
                                      icon: const Icon(
                                        Icons.download_for_offline,
                                      ),
                                      label: const Text("Restore Online"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_logs.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  height: 150,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.builder(
                                    controller: _logScrollController,
                                    itemCount: _logs.length,
                                    itemBuilder: (context, index) => Text(
                                      _logs[index],
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontFamily: 'Monospace',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      _DeveloperOptions(onSeedData: _seedData),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLastBackupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Last Backup Successful",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4), // Added this SizedBox
                if (_lastBackupTime != null) // Added this conditional Text
                  Text(
                    DateFormat.yMMMd().add_jm().format(_lastBackupTime!),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  // Modified to a Row
                  children: [
                    Text(
                      _lastBackupPath != null
                          ? p.basename(_lastBackupPath!)
                          : "Unknown",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'Monospace',
                      ),
                    ),
                    if (_lastBackupSize != null) ...[
                      // Added this conditional Text
                      const SizedBox(width: 8),
                      Text(
                        "(${(_lastBackupSize! / 1024 / 1024).toStringAsFixed(2)} MB)",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isDangerous;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.buttonText,
    required this.onPressed,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDangerous ? Colors.white : color,
                  foregroundColor: isDangerous ? color : Colors.white,
                  elevation: 0,
                  side: isDangerous ? BorderSide(color: color) : null,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperOptions extends StatefulWidget {
  final VoidCallback onSeedData;

  const _DeveloperOptions({required this.onSeedData});

  @override
  State<_DeveloperOptions> createState() => _DeveloperOptionsState();
}

class _DeveloperOptionsState extends State<_DeveloperOptions> {
  bool _expanded = false;

  Future<void> _handleTap() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }

    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter password to access developer options:'),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(context, value == '1234'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, passwordController.text == '1234'),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _expanded = true);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Incorrect password")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _handleTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                "Developer Options",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                // --- Show User UUID ---
                Card(
                  color: Colors.blue.shade50,
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      Icons.fingerprint,
                      color: Colors.blue.shade700,
                    ),
                    title: const Text(
                      "User UUID",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: SelectableText(
                      AuthService.instance.currentUser?.id ?? "Unknown",
                      style: const TextStyle(fontFamily: 'Monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // --- Seed Data ---
                Card(
                  color: Colors.red.shade50,
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                    ),
                    title: Text(
                      "Seed Dummy Data",
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      "Populates database with test records.",
                    ),
                    trailing: TextButton(
                      onPressed: widget.onSeedData,
                      child: const Text("Seed"),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
