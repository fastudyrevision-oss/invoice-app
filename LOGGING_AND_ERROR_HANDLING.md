# 📋 Logging, Error Handling & User Messages Documentation

## Overview

This document describes the comprehensive logging, exception handling, and error messaging system implemented throughout the Invoice App. This system provides:

- **Centralized Logging**: Single point for all app logging with 5 severity levels
- **Exception Handling**: Custom exception classes for different error scenarios
- **User-Friendly Messages**: Non-technical error messages for end users
- **Recovery Guidance**: Suggestions to help users resolve issues
- **Performance Tracking**: Monitor operation durations
- **Error Analytics**: Collect and export error statistics

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Code                         │
│  (DAOs, Services, UI Screens, Business Logic)               │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┬──────────────┬──────────────┐
        │                     │              │              │
   ┌────▼────┐         ┌─────▼──────┐  ┌────▼────┐  ┌─────▼──────┐
   │ExceptionHandler│   │DaoLogger   │  │Services │  │UI Handlers │
   └────┬────┘         └─────┬──────┘  └────┬────┘  └─────┬──────┘
        │                     │              │              │
        └──────────────────┬──┴──────────────┴──────────────┘
                           │
                    ┌──────▼────────┐
                    │LoggerService  │
                    │  (Singleton)  │
                    └──────┬────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌───▼──┐        ┌─────▼────┐        ┌───▼──────┐
    │Console│        │Log Files │        │Statistics│
    │Logs   │        │ (Device) │        │ & Export │
    └───────┘        └──────────┘        └──────────┘
```

---

## 🔧 Core Components

### 1. LoggerService (`lib/services/logger_service.dart`)

**Purpose**: Centralized logging with persistence and performance tracking

**Features**:
- 5 Log Levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`
- File logging (app_logs.txt)
- Console logging during development
- Performance monitoring with timers
- Log retrieval and statistics
- Context capture for debugging
- Log cleanup (auto-rotate old logs)

**Usage**:
```dart
import 'services/logger_service.dart';

final logger = LoggerService.instance;

// Basic logging
logger.debug('PaymentService', 'Processing payment');
logger.info('PaymentService', 'Payment successful');
logger.warning('PaymentService', 'Low balance detected');
logger.error('PaymentService', 'Payment failed', error: exception);
logger.critical('PaymentService', 'Database connection lost');

// With context
logger.info('InvoiceService', 'Creating invoice', context: {
  'customerId': 'CUST-001',
  'amount': 5000,
  'items': 5,
});

// Performance tracking
logger.startPerformanceTimer('invoice_generation');
// ... do work ...
logger.endPerformanceTimer('invoice_generation', tag: 'InvoiceService');

// Retrieve logs
final allLogs = await logger.getAllLogs();
final stats = await logger.getStatistics();
```

**Key Methods**:
- `initialize()`: Initialize logger (called at app startup)
- `debug()`, `info()`, `warning()`, `error()`, `critical()`: Log messages
- `startPerformanceTimer()`, `endPerformanceTimer()`: Track operation duration
- `getAllLogs()`: Retrieve all logs
- `getStatistics()`: Get log statistics
- `exportLogs()`: Export logs to file
- `clearLogs()`: Clear all logs

---

### 2. Exception Handler (`lib/services/exception_handler.dart`)

**Purpose**: Unified exception handling with automatic logging

**Exception Types**:

```
AppException (Base)
├── NetworkException         - Connection, timeout issues
├── DatabaseException        - SQL, database operations
├── ValidationException      - Input validation failures
├── PrinterException         - Printer connection/operations
├── FileException            - File I/O operations
├── StorageException         - Permission/storage issues
├── TimeoutException         - Operation timeouts
├── ServiceException         - API/service failures
├── AuthException            - Authentication issues
└── UnknownException         - Unhandled errors
```

**Each exception provides**:
- User-friendly message (via `getUserMessage()`)
- Original error details
- Stack trace for debugging
- Context information
- Automatic logging

**Usage**:
```dart
import 'services/exception_handler.dart';

// Custom exceptions
try {
  await fetchCustomerData();
} catch (e) {
  throw NetworkException(
    message: 'Failed to fetch customer',
    originalError: e.toString(),
    context: {'customerId': '123'},
  );
}

// Exception handler utilities
try {
  final result = await ExceptionHandler.safeExecute<List<Customer>>(
    () => customerDao.getAllCustomers(),
    tag: 'CustomerService',
  );
} catch (e) {
  // Error logged automatically
}

// Sync operations
final result = ExceptionHandler.safeExecuteSync(
  () => parseCustomerData(jsonData),
  tag: 'DataParser',
  fallbackValue: [],
);

// Retry logic
try {
  await retryAsync(
    () => apiService.fetchData(),
    tag: 'API',
    config: RetryConfig(
      maxAttempts: 3,
      delay: Duration(seconds: 1),
    ),
  );
} catch (e) {
  // All retries failed
}
```

**Retry Configuration**:
```dart
RetryConfig(
  maxAttempts: 3,              // Number of retry attempts
  delay: Duration(milliseconds: 500), // Delay between retries
  maxDuration: Duration(minutes: 5),  // Max total duration
  retryOnTimeout: true,         // Retry on timeout
)
```

---

### 3. Error Message Service (`lib/services/error_message_service.dart`)

**Purpose**: Generate user-friendly error messages and recovery guidance

**Main Features**:

1. **ErrorMessageService**
   - Generate user-friendly messages from exceptions
   - Get error titles and icons
   - Show error snackbars
   - Show error dialogs

2. **ErrorRecoveryService**
   - Get recovery suggestions for each error type
   - Provide actionable steps for users

3. **ErrorStateWidget**
   - Display error with recovery options
   - Show suggestions inline
   - Provide retry/dismiss actions

**Usage**:
```dart
import 'services/error_message_service.dart';

// Get user message
final message = ErrorMessageService.getMessage(exception);
// e.g., "Network error: Failed to fetch. Please check internet."

// Show error snackbar
ErrorMessageService.showError(
  context,
  exception,
  duration: Duration(seconds: 5),
  onRetry: () { /* retry logic */ },
);

// Show error dialog
await ErrorMessageService.showErrorDialog(
  context,
  exception,
  onRetry: () { /* retry logic */ },
  retryLabel: 'Try Again',
);

// Get recovery suggestions
final suggestions = ErrorRecoveryService.getSuggestions(exception);
for (var suggestion in suggestions) {
  print('${suggestion.title}: ${suggestion.description}');
}

// Use error state widget
return ErrorStateWidget(
  error: exception,
  onRetry: () { /* retry */ },
  onDismiss: () { /* dismiss */ },
);
```

**Error Message Examples**:
```
NetworkException
  → "Network error: Failed to connect. Please check your internet connection."

DatabaseException
  → "Database error during 'insert': Operation failed"

ValidationException
  → "Invalid email: Email must contain @"

PrinterException
  → "Printer error (192.168.1.100:9100): Connection timeout. Please check printer."

FileException
  → "File error (invoice.pdf): Cannot save file"

StorageException
  → "Storage permission error: Please grant storage permission"

TimeoutException
  → "Operation timed out (30s). Please try again"
```

---

### 4. DAO Logger (`lib/services/dao_logger.dart`)

**Purpose**: Consistent logging for database operations

**Features**:
- Log CRUD operations
- Track affected rows
- Log batch operations
- Capture operation metadata
- Error logging for failures

**Usage**:
```dart
import 'services/dao_logger.dart';

// In DAO methods
try {
  final id = await db.insert("customers", customer.toMap());
  DaoLogger.logInsert(
    dao: 'CustomerDao',
    recordId: customer.id,
    data: customer.toMap(),
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

// Safe DAO operation wrapper
final customers = await safeDaoOperation(
  operation: () => db.query('customers'),
  dao: 'CustomerDao',
  operationName: 'fetch all customers',
);
```

---

## 🚀 Implementation Guidelines

### For DAO Classes

1. Add logging to all CRUD operations:
```dart
Future<int> insertCustomer(Customer customer) async {
  try {
    final id = await db.insert("customers", customer.toMap());
    DaoLogger.logInsert(
      dao: 'CustomerDao',
      recordId: customer.id ?? 'new',
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
```

2. Log complex queries:
```dart
Future<List<Customer>> getCustomersPage({...}) async {
  try {
    final data = await db.query("customers", ...);
    DaoLogger.logQueryResult(
      dao: 'CustomerDao',
      operation: 'getCustomersPage',
      results: data,
    );
    return data.map<Customer>((e) => Customer.fromMap(e)).toList();
  } catch (e, st) {
    DaoLogger.logError(
      dao: 'CustomerDao',
      operation: 'getCustomersPage',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}
```

### For Services

1. Wrap operations with try-catch:
```dart
Future<void> processPayment(Payment payment) async {
  final tag = '💳 PaymentService';
  try {
    logger.info(tag, 'Processing payment: ${payment.id}');
    logger.startPerformanceTimer('process_payment');
    
    // Validate
    if (payment.amount <= 0) {
      throw ValidationException(
        message: 'Amount must be greater than 0',
        field: 'amount',
        invalidValue: payment.amount,
      );
    }
    
    // Process
    await api.processPayment(payment);
    
    logger.endPerformanceTimer('process_payment', tag: tag);
    logger.info(tag, 'Payment processed successfully');
  } catch (e, st) {
    logger.error(tag, 'Payment processing failed', error: e, stackTrace: st);
    throw ExceptionHandler.handleException(e, stackTrace: st, tag: tag);
  }
}
```

2. Use safe execution wrappers:
```dart
final customers = await ExceptionHandler.safeExecute(
  () => customerDao.getAllCustomers(),
  tag: 'CustomerService',
);
```

### For UI Screens

1. Handle errors in event handlers:
```dart
void _onCreateInvoice() async {
  final tag = '📄 InvoiceScreen';
  try {
    logger.info(tag, 'User initiated invoice creation');
    
    setState(() => _isLoading = true);
    
    final invoice = await _invoiceService.createInvoice(
      customers: _selectedCustomers,
      items: _items,
    );
    
    logger.info(tag, 'Invoice created: ${invoice.id}');
    
    ErrorMessageService.showError(
      context,
      'Invoice created successfully!',
    );
  } on ValidationException catch (e) {
    e.log(tag);
    ErrorMessageService.showError(context, e);
  } catch (e, st) {
    final exception = ExceptionHandler.handleException(
      e,
      stackTrace: st,
      tag: tag,
    );
    ErrorMessageService.showErrorDialog(
      context,
      exception,
      onRetry: _onCreateInvoice,
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

2. Display error states:
```dart
@override
Widget build(BuildContext context) {
  if (_hasError) {
    return ErrorStateWidget(
      error: _error,
      onRetry: _loadData,
      onDismiss: () => Navigator.pop(context),
    );
  }
  
  if (_isLoading) {
    return const Center(child: CircularProgressIndicator());
  }
  
  return _buildContent();
}
```

---

## 📱 Printer Service Logging

Add logging to thermal printer operations:

```dart
Future<void> connectPrinter(String ip, int port) async {
  final tag = '🖨️ ThermalPrintingService';
  try {
    logger.info(tag, 'Connecting to printer: $ip:$port');
    logger.startPerformanceTimer('printer_connection');
    
    // Connection code
    await _connect(ip, port);
    
    logger.endPerformanceTimer('printer_connection', tag: tag);
    logger.info(tag, '✅ Connected to printer successfully');
  } catch (e, st) {
    logger.endPerformanceTimer('printer_connection', tag: tag);
    throw PrinterException(
      message: 'Failed to connect to printer',
      printerAddress: ip,
      printerPort: port,
      originalError: e.toString(),
      stackTrace: st,
    );
  }
}
```

---

## 📤 Export Service Logging

Add logging to PDF generation and export:

```dart
Future<File> generatePDF(Invoice invoice) async {
  final tag = '📤 ExportService';
  try {
    logger.info(tag, 'Generating PDF for invoice: ${invoice.id}');
    logger.startPerformanceTimer('pdf_generation');
    
    // Generation code
    final file = await _generatePDF(invoice);
    
    logger.endPerformanceTimer('pdf_generation', tag: tag);
    logger.info(
      tag,
      '✅ PDF generated: ${file.path}',
      context: {'fileSize': file.lengthSync()},
    );
    return file;
  } catch (e, st) {
    logger.error(tag, 'PDF generation failed', error: e, stackTrace: st);
    throw FileException(
      message: 'Failed to generate PDF',
      filename: '${invoice.id}.pdf',
      originalError: e.toString(),
      stackTrace: st,
    );
  }
}
```

---

## 📊 Log Management

### Accessing Logs

```dart
// Get all logs
final allLogs = await logger.getAllLogs();
for (var entry in allLogs) {
  print('${entry.timestamp} [${entry.level}] ${entry.tag}: ${entry.message}');
}

// Get statistics
final stats = await logger.getStatistics();
print('Total logs: ${stats['total']}');
print('Errors: ${stats['error']}');
print('Warnings: ${stats['warning']}');

// Export logs
final file = await logger.exportLogs();
print('Logs exported to: ${file.path}');

// Clear old logs (auto-run on startup)
await logger.clearLogs();
```

### Log File Location

- **Android**: `{appDocumentsDirectory}/invoice_app/app_logs.txt`
- **iOS**: `{appDocumentsDirectory}/invoice_app/app_logs.txt`
- **Web**: Stored in localStorage (browser-dependent)

### Log Rotation

Logs are automatically rotated when they exceed 5MB. Old logs are compressed and stored as `app_logs.txt.{n}`.

---

## 🎯 Error Types Reference

| Exception Type | When to Use | Example Message |
|---|---|---|
| **NetworkException** | Connection failures, network timeouts | "Network error: Failed to connect..." |
| **DatabaseException** | SQL errors, transaction failures | "Database error during 'insert'..." |
| **ValidationException** | Invalid input data | "Invalid email: Email must contain @" |
| **PrinterException** | Printer connection/operation failures | "Printer error (IP:Port): Connection timeout" |
| **FileException** | File I/O failures | "File error (filename.pdf): Cannot save" |
| **StorageException** | Permission or storage issues | "Storage permission error: Please grant..." |
| **TimeoutException** | Operation timeout | "Operation timed out (30s)..." |
| **ServiceException** | API/service errors | "Service error (PaymentAPI): [HTTP 500]" |
| **AuthException** | Authentication failures | "Authentication error: Invalid credentials" |
| **UnknownException** | Unexpected errors | "An unexpected error occurred..." |

---

## 🧪 Testing Error Handling

### Manual Testing

1. **Test NetworkException**:
   - Disable internet and try to load customer data
   - Should show: "Network error: Failed to connect. Please check your internet connection."

2. **Test ValidationException**:
   - Try to create invoice with empty name
   - Should show: "Invalid customer name: Name cannot be empty"

3. **Test PrinterException**:
   - Disconnect printer and try to print
   - Should show: "Printer error: Connection timeout..."

4. **Test FileException**:
   - Try to export without write permission
   - Should show: "File error: Cannot save file"

### Automated Testing

```dart
test('handles network exception', () async {
  try {
    throw NetworkException(
      message: 'Connection refused',
    );
  } catch (e) {
    expect(
      e.getUserMessage(),
      contains('check your internet connection'),
    );
  }
});

test('handles validation exception', () async {
  try {
    throw ValidationException(
      message: 'Invalid email',
      field: 'email',
    );
  } catch (e) {
    expect(e.getUserMessage(), contains('Invalid email'));
  }
});
```

---

## 🔒 Best Practices

1. **Always log operations**: Every significant operation should have entry and exit logs
2. **Include context**: Add relevant data to help debugging
3. **Use appropriate levels**:
   - `DEBUG`: Detailed flow information
   - `INFO`: Significant events (successful operations)
   - `WARNING`: Unexpected situations (no crash)
   - `ERROR`: Errors with recovery
   - `CRITICAL`: System-breaking errors

4. **Never log sensitive data**:
   ```dart
   // ❌ BAD
   logger.info('Login', 'User logged in', context: {
     'username': email,
     'password': password, // NEVER!
   });
   
   // ✅ GOOD
   logger.info('Login', 'User logged in', context: {
     'userId': user.id,
     'loginTime': DateTime.now(),
   });
   ```

5. **Clean up logs regularly**: Logs are auto-cleaned on startup
6. **Use tags consistently**: Use format `emoji ClassName` for easy filtering

---

## 📚 Summary

This comprehensive logging and error handling system provides:

- ✅ Centralized logging with persistence
- ✅ Custom exception types for different scenarios
- ✅ User-friendly error messages
- ✅ Recovery suggestions
- ✅ Performance monitoring
- ✅ Easy debugging with context capture
- ✅ Error analytics and export

All components are integrated and ready for use throughout the app!

