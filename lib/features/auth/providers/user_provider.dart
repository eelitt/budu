import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  bool _isAdmin = false;
  bool _isPremium = false;
  String? _sharedBudgetId; // Tulevaisuutta varten yhteistalousominaisuutta

  String? get userId => _userId;
  bool get isAdmin => _isAdmin;
  bool get isPremium => _isPremium;
  String? get sharedBudgetId => _sharedBudgetId;

  Future<void> fetchUserData(String userId) async {
    _userId = userId;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        _isAdmin = userDoc.data()?['isAdmin'] ?? false;
        _isPremium = userDoc.data()?['isPremium'] ?? false;
        _sharedBudgetId = userDoc.data()?['sharedBudgetId'];
      } else {
        _isAdmin = false;
        _isPremium = false;
        _sharedBudgetId = null;
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching user data: $e');
      _isAdmin = false;
      _isPremium = false;
      _sharedBudgetId = null;
      notifyListeners();
    }
  }

  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));

      await fetchUserData(userId); // Päivitä tiedot Firestoresta
    } catch (e) {
      print('Error updating user data: $e');
      throw e;
    }
  }

  void clearUserData() {
    _userId = null;
    _isAdmin = false;
    _isPremium = false;
    _sharedBudgetId = null;
    notifyListeners();
  }
}