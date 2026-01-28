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

void main() async {
  runZonedGuarded(
    () async {
      // ----------------------------------------------------------
      // 🔍 DEBUG LOGGING SETUP
      // ----------------------------------------------------------
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize centralized logger
      final logger = LoggerService.instance;
      await logger.initialize(
        enableConsoleLogging: true,
        enableFileLogging: true,
      );

      logger.info('Startup', "🚀 APPLICATION STARTING");
      logger.debug('Startup', "✅ WidgetsBinding Initialized");

      // 1. Setup Desktop FFI
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

      // 2. Launch Splash Screen
      logger.debug('Startup', "🎨 Calling runApp(LauncherApp)");
      runApp(const LauncherApp());

      // 3. Initialize Heavy Resources in Background
      bool dbInitialized = false;
      try {
        logger.info('Startup', "💾 Initializing Database in background...");

        // Run database initialization with timeout
        await DatabaseHelper.instance.init().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            logger.error(
              'Startup',
              "⏱️ Database initialization timed out after 15s",
            );
            throw TimeoutException('Database initialization timeout');
          },
        );

        logger.info('Startup', "✅ Database Initialized Success");
        dbInitialized = true;
      } catch (e, stack) {
        logger.critical(
          'Startup',
          "❌ Database initialization failed",
          error: e,
          stackTrace: stack,
        );
        // Don't crash - continue with limited functionality
        dbInitialized = false;
      }

      try {
        logger.info('Startup', "🔑 Initializing Auth Service...");
        await AuthService.instance.init();
        logger.info('Startup', "✅ Auth Service Initialized");
      } catch (e, st) {
        logger.warning(
          'Startup',
          "⚠️ Auth Service init failed",
          error: e,
          context: {'stack': st.toString()},
        );
        // Continue anyway
      }

      // 4. Launch Main App (even if DB failed)
      logger.info(
        'Startup',
        "🚀 Launching Main App",
        context: {'dbStatus': dbInitialized ? 'Ready' : 'Failed'},
      );

      if (!dbInitialized) {
        // Show error app with option to retry
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Database Initialization Failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'The app cannot start because the database failed to initialize.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Restart the app
                          main();
                        },
                        icon: Icon(Icons.refresh),
                        label: Text('Retry'),
                      ),
                      SizedBox(height: 16),
                      Builder(
                        builder: (context) => TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LogsFrame(),
                              ),
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
        return;
      }

      runApp(
        ChangeNotifierProvider(
          create: (_) => AuthService.instance,
          child: const InvoiceApp(),
        ),
      );
    },
    (error, stack) {
      // Use the static crash logger we implemented
      LoggerService.logCrash(error, stack);
    },
  );
}

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

  const ErrorApp({super.key, required this.error, required this.stack});

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
                    "An error occurred while initializing the database.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$error\n\n$stack",
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                      ),
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
            title: 'Invoice App',
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
