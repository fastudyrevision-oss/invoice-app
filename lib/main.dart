import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'main_frame.dart';
import 'db/database_helper.dart';
import 'ui/settings/logs_frame.dart';
import 'services/auth_service.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/inactivity_wrapper.dart';

import 'services/logger_service.dart';

// ----------------------------------------------------------------------
// SYSTEM INITIALIZATION LOGIC (Shared)
// ----------------------------------------------------------------------

class AppSystem {
  static final _logger = LoggerService.instance;

  /// Performs all necessary system initialization.
  /// safe to call multiple times (idempotent).
  static Future<void> initialize() async {
    _logger.info('Startup', "🔄 Starting System Initialization...");

    // 1. Initialize Database
    _logger.info('Startup', "💾 Initializing Database...");

    // Android may need more time due to encryption/storage latency
    final timeoutDuration = Platform.isAndroid
        ? const Duration(seconds: 60)
        : const Duration(seconds: 15);

    await DatabaseHelper.instance.init().timeout(
      timeoutDuration,
      onTimeout: () {
        throw TimeoutException(
          'Database initialization timed out after ${timeoutDuration.inSeconds}s',
        );
      },
    );
    _logger.info('Startup', "✅ Database Ready");

    // 2. Initialize Auth Service
    _logger.info('Startup', "🔑 Initializing Auth Service...");
    try {
      await AuthService.instance.init();
      _logger.info('Startup', "✅ Auth Service Ready");
    } catch (e, st) {
      _logger.warning(
        'Startup',
        "⚠️ Auth Service init warning",
        error: e,
        context: {'stack': st.toString()},
      );
    }

    _logger.info('Startup', "✅ System Initialization Complete");
  }
}

// ----------------------------------------------------------------------
// ROOT WIDGET (Providers + App)
// ----------------------------------------------------------------------

class InvoiceAppRoot extends StatelessWidget {
  const InvoiceAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService.instance,
      child: const InvoiceApp(),
    );
  }
}

// ----------------------------------------------------------------------
// MAIN ENTRY POINT
// ----------------------------------------------------------------------

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize centralized logger immediately
      final logger = LoggerService.instance;
      await logger.initialize(
        enableConsoleLogging: true,
        enableFileLogging: true,
      );

      logger.info('Startup', "🚀 APPLICATION STARTING (Pid: $pid)");
      logger.debug('Startup', "✅ WidgetsBinding Initialized");

      // Setup Desktop FFI (Run once globally)
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          try {
            sqfliteFfiInit();
            databaseFactory = databaseFactoryFfi;
            logger.info('Startup', "✅ FFI Initialized");
          } catch (e, st) {
            logger.error(
              'Startup',
              "❌ Failed to init FFI",
              error: e,
              stackTrace: st,
            );
          }
        }
      }

      // ----------------------------------------------------------
      // 🚀 HYBRID INITIALIZATION STRATEGY
      // ----------------------------------------------------------

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // DESKTOP: Eager Initialization
        // We await initialization BEFORE runApp to ensure the app is ready immediately.
        // This avoids a splash screen flicker on fast desktop machines.
        try {
          logger.info('Startup', "🖥️ Desktop Mode: Eager Initialization");
          await AppSystem.initialize();
          runApp(const InvoiceAppRoot());
        } catch (e, stack) {
          // If eager init fails, show ErrorApp
          // Retry will switch to 'staged' mode (AppInitializer) for better UX on retry loops
          logger.critical(
            'Startup',
            "❌ Eager Init Failed",
            error: e,
            stackTrace: stack,
          );
          runApp(
            ErrorApp(
              error: e.toString(),
              stack: stack.toString(),
              onRetry: () => runApp(const AppInitializer()),
            ),
          );
        }
      } else {
        // MOBILE / WEB: Staged Initialization
        // We call runApp first (showing splash), then initialize in background.
        // Better for perceived performance on slower devices.
        logger.info('Startup', "📱 Mobile Mode: Staged Initialization");
        runApp(const AppInitializer());
      }
    },
    (error, stack) {
      LoggerService.logCrash(error, stack);
    },
  );
}

// ----------------------------------------------------------------------
// STAGED INITIALIZER WIDGET (Mobile / Recovery Mode)
// ----------------------------------------------------------------------

/// Root widget that manages the application lifecycle state:
/// - Initializing (Splash)
/// - Error (Retryable)
/// - Running (Main App)
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  // State variables to manage lifecycle
  bool _isLoading = true;
  String? _error;
  String? _stackTrace;

  @override
  void initState() {
    super.initState();
    _startInit();
  }

  Future<void> _startInit() async {
    // Reset state for retry scenarios
    setState(() {
      _isLoading = true;
      _error = null;
      _stackTrace = null;
    });

    try {
      await AppSystem.initialize();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
          _stackTrace = stack.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show Splash while Loading
    if (_isLoading) return const LauncherApp();
    // 2. Show Error if failed
    if (_error != null) {
      return ErrorApp(
        error: _error!,
        stack: _stackTrace ?? '',
        onRetry: _startInit,
      );
    }
    // 3. Show Main App if successful
    return const InvoiceAppRoot();
  }
}

// ----------------------------------------------------------------------
// UI COMPONENTS
// ----------------------------------------------------------------------

/// Simple Splash Screen shown while DB is initializing
class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                "Initializing System...",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error Screen shown if DB init fails
class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;
  final VoidCallback onRetry;

  const ErrorApp({
    super.key,
    required this.error,
    required this.stack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    "Startup Failed",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "An error occurred while initializing the system.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        "$error\n\n$stack",
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Initialization'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) => TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LogsFrame()),
                        );
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('View System Logs'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        return InactivityWrapper(
          child: MaterialApp(
            title: 'Mian Traders',
            debugShowCheckedModeBanner: false,
            // If not logged in, show LoginScreen.
            // If logged in, show MainFrame.
            // Using a key forces rebuild when auth state changes.
            key: ValueKey(auth.currentUser?.username),
            home: auth.currentUser == null
                ? const LoginScreen()
                : const MainFrame(),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
          ),
        );
      },
    );
  }
}
