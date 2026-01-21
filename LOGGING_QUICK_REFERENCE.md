# 🚀 Logging & Error Handling - Quick Reference Card

## 📋 At a Glance

| Task | Use This | Example |
|------|----------|---------|
| **Log message** | `logger.info()` | `logger.info('Service', 'Operation done')` |
| **Log with context** | `logger.info(..., context: {...})` | `logger.info('API', 'Response', context: {'status': 200})` |
| **Track performance** | `logger.startPerformanceTimer()` + `endPerformanceTimer()` | See Pattern 1 |
| **Throw error** | `throw NNN Exception(message: ...)` | `throw ValidationException(message: 'Invalid')` |
| **Catch & log error** | `ExceptionHandler.handleException()` | See Pattern 2 |
| **Show user error** | `ErrorMessageService.showError()` | `ErrorMessageService.showError(context, error)` |
| **Error dialog** | `ErrorMessageService.showErrorDialog()` | `await ErrorMessageService.showErrorDialog(context, error)` |
| **Retry logic** | `retryAsync()` | `await retryAsync(() => apiCall(), tag: 'API')` |
| **Log DAO op** | `DaoLogger.logInsert/Update/Delete()` | `DaoLogger.logInsert(dao: 'MyDao', recordId: id)` |
| **Safe execution** | `ExceptionHandler.safeExecute()` | `await ExceptionHandler.safeExecute(() => op(), tag: 'Tag')` |

---

## 🎨 Logging Examples

### Example 1: Service Operation
```dart
const _tag = '👥 CustomerService';

Future<Customer> getCustomer(String id) async {
  try {
    logger.info(_tag, 'Fetching customer: $id');
    final customer = await _dao.getById(id);
    logger.info(_tag, '✅ Customer fetched');
    return customer;
  } catch (e, st) {
    throw ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
  }
}
```

### Example 2: Performance Tracking
```dart
const _tag = '📊 ReportService';

Future<Report> generateReport() async {
  try {
    logger.startPerformanceTimer('report_generation');
    
    final data = await _fetchData();
    final report = _compile(data);
    
    logger.endPerformanceTimer('report_generation', tag: _tag);
    logger.info(_tag, 'Report generated');
    return report;
  } catch (e, st) {
    logger.error(_tag, 'Generation failed', error: e, stackTrace: st);
    rethrow;
  }
}
```

### Example 3: UI Error Handling
```dart
void _loadData() async {
  try {
    setState(() => _loading = true);
    final data = await _service.fetchData();
    setState(() => _data = data);
  } on ValidationException catch (e) {
    ErrorMessageService.showError(context, e);
  } catch (e, st) {
    final ex = ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
    await ErrorMessageService.showErrorDialog(context, ex, onRetry: _loadData);
  } finally {
    setState(() => _loading = false);
  }
}
```

### Example 4: DAO Operation
```dart
Future<int> insert(Customer customer) async {
  try {
    final id = await db.insert('customers', customer.toMap());
    DaoLogger.logInsert(dao: 'CustomerDao', recordId: customer.id);
    return id;
  } catch (e, st) {
    DaoLogger.logError(dao: 'CustomerDao', operation: 'insert', error: e, stackTrace: st);
    rethrow;
  }
}
```

### Example 5: Retry Logic
```dart
Future<List<Order>> fetchOrders() async {
  try {
    return await retryAsync(
      () => api.getOrders(),
      tag: 'OrderAPI',
      config: RetryConfig(maxAttempts: 3),
    );
  } catch (e) {
    throw NetworkException(message: 'Failed to fetch orders', originalError: e.toString());
  }
}
```

---

## 📱 Exception Types

| Exception | When to Use | Message Example |
|-----------|------------|-----------------|
| **NetworkException** | Connection/internet issues | "Network error: Failed to connect. Check internet." |
| **DatabaseException** | Database/SQL errors | "Database error during 'insert': Operation failed" |
| **ValidationException** | Invalid input data | "Invalid email: Must contain @" |
| **PrinterException** | Printer connection/operations | "Printer error: Connection timeout" |
| **FileException** | File I/O errors | "File error: Cannot save file" |
| **StorageException** | Permissions/storage issues | "Storage permission error: Grant storage access" |
| **TimeoutException** | Operation timeouts | "Operation timed out (30s). Try again." |
| **ServiceException** | API/service errors | "Service error: [HTTP 500]" |
| **AuthException** | Authentication failures | "Authentication error: Invalid credentials" |
| **UnknownException** | Unhandled errors | "An unexpected error occurred." |

---

## 🎯 Log Levels

```dart
logger.debug(_tag, 'Detailed info - only in development')     // DEBUG
logger.info(_tag, 'Important event occurred')                 // INFO
logger.warning(_tag, 'Something unexpected (no crash)')       // WARNING
logger.error(_tag, 'Error occurred', error: e)               // ERROR
logger.critical(_tag, 'System-breaking error')               // CRITICAL
```

---

## 🛠️ Common Patterns

### Pattern: Service Method
```dart
Future<T> operation() async {
  try {
    logger.info(_tag, 'Starting operation');
    final result = await _doWork();
    logger.info(_tag, '✅ Operation completed');
    return result;
  } catch (e, st) {
    throw ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
  }
}
```

### Pattern: UI Event Handler
```dart
void _onAction() async {
  try {
    setState(() => _loading = true);
    await _service.action();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Success!')),
    );
  } catch (e, st) {
    ErrorMessageService.showErrorDialog(
      context,
      ExceptionHandler.handleException(e, stackTrace: st, tag: _tag),
      onRetry: _onAction,
    );
  } finally {
    setState(() => _loading = false);
  }
}
```

### Pattern: DAO Method
```dart
Future<List<T>> getAll() async {
  try {
    final data = await db.query('table');
    DaoLogger.logQueryResult(dao: 'MyDao', operation: 'getAll', results: data);
    return data.map<T>((e) => T.fromMap(e)).toList();
  } catch (e, st) {
    DaoLogger.logError(dao: 'MyDao', operation: 'getAll', error: e, stackTrace: st);
    rethrow;
  }
}
```

---

## 🎨 Error Messages in UI

### Show Snackbar
```dart
ErrorMessageService.showError(context, exception);
```

### Show Dialog
```dart
await ErrorMessageService.showErrorDialog(context, exception);
```

### Show Error State
```dart
return ErrorStateWidget(
  error: exception,
  onRetry: _loadData,
  onDismiss: () => Navigator.pop(context),
);
```

---

## 📊 Logging Tags Format

Use format: `emoji ClassName`

```dart
static const _tag = '👥 CustomerService';
static const _tag = '📊 ReportService';
static const _tag = '💰 PaymentService';
static const _tag = '🖨️ PrinterService';
static const _tag = '📄 InvoiceService';
static const _tag = '📤 ExportService';
static const _tag = '🔐 AuthService';
static const _tag = '🌐 NetworkService';
static const _tag = '💾 DatabaseService';
static const _tag = '⚙️ ConfigService';
```

---

## 🔧 Safe Execution Wrappers

### Async Operations
```dart
final result = await ExceptionHandler.safeExecute(
  () => apiService.fetchData(),
  tag: 'API',
  fallbackValue: [],
);
```

### Sync Operations
```dart
final result = ExceptionHandler.safeExecuteSync(
  () => parseData(json),
  tag: 'Parser',
  fallbackValue: null,
);
```

### Try-Execute
```dart
final result = ExceptionHandler.tryExecute(
  () => riskyOperation(),
  tag: 'RiskyOp',
);
```

---

## 📝 Log Output Examples

```
2024-01-15 10:30:45 [INFO] 👥 CustomerService: Fetching customer: CUST-001
2024-01-15 10:30:46 [INFO] 👥 CustomerService: ✅ Customer fetched
2024-01-15 10:30:47 [PERF] 👥 CustomerService: getCustomer took 2150ms

2024-01-15 10:31:00 [ERROR] 🌐 NetworkService: Connection failed
2024-01-15 10:31:00 [ERROR] 🌐 NetworkService: SocketException: Connection refused

2024-01-15 10:32:10 [WARNING] 📊 ReportService: Report generation took longer than expected (45000ms)
2024-01-15 10:32:15 [CRITICAL] 💾 DatabaseService: Database connection lost!
```

---

## 🚀 Integration Checklist

- [ ] Import logger_service in your service
- [ ] Import exception_handler and error_message_service in UI
- [ ] Import dao_logger in DAO classes
- [ ] Add try-catch blocks to all operations
- [ ] Use appropriate exception types
- [ ] Call `logger.info()` for significant events
- [ ] Use `ErrorMessageService.showError()` in UI
- [ ] Add performance tracking for long operations
- [ ] Include context in important log entries
- [ ] Test error scenarios manually

---

## 📚 Reference Files

- **Complete Docs:** `LOGGING_AND_ERROR_HANDLING.md`
- **Quick Guide:** `LOGGING_IMPLEMENTATION_GUIDE.md`
- **Delivery Summary:** `LOGGING_DELIVERY_SUMMARY.md`
- **Logger Code:** `lib/services/logger_service.dart`
- **Exceptions Code:** `lib/services/exception_handler.dart`
- **Messages Code:** `lib/services/error_message_service.dart`
- **DAO Patterns:** `lib/services/dao_logger.dart`

---

## ⚡ Quick Copy-Paste Templates

### Service Template
```dart
import 'services/logger_service.dart';
import 'services/exception_handler.dart';

class MyService {
  static const String _tag = '🔷 MyService';

  Future<T> operation() async {
    try {
      logger.info(_tag, 'Starting operation');
      // TODO: Do work
      logger.info(_tag, '✅ Operation completed');
    } catch (e, st) {
      throw ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
    }
  }
}
```

### UI Template
```dart
void _onAction() async {
  try {
    setState(() => _loading = true);
    // TODO: Do work
  } catch (e, st) {
    final ex = ExceptionHandler.handleException(e, stackTrace: st, tag: _tag);
    ErrorMessageService.showErrorDialog(context, ex, onRetry: _onAction);
  } finally {
    setState(() => _loading = false);
  }
}
```

### DAO Template
```dart
Future<int> insert(Model model) async {
  try {
    final id = await db.insert('table', model.toMap());
    DaoLogger.logInsert(dao: 'MyDao', recordId: model.id);
    return id;
  } catch (e, st) {
    DaoLogger.logError(dao: 'MyDao', operation: 'insert', error: e, stackTrace: st);
    rethrow;
  }
}
```

---

**That's it! You're ready to add comprehensive logging to your app.** 🚀

