import 'package:shared_preferences/shared_preferences.dart';

class ThrottlingService {
  static const int _dailyLimit = 1000000;
  static const String _keyPrefix = 'scan_count_';

  Future<bool> canScan() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final count = prefs.getInt(today) ?? 0;

    return count < _dailyLimit;
  }

  Future<void> incrementScan() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final count = prefs.getInt(today) ?? 0;

    await prefs.setInt(today, count + 1);
  }

  Future<int> getRemainingScans() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();
    final count = prefs.getInt(today) ?? 0;
    return _dailyLimit - count;
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '$_keyPrefix${now.year}-${now.month}-${now.day}';
  }
}
