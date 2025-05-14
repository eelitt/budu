import 'package:budu/features/auth/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  UserModel? _user;
  bool _isLoading = true;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    initialize();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authRepo.getCurrentUser();
    } catch (e) {
      _user = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authRepo.signInWithGoogle();
      print('AuthProvider: Google-kirjautuminen onnistui: ${_user?.uid}');

      // Tallenna isPremium-tieto Firestoreen, jos käyttäjä kirjautuu ensimmäistä kertaa
      if (_user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          // Käyttäjä kirjautuu ensimmäistä kertaa, luodaan dokumentti
          await userDocRef.set({
            'email': _user!.email,
            'isPremium': false, // Oletusarvo: ei premium-käyttäjä
            'createdAt': FieldValue.serverTimestamp(), // Tallentaa palvelimen aikaleiman
          });
          print('AuthProvider: Käyttäjädokumentti luotu Firestoreen: ${_user!.uid}');
        } else {
          print('AuthProvider: Käyttäjädokumentti on jo olemassa Firestoressa: ${_user!.uid}');
        }
      }
    } catch (e) {
      _user = null;
      print('AuthProvider: Google-kirjautumisvirhe: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepo.signOut();
      _user = null;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}