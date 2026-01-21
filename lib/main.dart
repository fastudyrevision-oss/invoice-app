import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'main_frame.dart';
import 'db/database_helper.dart';
import 'services/auth_service.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/inactivity_wrapper.dart';

void main() async {
  runZonedGuarded(
    () async {
      // ----------------------------------------------------------
      // 🔍 DEBUG LOGGING SETUP
      // ----------------------------------------------------------
      // Initialize bindings first to use path_provider
      WidgetsFlutterBinding.ensureInitialized();

      // Get the proper writable directory
      File? logFile;
      // Initialize log with debugPrint immediately to make it non-nullable
      void Function(String) log = (String message) => debugPrint(message);

      try {
        final directory = await getApplicationDocumentsDirectory();
        logFile = File('${directory.path}/startup_log.txt');

        // Upgrade to file logging if possible
        log = (String message) {
          final msg = "${DateTime.now().toIso8601String()} - $message\n";
          // Using sync write to ensure it's captured before any crash
          try {
            logFile!.writeAsStringSync(msg, mode: FileMode.append);
          } catch (e) {
            debugPrint("Failed to write log: $e");
          }
          debugPrint(message);
        };

        // Clear old log
        if (logFile.existsSync()) logFile.deleteSync();
        log("🚀 APPLICATION STARTING");
        log("✅ WidgetsBinding Initialized");
      } catch (e) {
        debugPrint("❌ Failed to init logging: $e");
        // log is already initialized with debugPrint fallback
        log("⚠️ Running without file logging");
      }

      // 1. Setup Desktop FFI
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          try {
            sqfliteFfiInit();
            databaseFactory = databaseFactoryFfi;
            log("✅ FFI Initialized");
          } catch (e) {
            log("❌ Failed to init FFI: $e");
          }
        }
      }

      // 2. Launch Splash Screen
      log("🎨 Calling runApp(LauncherApp)");
      runApp(const LauncherApp());

      // 3. Initialize Heavy Resources in Background
      bool dbInitialized = false;
      try {
        log("💾 Initializing Database in background...");

        // Run database initialization with timeout
        await DatabaseHelper.instance.init().timeout(
          const Duration(seconds: 15), // Increased from 10s
          onTimeout: () {
            log("⏱️ Database initialization timed out after 15s");
            throw TimeoutException('Database initialization timeout');
          },
        );

        log("✅ Database Initialized Success");
        dbInitialized = true;
      } catch (e, stack) {
        log("❌ Database initialization failed: $e");
        log("Stack trace: ${stack.toString()}");
        // Don't crash - continue with limited functionality
        dbInitialized = false;
      }

      try {
        log("🔑 Initializing Auth Service...");
        await AuthService.instance.init();
        log("✅ Auth Service Initialized");
      } catch (e) {
        log("⚠️ Auth Service init failed: $e");
        // Continue anyway
      }

      // 4. Launch Main App (even if DB failed)
      log(
        "🚀 Launching Main App (DB Status: ${dbInitialized ? 'Ready' : 'Failed'})",
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
      debugPrint("☠️ GLOBAL UNCAUGHT ERROR: $error");
      debugPrint("Stack trace: $stack");
      // Note: We can't safely write to file here as we may not have initialized path_provider
      // The error will be visible in the debug console
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
