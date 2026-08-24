import 'package:shared_preferences/shared_preferences.dart';

/// Personal vs household toggle, one key per screen so they do not overwrite each other.
class BudgetTypePrefs {
  static const budget = 'isSharedBudget_budget';
  static const summary = 'isSharedBudget_summary';
  static const history = 'isSharedBudget_history';
  static const legacy = 'isSharedBudget';

  static bool read(SharedPreferences prefs, String key) {
    if (prefs.containsKey(key)) return prefs.getBool(key) ?? false;
    if (key == budget) return prefs.getBool(legacy) ?? false;
    return false;
  }

  static Future<void> write(SharedPreferences prefs, String key, bool value) {
    return prefs.setBool(key, value);
  }
}
