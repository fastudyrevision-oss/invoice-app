import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  static PreferencesService get instance => _instance;

  PreferencesService._internal();

  static const String keyIncludeExpired = 'include_expired_in_orders';

  Future<bool> getIncludeExpiredInOrders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIncludeExpired) ??
        false; // Default to FALSE (safer) or TRUE?
    // User said "if not those... will not be added". Implies default might be ON or OFF.
    // Usually default is to NOT sell expired goods. So false is a good default.
  }

  Future<void> setIncludeExpiredInOrders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIncludeExpired, value);
  }
}
