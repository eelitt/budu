import 'package:shared_preferences/shared_preferences.dart';

class DeleteDialogStateManager {
  Future<bool> shouldShowDeleteDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('showDeleteCategoryDialog') ?? true;
  }

  Future<void> setShowDeleteDialog(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showDeleteCategoryDialog', show);
  }
}