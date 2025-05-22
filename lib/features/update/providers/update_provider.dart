import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateProvider with ChangeNotifier {
  final UpdateService _updateService = UpdateService();
  bool _isUpdateAvailable = false;
  String? _latestVersion;
  String? _apkUrl;

  bool get isUpdateAvailable => _isUpdateAvailable;
  String? get latestVersion => _latestVersion;
  String? get apkUrl => _apkUrl;

  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final updateInfo = await _updateService.checkForUpdate(context);
      _isUpdateAvailable = updateInfo['isUpdateAvailable'] ?? false;
      _latestVersion = updateInfo['latestVersion'];
      _apkUrl = updateInfo['apkUrl'];

        notifyListeners();

    } catch (e) {
      print('Error in UpdateProvider.checkForUpdate: $e');
      _isUpdateAvailable = false;
      _latestVersion = null;
      _apkUrl = null;
        notifyListeners();
    }
  }

  void reset() {
    _isUpdateAvailable = false;
    _latestVersion = null;
    _apkUrl = null;
        notifyListeners();
  }
}