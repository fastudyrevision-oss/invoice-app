# 🎯 Logging & Error Handling Implementation Guide

## ✅ Completed Components

This guide summarizes what has been implemented and how to integrate it throughout your app.

### 1. **LoggerService** ✅ 
📁 `lib/services/logger_service.dart` (450+ lines)

**What it does:**
- Centralized logging with 5 levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Persists logs to device file system
- Tracks performance metrics
- Captures context information
- Provides statistics and export functionality

**How to use:**
```dart
import 'services/logger_service.dart';

final logger = LoggerService.instance;

// Simple logging
logger.info('MyClass', 'Operation completed');
logger.warning('MyClass', 'Something unexpected happened');
logger.error('MyClass', 'Error occurred', error: exception);

// With context
logger.info('Service', 'Action completed', context: {
  'userId': '123',
  'operationTime': '2.5s',
});

// Performance tracking
logger.startPerformanceTimer('database_query');
// ... do work ...
logger.endPerformanceTimer('database_query', tag: 'MyService');
```

---

### 2. **Exception Handler** ✅ 
📁 `lib/services/exception_handler.dart` (400+ lines)

**What it does:**
- 10 custom exception classes for different error scenarios
- Automatic logging of exceptions
- Safe execution wrappers for async/sync operations
- Retry logic with exponential backoff
- Context capture for debugging

**Exception Types Available:**
```
NetworkException        - Connection, timeout, network issues
DatabaseException       - SQL, database operations
ValidationException     - Input validation failures
PrinterException        - Printer operations
FileException          - File I/O operations
StorageException       - Permissions, storage issues
TimeoutException       - Operation timeouts
ServiceException       - API/service errors
AuthException          - Authentication failures
UnknownException       - Unhandled errors
```

**How to use:**
```dart
import 'services/exception_handler.dart';

// Throw custom exceptions
try {
  throw ValidationException(
    message: 'Email is invalid',
    field: 'email',
  );
} catch (e) {
  e.getUserMessage(); // "Invalid email: Email is invalid"
}

// Safe execution wrapper
final customers = await ExceptionHandler.safeExecute(
  () => customerDao.getAllCustomers(),
  tag: 'CustomerService',
);

// Retry logic
try {
  await retryAsync(
    () => apiService.fetchData(),
    tag: 'API',
    config: RetryConfig(maxAttempts: 3),
  );
} catch (e) {
  // All retries failed
}
```

---

### 3. **Error Message Service** ✅ 
📁 `lib/services/error_message_service.dart` (350+ lines)

**What it does:**
- Generates user-friendly error messages
- Shows error snackbars and dialogs
- Provides recovery suggestions
- Displays error states with recovery options
- Gets appropriate icons and colors for different errors

**How to use:**
```dart
import 'services/error_message_service.dart';

// Show error snackbar
ErrorMessageService.showError(
  context,
  exception,
  onRetry: () { /* retry operation */ },
);

// Show error dialog
await ErrorMessageService.showErrorDialog(
  context,
  exception,
  onRetry: () { /* retry */ },
  retryLabel: 'Try Again',
);

// Get recovery suggestions
final suggestions = ErrorRecoveryService.getSuggestions(exception);
for (var suggestion in suggestions) {
  print('${suggestion.title}: ${suggestion.description}');
}

// Display error state in UI
return ErrorStateWidget(
  error: exception,
  onRetry: _loadData,
  onDismiss: () => Navigator.pop(context),
);
```

**Error Messages Generated:**
```
NetworkException       → "Network error: Failed to connect..."
DatabaseException      → "Database error during 'operation'..."
ValidationException    → "Invalid fieldName: message"
PrinterException       → "Printer error: Connection timeout..."
FileException         → "File error: Cannot save file"
StorageException      → "Storage permission error: Please grant..."
TimeoutException      → "Operation timed out (30s)..."
```

---

### 4. **DAO Logger Utility** ✅ 
📁 `lib/services/dao_logger.dart` (150+ lines)

**What it does:**
- Consistent logging patterns for database operations
- Tracks CRUD operations (insert, update, delete, query)
- Logs batch operations
- Captures operation metadata
- Provides error logging for failures

**How to use in DAOs:**
```dart
import 'services/dao_logger.dart';

Future<int> insertCustomer(Customer customer) async {
  try {
    final id = await db.insert("customers", customer.toMap());
    DaoLogger.logInsert(
      dao: 'CustomerDao',
      recordId: customer.id,
    );
    return id;
  } catch (e, st) {
    DaoLogger.logError(
      dao: 'CustomerDao',
      operation: 'insert',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}

Future<List<Customer>> getAllCustomers() async {
  try {
    final data = await db.query("customers");
    DaoLogger.logQueryResult(
      dao: 'CustomerDao',
      operation: 'getAllCustomers',
      results: data,
    );
    return data.map<Customer>((e) => Customer.fromMap(e)).toList();
  } catch (e, st) {
    DaoLogger.logError(
      dao: 'CustomerDao',
      operation: 'getAllCustomers',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}
```

---

### 5. **ThermalPrintingService** ✅ 
📁 `lib/services/thermal_printer/thermal_printing_service.dart`

**What was updated:**
- All print methods now log operations with performance tracking
- Connection attempts are logged
- Print failures include detailed error context
- Auto-connect attempts are logged
- All exceptions are properly thrown as `PrinterException`

**Logging in action:**
```
🖨️ ThermalPrinting | INFO | 📄 Printing invoice: INV-001
🖨️ ThermalPrinting | DEBUG | Using printer: 192.168.1.100:9100
🖨️ ThermalPrinting | DEBUG | Receipt image generated: 15234 bytes
🖨️ ThermalPrinting | DEBUG | Sending receipt to printer (15234 bytes)
🖨️ ThermalPrinting | INFO | ✅ Receipt sent to printer successfully
```

---

## 📝 Implementation Checklist

### Next Steps (Not Yet Done):

- [ ] **Export Services** (lib/services/export_service.dart, pdf_service.dart)
  - Add logging to PDF generation
  - Log export operations
  - Track file write operations

- [ ] **UI Screens** (All screens in lib/ui/)
  - Add try-catch to event handlers
  - Use ErrorMessageService.showError() for user feedback
  - Display loading states and error states
  - Add error dialogs for critical operations

---

## 🚀 Quick Start Integration

### For Services

```dart
import 'services/logger_service.dart';
import 'services/exception_handler.dart';
import 'services/error_message_service.dart';

class MyService {
  Future<List<Data>> fetchData() async {
    try {
      logger.info('MyService', 'Fetching data...');
      final result = await _fetch();
      logger.info('MyService', 'Data fetched successfully');
      return result;
    } catch (e, st) {
      throw ExceptionHandler.handleException(
        e,
        stackTrace: st,
        tag: 'MyService',
      );
    }
  }
}
```

### For UI Screens

```dart
void _onButtonTap() async {
  try {
    setState(() => _isLoading = true);
    final result = await _service.doSomething();
    logger.info('Screen', 'Operation successful');
  } on ValidationException catch (e) {
    ErrorMessageService.showError(context, e);
  } catch (e, st) {
    final exception = ExceptionHandler.handleException(
      e,
      stackTrace: st,
      tag: 'MyScreen',
    );
    ErrorMessageService.showErrorDialog(
      context,
      exception,
      onRetry: _onButtonTap,
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### For DAOs

```dart
import 'services/dao_logger.dart';

Future<int> insertRecord(Model model) async {
  try {
    final id = await db.insert('table', model.toMap());
    DaoLogger.logInsert(
      dao: 'MyDao',
      recordId: model.id,
    );
    return id;
  } catch (e, st) {
    DaoLogger.logError(
      dao: 'MyDao',
      operation: 'insert',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}
```

---

## 📊 Log Levels Reference

| Level | When to Use | Example |
|-------|-----------|---------|
| **DEBUG** | Detailed flow information | "Query started", "Variable set to X" |
| **INFO** | Significant successful events | "User created", "Payment processed" |
| **WARNING** | Unexpected situations (no crash) | "Low balance", "Retry attempt 2" |
| **ERROR** | Errors with recovery | "Database query failed", caught exceptions |
| **CRITICAL** | System-breaking errors | "Database connection lost" |

---

## 🎯 Best Practices

1. **Always log entry and exit**
   ```dart
   logger.debug('Service', 'Starting operation');
   // ... do work ...
   logger.info('Service', '✅ Operation completed');
   ```

2. **Include context for debugging**
   ```dart
   logger.error('Payment', 'Failed to process', context: {
     'customerId': customerId,
     'amount': amount,
     'errorCode': errorCode,
   });
   ```

3. **Never log sensitive data**
   ```dart
   // ❌ WRONG
   logger.info('Login', 'User: $email, Password: $password');
   
   // ✅ RIGHT
   logger.info('Login', 'User authenticated', context: {
     'userId': user.id,
     'loginTime': DateTime.now(),
   });
   ```

4. **Use consistent tag format**
   ```dart
   // Format: emoji + ClassName
   static const String _tag = '📊 CustomerService';
   static const String _tag = '🖨️ PrinterService';
   static const String _tag = '💬 ErrorMessageService';
   ```

5. **Always use try-catch for operations**
   ```dart
   try {
     // operation
   } catch (e, st) {
     logger.error(tag, 'Operation failed', error: e, stackTrace: st);
     rethrow;
   }
   ```

---

## 📚 Files Created/Modified

### Created Files:
- ✅ `lib/services/logger_service.dart` - Core logging
- ✅ `lib/services/exception_handler.dart` - Exception handling
- ✅ `lib/services/error_message_service.dart` - User messages
- ✅ `lib/services/dao_logger.dart` - DAO logging utility
- ✅ `LOGGING_AND_ERROR_HANDLING.md` - Detailed documentation

### Modified Files:
- ✅ `lib/services/thermal_printer/thermal_printing_service.dart` - Added comprehensive logging

### To Be Modified:
- ⏳ All DAO files in `lib/dao/` - Add DaoLogger calls
- ⏳ Export services in `lib/services/` - Add logging
- ⏳ All UI screens in `lib/ui/` - Add error handling

---

## 🧪 Testing

### Manual Testing:

1. **Test logging output**
   ```dart
   final logs = await logger.getAllLogs();
   print('Total logs: ${logs.length}');
   ```

2. **Test error messages**
   ```dart
   try {
     throw ValidationException(
       message: 'Test validation error',
       field: 'testField',
     );
   } catch (e) {
     ErrorMessageService.showError(context, e);
   }
   ```

3. **Test exception handling**
   ```dart
   try {
     throw NetworkException(message: 'Test network error');
   } catch (e) {
     print(ErrorMessageService.getMessage(e));
   }
   ```

---

## 💡 Common Patterns

### Pattern 1: Service Operation with Logging
```dart
Future<List<T>> getAll() async {
  try {
    logger.debug(_tag, 'Fetching all records');
    final results = await _fetch();
    logger.info(_tag, '✅ Fetched ${results.length} records');
    return results;
  } catch (e, st) {
    throw ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
  }
}
```

### Pattern 2: UI Event Handler with Error Handling
```dart
void _onAction() async {
  try {
    setState(() => _isLoading = true);
    logger.info(_tag, 'User initiated action');
    
    final result = await _service.action();
    
    logger.info(_tag, 'Action completed successfully');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Success!')),
    );
  } catch (e, st) {
    final exception = ExceptionHandler.handleException(
      e,
      stackTrace: st,
      tag: _tag,
    );
    ErrorMessageService.showErrorDialog(context, exception);
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### Pattern 3: DAO Operation with Logging
```dart
Future<int> insert(Model model) async {
  try {
    final id = await db.insert('table', model.toMap());
    DaoLogger.logInsert(dao: 'MyDao', recordId: model.id);
    return id;
  } catch (e, st) {
    DaoLogger.logError(
      dao: 'MyDao',
      operation: 'insert',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}
```

---

## 🔍 Log File Access

**File Location:**
- Android/iOS: `{appDocumentsDirectory}/invoice_app/app_logs.txt`

**Access Logs Programmatically:**
```dart
// Get all logs
final allLogs = await logger.getAllLogs();

// Export logs
final file = await logger.exportLogs();

// Get statistics
final stats = await logger.getStatistics();
```

---

## ✨ Features Summary

| Feature | Component | Status |
|---------|-----------|--------|
| Centralized Logging | LoggerService | ✅ Done |
| 5 Log Levels | LoggerService | ✅ Done |
| File Persistence | LoggerService | ✅ Done |
| Performance Tracking | LoggerService | ✅ Done |
| Custom Exceptions | ExceptionHandler | ✅ Done |
| Safe Execution | ExceptionHandler | ✅ Done |
| Retry Logic | ExceptionHandler | ✅ Done |
| User-Friendly Messages | ErrorMessageService | ✅ Done |
| Error Dialogs | ErrorMessageService | ✅ Done |
| Recovery Suggestions | ErrorMessageService | ✅ Done |
| DAO Logging Patterns | DaoLogger | ✅ Done |
| Printer Service Logging | ThermalPrintingService | ✅ Done |
| Export Service Logging | ExportService | ⏳ To Do |
| UI Screen Error Handling | All Screens | ⏳ To Do |

---

## 🆘 Need Help?

For detailed documentation on each component, see:
- [LOGGING_AND_ERROR_HANDLING.md](LOGGING_AND_ERROR_HANDLING.md)

For quick examples:
- LoggerService examples: See logger_service.dart comments
- ExceptionHandler examples: See exception_handler.dart comments
- ErrorMessageService examples: See error_message_service.dart comments

