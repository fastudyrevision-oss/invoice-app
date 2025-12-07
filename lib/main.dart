import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
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
      final logFile = File('startup_log.txt');
      void log(String message) {
        final msg = "${DateTime.now().toIso8601String()} - $message\n";
        // Using sync write to ensure it's captured before any crash
        logFile.writeAsStringSync(msg, mode: FileMode.append);
        debugPrint(message);
      }

      // Clear old log
      if (logFile.existsSync()) logFile.deleteSync();
      log("🚀 APPLICATION STARTING");

      try {
        WidgetsFlutterBinding.ensureInitialized();
        log("✅ WidgetsBinding Initialized");
      } catch (e) {
        log("❌ Failed to init WidgetsBinding: $e");
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

      // 3. Initialize Heavy Resources
      try {
        log("💾 Initializing Database...");
        // Add a timeout to detect deadlocks
        await DatabaseHelper.instance.init().timeout(
          const Duration(seconds: 5),
        );
        log("✅ Database Initialized Success");

        log("🔑 Initializing Auth Service...");
        await AuthService.instance.init();
        log("✅ Auth Service Initialized");

        // 4. Success -> Run Main App
        log("🚀 Launching Main App");
        runApp(
          ChangeNotifierProvider(
            create: (_) => AuthService.instance,
            child: const InvoiceApp(),
          ),
        );
      } catch (e, stack) {
        log("🛑 CRITICAL ERROR: $e");
        log(stack.toString());

        runApp(ErrorApp(error: e.toString(), stack: stack.toString()));
      }
    },
    (error, stack) {
      debugPrint("Global Uncaught Error: $error");
      File('startup_log.txt').writeAsStringSync(
        "☠️ GLOBAL UNCAUGHT: $error\n$stack\n",
        mode: FileMode.append,
      );
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
