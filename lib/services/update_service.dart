import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'logger_service.dart';

class UpdateInfo {
  final String latestVersion;
  final String notes;
  final String downloadUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.notes,
    required this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] ?? '0.0.0',
      notes: json['notes'] ?? 'No release notes provided.',
      downloadUrl: json['url'] ?? '',
    );
  }
}

class UpdateService {
  // TODO: Replace with actual bucket URL when provided.
  // Using user provided placeholder or potential bucket from requirements.
  static const String _updateJsonUrl =
      'https://mian-traders-app.s3.eu-north-1.amazonaws.com/update.json';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(_updateJsonUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(data);

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(updateInfo.latestVersion, currentVersion)) {
          return updateInfo;
        }
      } else {
        logger.warning(
          'UpdateService',
          'Failed to check updates: ${response.statusCode}',
        );
      }
    } catch (e) {
      logger.error('UpdateService', 'Error checking for updates', error: e);
    }
    return null;
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      List<int> latestParts = latest.split('.').map(int.parse).toList();
      List<int> currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true; // Latest has more parts
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false; // Versions are equal
    } catch (e) {
      // If version referencing fails, assume no update to be safe
      return false;
    }
  }
}
