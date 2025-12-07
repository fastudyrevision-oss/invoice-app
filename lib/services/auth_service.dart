import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._privateConstructor();
  AuthService._privateConstructor();

  final UserRepository _userRepo = UserRepository();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isDeveloper => _currentUser?.isDeveloper ?? false;

  Timer? _inactivityTimer;
  // Auto-logout after 10 minutes of inactivity
  static const Duration _inactivityDuration = Duration(minutes: 10);

  // Initialize: Ensure admin exists
  Future<void> init() async {
    await _userRepo.ensureAdminExists();
  }

  /// Returns true if login successful
  Future<bool> login(String username, String password) async {
    try {
      final user = await _userRepo.getUserByUsername(username);
      if (user != null && user.passwordHash == password) {
        _currentUser = user;
        _startInactivityTimer();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print("Login error: $e");
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _cancelInactivityTimer();
    notifyListeners();
  }

  bool canAccess(String feature) {
    if (_currentUser == null) return false;
    if (_currentUser!.isDeveloper) return true;
    if (_currentUser!.permissions.contains('all')) return true;
    return _currentUser!.permissions.contains(feature);
  }

  // --- Inactivity Monitoring ---

  void _startInactivityTimer() {
    _cancelInactivityTimer();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (_currentUser != null) {
        logout(); // Auto logout
      }
    });
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Call this whenever user interacts with the app
  void userInteracted() {
    if (_currentUser != null) {
      _startInactivityTimer();
    }
  }
}
