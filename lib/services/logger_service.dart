import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 📋 Log Levels (In order of severity)
enum LogLevel {
  debug,    // 🔍 Detailed diagnostic information
  info,     // ℹ️ General informational messages
  warning,  // ⚠️ Warning messages (recoverable issues)
  error,    // ❌ Error messages (app can still function)
  critical, // 🔴 Critical errors (app may crash or stop functioning)
}

/// 📝 Log Entry Model
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic>? context;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
    this.context,
  });

  /// Format log entry as string
  String format() {
    final levelStr = _getLevelString(level);
    final dateStr = _formatDateTime(timestamp);
    final contextStr = context != null ? ' | Context: $context' : '';
    return '[$dateStr] $levelStr [$tag] $message$contextStr';
  }

  /// Format with stack trace (for error logs)
  String formatWithTrace() {
    final base = format();
    return stackTrace != null ? '$base\nStackTrace:\n$stackTrace' : base;
  }

  static String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍 DEBUG';
      case LogLevel.info:
        return 'ℹ️  INFO';
      case LogLevel.warning:
        return '⚠️  WARN';
      case LogLevel.error:
        return '❌ ERROR';
      case LogLevel.critical:
        return '🔴 CRIT';
    }
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }
}

/// 🎯 Centralized Logging Service
/// 
/// Features:
/// - Multiple log levels
/// - File logging support
/// - Contextual logging
/// - Stack trace capture
/// - Performance monitoring
/// - Log rotation
/// 
/// Usage:
/// ```dart
/// final logger = LoggerService.instance;
/// logger.info('UserLogin', 'User logged in successfully');
/// logger.error('PaymentService', 'Payment failed', error: e, stackTrace: st);
/// logger.warning('Performance', 'Database query took 5 seconds');
/// ```
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  
  factory LoggerService() => _instance;
  
  LoggerService._internal();
  
  static LoggerService get instance => _instance;

  // Configuration
  final List<LogEntry> _logs = [];
  LogLevel _minimumLevel = LogLevel.debug;
  bool _enableConsoleLogging = true;
  bool _enableFileLogging = true;
  bool _enableContextCapture = true;
  bool _initialized = false;
  File? _logFile;
  
  // Performance tracking
  final Map<String, int> _performanceMarkers = {};
  final Map<String, Duration> _performanceMetrics = {};

  /// Initialize logging service
  Future<void> initialize({
    LogLevel minimumLevel = LogLevel.debug,
    bool enableConsoleLogging = true,
    bool enableFileLogging = true,
    bool enableContextCapture = true,
  }) async {
    if (_initialized) return;

    _minimumLevel = minimumLevel;
    _enableConsoleLogging = enableConsoleLogging;
    _enableFileLogging = enableFileLogging;
    _enableContextCapture = enableContextCapture;

    if (_enableFileLogging) {
      await _initializeFileLogging();
    }

    _initialized = true;
    info('LoggerService', '✅ Logger initialized at ${DateTime.now()}');
  }

  /// Initialize file logging
  Future<void> _initializeFileLogging() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final dateStr = DateTime.now().toString().split(' ')[0];
      _logFile = File('${logDir.path}/app_$dateStr.log');

      // Create file if it doesn't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }

      debugPrint('📁 Log file: ${_logFile!.path}');
    } catch (e) {
      debugPrint('❌ Failed to initialize file logging: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Logging Methods
  // ═══════════════════════════════════════════════════════════════

  /// Log debug message (detailed diagnostic info)
  void debug(
    String tag,
    String message, {
    Map<String, dynamic>? context,
  }) {
    _log(
      level: LogLevel.debug,
      tag: tag,
      message: message,
      context: context,
    );
  }

  /// Log info message
  void info(
    String tag,
    String message, {
    Map<String, dynamic>? context,
  }) {
    _log(
      level: LogLevel.info,
      tag: tag,
      message: message,
      context: context,
    );
  }

  /// Log warning message
  void warning(
    String tag,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
  }) {
    _log(
      level: LogLevel.warning,
      tag: tag,
      message: message,
      context: context,
      error: error,
    );
  }

  /// Log error message with optional stack trace
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      level: LogLevel.error,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Log critical error that may crash app
  void critical(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log(
      level: LogLevel.critical,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Private Logging Implementation
  // ═══════════════════════════════════════════════════════════════

  void _log({
    required LogLevel level,
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    // Check if this log level should be logged
    if (level.index < _minimumLevel.index) {
      return;
    }

    // Build final message with error info
    String finalMessage = message;
    if (error != null) {
      finalMessage = '$message | Error: $error';
    }

    // Create log entry
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: finalMessage,
      stackTrace: stackTrace?.toString(),
      context: _enableContextCapture ? context : null,
    );

    _logs.add(entry);

    // Console logging
    if (_enableConsoleLogging) {
      if (stackTrace != null) {
        debugPrint(entry.formatWithTrace());
      } else {
        debugPrint(entry.format());
      }
    }

    // File logging
    if (_enableFileLogging && _logFile != null) {
      _writeToFile(entry);
    }
  }

  /// Write log entry to file
  Future<void> _writeToFile(LogEntry entry) async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final logStr = entry.formatWithTrace();
        await _logFile!.writeAsString(
          '$logStr\n',
          mode: FileMode.append,
        );
      }
    } catch (e) {
      debugPrint('⚠️  Failed to write to log file: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Performance Monitoring
  // ═══════════════════════════════════════════════════════════════

  /// Start performance measurement
  void startPerformanceTimer(String operationName) {
    _performanceMarkers[operationName] = DateTime.now().millisecondsSinceEpoch;
    debug('Performance', 'Started measuring: $operationName');
  }

  /// End performance measurement and log duration
  void endPerformanceTimer(String operationName, {String? tag}) {
    final startTime = _performanceMarkers[operationName];
    if (startTime == null) {
      warning('Performance', 'Timer for "$operationName" not started');
      return;
    }

    final duration = Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - startTime,
    );

    _performanceMetrics[operationName] = duration;
    _performanceMarkers.remove(operationName);

    final logTag = tag ?? 'Performance';
    final durationStr = _formatDuration(duration);
    
    if (duration.inMilliseconds > 1000) {
      warning(logTag, '$operationName took $durationStr (slow operation)');
    } else {
      info(logTag, '$operationName took $durationStr');
    }
  }

  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds}ms';
    } else if (d.inSeconds < 60) {
      return '${d.inSeconds}s ${d.inMilliseconds % 1000}ms';
    } else {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Log Retrieval & Management
  // ═══════════════════════════════════════════════════════════════

  /// Get all logged entries
  List<LogEntry> getAllLogs() => List.from(_logs);

  /// Get logs by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Get logs by tag
  List<LogEntry> getLogsByTag(String tag) {
    return _logs.where((log) => log.tag == tag).toList();
  }

  /// Get logs within time range
  List<LogEntry> getLogsByTimeRange(DateTime start, DateTime end) {
    return _logs
        .where((log) => log.timestamp.isAfter(start) && log.timestamp.isBefore(end))
        .toList();
  }

  /// Get recent logs
  List<LogEntry> getRecentLogs({int count = 100}) {
    final sorted = _logs.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(count).toList();
  }

  /// Get performance metrics
  Map<String, Duration> getPerformanceMetrics() {
    return Map.from(_performanceMetrics);
  }

  /// Clear logs
  void clearLogs() {
    _logs.clear();
    _performanceMetrics.clear();
    info('LoggerService', '🗑️  All logs cleared');
  }

  /// Export logs to file
  Future<File?> exportLogs({String? filename}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-');
      final file = File('${dir.path}/logs_export_$timestamp.txt');

      final content = _logs.map((log) => log.formatWithTrace()).join('\n');
      await file.writeAsString(content);

      info('LoggerService', '✅ Logs exported to: ${file.path}');
      return file;
    } catch (e) {
      error('LoggerService', 'Failed to export logs', error: e);
      return null;
    }
  }

  /// Get log statistics
  Map<String, dynamic> getStatistics() {
    final allLogs = _logs;
    
    return {
      'totalLogs': allLogs.length,
      'debugCount': allLogs.where((l) => l.level == LogLevel.debug).length,
      'infoCount': allLogs.where((l) => l.level == LogLevel.info).length,
      'warningCount': allLogs.where((l) => l.level == LogLevel.warning).length,
      'errorCount': allLogs.where((l) => l.level == LogLevel.error).length,
      'criticalCount': allLogs.where((l) => l.level == LogLevel.critical).length,
      'oldestLog': allLogs.isNotEmpty ? allLogs.first.timestamp : null,
      'newestLog': allLogs.isNotEmpty ? allLogs.last.timestamp : null,
      'uniqueTags': allLogs.map((l) => l.tag).toSet().toList(),
      'performanceMetrics': _performanceMetrics,
    };
  }

  /// Print log statistics to console
  void printStatistics() {
    final stats = getStatistics();
    debugPrint('\n📊 ═══════════════════════════════════════════════════════════');
    debugPrint('📊 LOG STATISTICS');
    debugPrint('📊 ═══════════════════════════════════════════════════════════');
    debugPrint('📊 Total Logs: ${stats['totalLogs']}');
    debugPrint('📊 Debug: ${stats['debugCount']} | Info: ${stats['infoCount']} | Warning: ${stats['warningCount']}');
    debugPrint('📊 Error: ${stats['errorCount']} | Critical: ${stats['criticalCount']}');
    debugPrint('📊 Time Span: ${stats['oldestLog']} to ${stats['newestLog']}');
    debugPrint('📊 Unique Tags: ${(stats['uniqueTags'] as List).join(', ')}');
    debugPrint('📊 ═══════════════════════════════════════════════════════════\n');
  }
}

/// Convenience getters for global logger
final logger = LoggerService.instance;
