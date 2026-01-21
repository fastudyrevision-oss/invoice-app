import 'logger_service.dart';

/// 🚨 Custom Exception Base Class
abstract class AppException implements Exception {
  final String message;
  final String? originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  AppException({
    required this.message,
    this.originalError,
    this.stackTrace,
    this.context,
  });

  /// Log this exception
  void log(String tag) {
    logger.error(
      tag,
      message,
      error: originalError ?? this,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Get user-friendly message
  String getUserMessage() => message;

  @override
  String toString() => message;
}

// ═══════════════════════════════════════════════════════════════════════════
// Specific Exception Types
// ═══════════════════════════════════════════════════════════════════════════

/// 📱 Network/Connection Errors
class NetworkException extends AppException {
  NetworkException({
    super.message = 'Network connection error',
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() => 'Network error: $message. Please check your internet connection.';
}

/// 🗄️ Database/DAO Errors
class DatabaseException extends AppException {
  final String? operation;
  
  DatabaseException({
    super.message = 'Database operation failed',
    this.operation,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    if (operation != null) {
      return 'Database error during "$operation": $message';
    }
    return 'Database error: $message';
  }
}

/// 🔐 Authentication/Authorization Errors
class AuthException extends AppException {
  final String? reason;
  
  AuthException({
    super.message = 'Authentication failed',
    this.reason,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    final reasonStr = reason != null ? ' ($reason)' : '';
    return 'Authentication error: $message$reasonStr';
  }
}

/// ✔️ Validation Errors
class ValidationException extends AppException {
  final String? field;
  final dynamic invalidValue;
  
  ValidationException({
    required super.message,
    this.field,
    this.invalidValue,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    if (field != null) {
      return 'Invalid $field: $message';
    }
    return 'Validation error: $message';
  }
}

/// 🖨️ Printer/Hardware Errors
class PrinterException extends AppException {
  final String? printerAddress;
  final int? printerPort;
  
  PrinterException({
    super.message = 'Printer operation failed',
    this.printerAddress,
    this.printerPort,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    final printerInfo = printerAddress != null ? ' ($printerAddress:$printerPort)' : '';
    return 'Printer error$printerInfo: $message. Please check printer connection.';
  }
}

/// 📄 File/Export Errors
class FileException extends AppException {
  final String? filename;
  
  FileException({
    super.message = 'File operation failed',
    this.filename,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    final fileStr = filename != null ? ' ($filename)' : '';
    return 'File error$fileStr: $message';
  }
}

/// 💾 Storage/Permission Errors
class StorageException extends AppException {
  final String? requiredPermission;
  
  StorageException({
    super.message = 'Storage operation failed',
    this.requiredPermission,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    if (requiredPermission != null) {
      return 'Storage permission error: Please grant $requiredPermission permission.';
    }
    return 'Storage error: $message';
  }
}

/// ⏱️ Timeout Errors
class TimeoutException extends AppException {
  final Duration? timeout;
  
  TimeoutException({
    super.message = 'Operation timed out',
    this.timeout,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    final timeStr = timeout != null ? ' (${timeout!.inSeconds}s)' : '';
    return 'Operation timed out$timeStr. Please try again.';
  }
}

/// 🔄 API/Service Errors
class ServiceException extends AppException {
  final String? serviceName;
  final int? statusCode;
  
  ServiceException({
    super.message = 'Service operation failed',
    this.serviceName,
    this.statusCode,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() {
    final service = serviceName != null ? ' ($serviceName)' : '';
    final status = statusCode != null ? ' [HTTP $statusCode]' : '';
    return 'Service error$service$status: $message';
  }
}

/// ❌ Generic/Unknown Errors
class UnknownException extends AppException {
  UnknownException({
    super.message = 'An unexpected error occurred',
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String getUserMessage() => message;
}

// ═══════════════════════════════════════════════════════════════════════════
// Exception Handler Utilities
// ═══════════════════════════════════════════════════════════════════════════

/// 🛡️ Exception Handling Utilities
class ExceptionHandler {
  static const String _tag = '🛡️ ExceptionHandler';

  /// Convert generic exception to AppException
  static AppException handleException(
    dynamic error, {
    StackTrace? stackTrace,
    String? tag = 'UnknownTag',
    Map<String, dynamic>? context,
  }) {
    final appTag = tag ?? 'UnknownTag';

    // Already an AppException
    if (error is AppException) {
      error.log(appTag);
      return error;
    }

    // Network errors
    if (error.toString().toLowerCase().contains('connection') ||
        error.toString().toLowerCase().contains('socket') ||
        error.toString().toLowerCase().contains('timeout')) {
      final exception = NetworkException(
        message: error.toString(),
        originalError: error.toString(),
        stackTrace: stackTrace,
        context: context,
      );
      exception.log(appTag);
      return exception;
    }

    // Generic unknown error
    final exception = UnknownException(
      message: 'Unknown error: ${error.toString()}',
      originalError: error.toString(),
      stackTrace: stackTrace,
      context: context,
    );
    exception.log(appTag);
    return exception;
  }

  /// Safe wrapper for async operations
  static Future<T> safeExecute<T>(
    Future<T> Function() operation, {
    required String tag,
    T? fallbackValue,
    Map<String, dynamic>? context,
  }) async {
    try {
      logger.debug(tag, 'Starting operation...');
      logger.startPerformanceTimer('$tag-operation');
      
      final result = await operation();
      
      logger.endPerformanceTimer('$tag-operation', tag: tag);
      logger.info(tag, '✅ Operation completed successfully');
      
      return result;
    } catch (e, st) {
      logger.endPerformanceTimer('$tag-operation', tag: tag);
      final exception = ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: tag,
        context: context,
      );
      
      if (fallbackValue != null) {
        logger.warning(tag, 'Using fallback value');
        return fallbackValue;
      }
      
      rethrow;
    }
  }

  /// Safe wrapper for sync operations
  static T safeExecuteSync<T>(
    T Function() operation, {
    required String tag,
    T? fallbackValue,
    Map<String, dynamic>? context,
  }) {
    try {
      logger.debug(tag, 'Starting sync operation...');
      logger.startPerformanceTimer('$tag-sync-operation');
      
      final result = operation();
      
      logger.endPerformanceTimer('$tag-sync-operation', tag: tag);
      logger.info(tag, '✅ Sync operation completed successfully');
      
      return result;
    } catch (e, st) {
      logger.endPerformanceTimer('$tag-sync-operation', tag: tag);
      ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: tag,
        context: context,
      );
      
      if (fallbackValue != null) {
        logger.warning(tag, 'Using fallback value');
        return fallbackValue;
      }
      
      rethrow;
    }
  }

  /// Log exception and return null
  static T? tryExecute<T>(
    T Function() operation, {
    required String tag,
  }) {
    try {
      return operation();
    } catch (e, st) {
      ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: tag,
      );
      return null;
    }
  }

  /// Log exception and return fallback value
  static T tryExecuteWithFallback<T>(
    T Function() operation,
    T fallback, {
    required String tag,
  }) {
    try {
      return operation();
    } catch (e, st) {
      ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: tag,
      );
      return fallback;
    }
  }
}

/// 🔧 Retry Logic
class RetryConfig {
  final int maxAttempts;
  final Duration delay;
  final Duration maxDuration;
  final bool retryOnTimeout;

  const RetryConfig({
    this.maxAttempts = 3,
    this.delay = const Duration(milliseconds: 500),
    this.maxDuration = const Duration(minutes: 5),
    this.retryOnTimeout = true,
  });
}

/// Retry a future operation with exponential backoff
Future<T> retryAsync<T>(
  Future<T> Function() operation, {
  RetryConfig config = const RetryConfig(),
  required String tag,
}) async {
  int attempt = 0;
  Duration currentDelay = config.delay;
  DateTime startTime = DateTime.now();

  while (true) {
    attempt++;
    logger.debug(tag, 'Attempt $attempt/${config.maxAttempts}');

    try {
      return await operation();
    } catch (e, st) {
      final isLastAttempt = attempt >= config.maxAttempts;
      final elapsedTime = DateTime.now().difference(startTime);
      final exceedsMaxDuration = elapsedTime > config.maxDuration;

      if (isLastAttempt || exceedsMaxDuration) {
        logger.error(
          tag,
          'All $attempt attempts failed after ${elapsedTime.inSeconds}s',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }

      logger.warning(
        tag,
        'Attempt $attempt failed, retrying in ${currentDelay.inMilliseconds}ms',
        error: e,
      );

      await Future.delayed(currentDelay);
      currentDelay *= 2; // Exponential backoff
    }
  }
}
