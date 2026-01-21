import 'logger_service.dart';

/// 📊 DAO Logging Utility - Provides consistent logging for database operations
class DaoLogger {
  /// Log database query operation
  static void logQuery({
    required String dao,
    required String operation,
    required int? result,
    int? count,
    int? resultCount,
  }) {
    final tag = '📊 $dao';
    final details = [
      operation,
      if (resultCount != null) 'found: $resultCount items',
      if (count != null) 'affected: $count rows',
    ].join(', ');

    if (result != null && result > 0) {
      logger.info(tag, '✅ $details');
    } else if (resultCount == 0 || count == 0) {
      logger.warning(tag, '⚠️ No results - $operation');
    } else {
      logger.debug(tag, '📥 $details');
    }
  }

  /// Log database insert operation
  static void logInsert({
    required String dao,
    required String recordId,
    Map<String, dynamic>? data,
  }) {
    final tag = '📊 $dao';
    logger.info(
      tag,
      '➕ INSERT record: $recordId',
      context: {
        'operation': 'insert',
        'recordId': recordId,
        if (data != null) 'fieldsCount': data.length,
      },
    );
  }

  /// Log database update operation
  static void logUpdate({
    required String dao,
    required String recordId,
    required int count,
    Map<String, dynamic>? newData,
  }) {
    final tag = '📊 $dao';
    final message = count > 0 ? '✏️ UPDATE: $count record(s) updated' : '⚠️ UPDATE: No records matched';
    logger.info(
      tag,
      message,
      context: {
        'operation': 'update',
        'recordId': recordId,
        'affectedRows': count,
        if (newData != null) 'fieldsChanged': newData.length,
      },
    );
  }

  /// Log database delete operation
  static void logDelete({
    required String dao,
    required String recordId,
    required int count,
  }) {
    final tag = '📊 $dao';
    if (count > 0) {
      logger.warning(
        tag,
        '🗑️ DELETE: $count record(s) deleted',
        context: {
          'operation': 'delete',
          'recordId': recordId,
          'affectedRows': count,
        },
      );
    } else {
      logger.warning(tag, '⚠️ DELETE: No records found for $recordId');
    }
  }

  /// Log batch operation
  static void logBatch({
    required String dao,
    required String operation,
    required int itemCount,
    int? successCount,
  }) {
    final tag = '📊 $dao';
    final success = successCount ?? itemCount;
    final status = success == itemCount ? '✅' : '⚠️';
    logger.info(
      tag,
      '$status BATCH $operation: $success/$itemCount items',
      context: {
        'operation': 'batch_$operation',
        'totalItems': itemCount,
        'successItems': success,
      },
    );
  }

  /// Log database error
  static void logError({
    required String dao,
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final tag = '📊 $dao';
    logger.error(
      tag,
      '❌ $operation failed',
      error: error,
      stackTrace: stackTrace,
      context: context ?? {},
    );
  }

  /// Log query with result count
  static void logQueryResult({
    required String dao,
    required String operation,
    required List<dynamic> results,
  }) {
    final tag = '📊 $dao';
    if (results.isEmpty) {
      logger.debug(tag, '🔍 $operation: No results found');
    } else {
      logger.info(tag, '🔍 $operation: Found ${results.length} item(s)');
    }
  }

  /// Log complex operation
  static void logOperation({
    required String dao,
    required String operationName,
    required String status, // 'started', 'completed', 'failed'
    Map<String, dynamic>? metadata,
  }) {
    final tag = '📊 $dao';
    
    switch (status) {
      case 'started':
        logger.debug(tag, '▶️ $operationName started', context: metadata);
        break;
      case 'completed':
        logger.info(tag, '✅ $operationName completed', context: metadata);
        break;
      case 'failed':
        logger.error(tag, '❌ $operationName failed', context: metadata);
        break;
      default:
        logger.info(tag, '$operationName: $status', context: metadata);
    }
  }
}

/// Safe DAO execution wrapper
Future<T> safeDaoOperation<T>({
  required Future<T> Function() operation,
  required String dao,
  required String operationName,
  T? fallback,
}) async {
  final tag = '📊 $dao';
  
  try {
    logger.debug(tag, '▶️ Starting: $operationName');
    final result = await operation();
    logger.info(tag, '✅ Completed: $operationName');
    return result;
  } catch (e, st) {
    logger.error(
      tag,
      '❌ Error in $operationName',
      error: e,
      stackTrace: st,
      context: {'operation': operationName},
    );
    
    if (fallback != null) {
      logger.warning(tag, 'Using fallback value for $operationName');
      return fallback;
    }
    
    rethrow;
  }
}
