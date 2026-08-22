import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  UserProvider({UserProfileRepository? profiles})
      : _profiles = profiles ?? UserProfileRepository();

  final UserProfileRepository _profiles;
  String? _userId;
  bool _isAdmin = false;
  bool _isPremium = false;
  String? _sharedBudgetId;

  String? get userId => _userId;
  bool get isAdmin => _isAdmin;
  bool get isPremium => _isPremium;
  String? get sharedBudgetId => _sharedBudgetId;

  Future<void> fetchUserData(String userId) async {
    _userId = userId;
    try {
      final profile = await _profiles.getProfile(userId);
      _isAdmin = profile?.isAdmin ?? false;
      _isPremium = profile?.isPremium ?? false;
      _sharedBudgetId = profile?.sharedBudgetId;
      notifyListeners();
    } catch (_) {
      _isAdmin = false;
      _isPremium = false;
      _sharedBudgetId = null;
    }
  }

  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    await _profiles.mergeProfile(userId, data);
    await fetchUserData(userId);
  }

  void clearUserData() {
    _userId = null;
    _isAdmin = false;
    _isPremium = false;
    _sharedBudgetId = null;
    notifyListeners();
  }
}
