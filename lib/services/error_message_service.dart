import 'package:flutter/material.dart';
import 'exception_handler.dart';
import 'logger_service.dart';

/// 💬 Error Message Service - Generates user-friendly error messages
class ErrorMessageService {
  static const String _tag = '💬 ErrorMessageService';

  /// Get user-friendly message from exception
  static String getMessage(dynamic error) {
    if (error is AppException) {
      return error.getUserMessage();
    }

    // Network errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    if (error.toString().contains('HandshakeException')) {
      return 'Secure connection failed. This may be a security issue.';
    }

    if (error.toString().contains('TimeoutException')) {
      return 'Operation took too long. Please check your connection and try again.';
    }

    // Database errors
    if (error.toString().contains('DatabaseException') ||
        error.toString().contains('sqlite')) {
      return 'Database error occurred. Your data may be corrupted. Please restart the app.';
    }

    // File errors
    if (error.toString().contains('FileSystemException') ||
        error.toString().contains('PathNotFoundException')) {
      return 'File operation failed. Please ensure you have storage permissions.';
    }

    if (error.toString().contains('Cannot create file')) {
      return 'Cannot save file. Please check available storage space.';
    }

    // Permission errors
    if (error.toString().contains('Permission denied') ||
        error.toString().contains('PERMISSION')) {
      return 'Permission denied. Please grant the required permissions in settings.';
    }

    // Default
    return 'An unexpected error occurred. Please try again or contact support.';
  }

  /// Get error title
  static String getTitle(dynamic error) {
    if (error is NetworkException) return '🌐 Connection Error';
    if (error is DatabaseException) return '🗄️ Database Error';
    if (error is ValidationException) return '✔️ Validation Error';
    if (error is PrinterException) return '🖨️ Printer Error';
    if (error is FileException) return '📄 File Error';
    if (error is StorageException) return '💾 Storage Error';
    if (error is TimeoutException) return '⏱️ Timeout Error';
    if (error is ServiceException) return '🔄 Service Error';
    if (error is AuthException) return '🔐 Authentication Error';
    return '❌ Error';
  }

  /// Get error icon
  static IconData getIcon(dynamic error) {
    if (error is NetworkException) return Icons.wifi_off;
    if (error is DatabaseException) return Icons.storage;
    if (error is ValidationException) return Icons.error_outline;
    if (error is PrinterException) return Icons.print;
    if (error is FileException) return Icons.file_present;
    if (error is StorageException) return Icons.sd_storage;
    if (error is TimeoutException) return Icons.schedule;
    if (error is ServiceException) return Icons.cloud_off;
    if (error is AuthException) return Icons.lock;
    return Icons.error;
  }

  /// Get error color
  static Color getColor(dynamic error) {
    if (error is ValidationException) return Colors.orange.shade600;
    if (error is TimeoutException) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  /// Show error snackbar
  static void showError(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    logger.warning(_tag, 'Showing error: $error');

    final message = getMessage(error);
    final title = getTitle(error);
    final icon = getIcon(error);
    final color = getColor(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  logger.info(_tag, 'User tapped retry');
                  onRetry();
                },
              )
            : null,
      ),
    );
  }

  /// Show error dialog
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    String? retryLabel,
  }) async {
    logger.warning(_tag, 'Showing error dialog: $error');

    final message = getMessage(error);
    final title = getTitle(error);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              logger.info(_tag, 'User dismissed error dialog');
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                logger.info(_tag, 'User tapped retry in dialog');
                Navigator.pop(context);
                onRetry();
              },
              child: Text(retryLabel ?? 'Retry'),
            ),
        ],
      ),
    );
  }

  /// Get specific error message for operations
  static String getOperationMessage(String operation, dynamic error) {
    final message = getMessage(error);
    return 'Failed to $operation: $message';
  }

  /// Log and show error
  static void logAndShow(
    BuildContext context,
    dynamic error, {
    required String tag,
    VoidCallback? onRetry,
  }) {
    if (error is AppException) {
      error.log(tag);
    } else {
      ExceptionHandler.handleException(error, tag: tag);
    }

    showError(context, error, onRetry: onRetry);
  }

  /// Get detailed error context for debugging
  static String getDetailedMessage(
    dynamic error, [
    Map<String, dynamic>? additionalContext,
  ]) {
    final buffer = StringBuffer();

    buffer.writeln('═══ Error Details ═══');
    buffer.writeln('Type: ${error.runtimeType}');
    buffer.writeln('Message: ${getMessage(error)}');

    if (error is AppException) {
      buffer.writeln('Original Error: ${error.originalError}');
      if (error.context != null) {
        buffer.writeln('Context: ${error.context}');
      }
    }

    if (additionalContext != null && additionalContext.isNotEmpty) {
      buffer.writeln('Additional Context:');
      additionalContext.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    buffer.writeln('═══════════════════');

    return buffer.toString();
  }
}

/// 📋 Error Recovery Service - Suggests recovery actions
class ErrorRecoveryService {
  /// Get recovery suggestions
  static List<RecoverySuggestion> getSuggestions(dynamic error) {
    final suggestions = <RecoverySuggestion>[];

    if (error is NetworkException) {
      suggestions.addAll([
        RecoverySuggestion(
          title: 'Check Internet Connection',
          description:
              'Ensure your device is connected to a stable internet network',
          action: 'open_settings',
        ),
        RecoverySuggestion(
          title: 'Try Later',
          description: 'Wait a few moments and try the operation again',
          action: 'retry',
        ),
      ]);
    } else if (error is DatabaseException) {
      suggestions.addAll([
        RecoverySuggestion(
          title: 'Restart App',
          description:
              'Close and reopen the application to resolve database issues',
          action: 'restart_app',
        ),
        RecoverySuggestion(
          title: 'Clear Cache',
          description: 'Clear app cache from device settings',
          action: 'open_settings',
        ),
      ]);
    } else if (error is ValidationException) {
      suggestions.add(
        RecoverySuggestion(
          title: 'Review Input',
          description: 'Check your input data and correct any errors',
          action: 'review',
        ),
      );
    } else if (error is PrinterException) {
      suggestions.addAll([
        RecoverySuggestion(
          title: 'Check Printer Connection',
          description: 'Ensure printer is powered on and connected to network',
          action: 'open_settings',
        ),
        RecoverySuggestion(
          title: 'Test Printer',
          description: 'Go to printer settings and run connection test',
          action: 'open_printer_settings',
        ),
      ]);
    } else if (error is FileException) {
      suggestions.addAll([
        RecoverySuggestion(
          title: 'Check Storage Space',
          description: 'Ensure you have enough storage space available',
          action: 'open_settings',
        ),
        RecoverySuggestion(
          title: 'Grant Permissions',
          description: 'Allow the app to access storage in device settings',
          action: 'open_settings',
        ),
      ]);
    } else if (error is TimeoutException) {
      suggestions.addAll([
        RecoverySuggestion(
          title: 'Check Connection Speed',
          description: 'Try the operation again with a faster connection',
          action: 'retry',
        ),
        RecoverySuggestion(
          title: 'Reduce Data Size',
          description: 'Try with smaller data or fewer items',
          action: 'review',
        ),
      ]);
    } else {
      suggestions.add(
        RecoverySuggestion(
          title: 'Try Again',
          description: 'Attempt the operation again',
          action: 'retry',
        ),
      );
    }

    return suggestions;
  }
}

/// Recovery suggestion model
class RecoverySuggestion {
  final String title;
  final String description;
  final String
  action; // 'retry', 'restart_app', 'open_settings', 'open_printer_settings', 'review'

  RecoverySuggestion({
    required this.title,
    required this.description,
    required this.action,
  });
}

/// 🔄 Error State Widget - Display error with recovery options
class ErrorStateWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final String? customMessage;

  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final title = ErrorMessageService.getTitle(error);
    final message = customMessage ?? ErrorMessageService.getMessage(error);
    final icon = ErrorMessageService.getIcon(error);
    final color = ErrorMessageService.getColor(error);
    final suggestions = ErrorRecoveryService.getSuggestions(error);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Recovery Suggestions:',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...suggestions.map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${suggestion.title}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onDismiss != null)
                  OutlinedButton(
                    onPressed: onDismiss,
                    child: const Text('Dismiss'),
                  ),
                if (onDismiss != null && onRetry != null)
                  const SizedBox(width: 12),
                if (onRetry != null)
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
