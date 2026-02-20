import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'logger_service.dart';

class BackupService {
  static const String _lambdaUrl =
      'https://qvwbj1pzic.execute-api.eu-north-1.amazonaws.com/prod/backup';

  /// Requests a pre-signed URL from Lambda for uploading a backup.
  /// Action: upload
  Future<String?> getPresignedUrl(String userId, String fileName) async {
    try {
      final response = await http.post(
        Uri.parse(_lambdaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'upload',
          'user_id': userId,
          'file_name': fileName,
        }),
      );

      if (response.statusCode == 200) {
        // Handle double-encoded JSON response from Lambda Proxy Integration
        final decoded = jsonDecode(response.body);

        // Check if 'body' exists and is a string (double encoded) or map
        dynamic bodyData;
        if (decoded is Map<String, dynamic> && decoded.containsKey('body')) {
          final bodyContent = decoded['body'];
          if (bodyContent is String) {
            bodyData = jsonDecode(bodyContent);
          } else {
            bodyData = bodyContent;
          }
        } else {
          // Fallback if not double wrapped (direct response)
          bodyData = decoded;
        }

        if (bodyData is Map<String, dynamic> && bodyData.containsKey('url')) {
          final url = bodyData['url'] as String?;
          logger.info('BackupService', 'Got upload URL: $url');
          return url;
        } else {
          logger.error(
            'BackupService',
            'URL not found in response body: $bodyData',
          );
          return null;
        }
      } else {
        logger.error(
          'BackupService',
          'Failed to get upload URL. Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception('Failed to get upload URL: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('BackupService', 'Error requesting upload URL', error: e);
      rethrow;
    }
  }

  /// Requests a pre-signed URL for downloading the latest backup.
  /// Action: download
  Future<Map<String, String>?> getRestoreUrl(String userId) async {
    try {
      final response = await http.post(
        Uri.parse(_lambdaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'download', 'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        dynamic bodyData;

        // Handle potential double encoding
        if (decoded is Map<String, dynamic> && decoded.containsKey('body')) {
          final bodyContent = decoded['body'];
          if (bodyContent is String) {
            bodyData = jsonDecode(bodyContent);
          } else {
            bodyData = bodyContent;
          }
        } else {
          bodyData = decoded;
        }

        if (bodyData is Map<String, dynamic> && bodyData.containsKey('url')) {
          logger.info(
            'BackupService',
            'Got restore URL for file: ${bodyData['file_name']}',
          );
          return {
            'url': bodyData['url'] as String,
            'file_name':
                bodyData['file_name'] as String? ?? 'backup_restore.db',
          };
        } else {
          logger.warning(
            'BackupService',
            'No backup found or URL missing: $bodyData',
          );
          return null;
        }
      } else {
        logger.error(
          'BackupService',
          'Failed to get restore URL. Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception('Failed to get restore URL: ${response.statusCode}');
      }
    } catch (e) {
      logger.error('BackupService', 'Error requesting restore URL', error: e);
      rethrow;
    }
  }

  /// Uploads the database file to S3 using the pre-signed URL.
  Future<void> uploadDbBackup(File dbFile, String presignedUrl) async {
    try {
      if (!await dbFile.exists()) {
        throw Exception('Database file not found at ${dbFile.path}');
      }

      final bytes = await dbFile.readAsBytes();

      // S3 presigned URLs expect a PUT request with the file binary
      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {'Content-Type': 'application/octet-stream'},
        body: bytes,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to upload file to S3. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      logger.error('BackupService', 'Error uploading DB backup', error: e);
      rethrow;
    }
  }
}
