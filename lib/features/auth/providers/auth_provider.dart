import 'package:budu/features/auth/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';

enum AuthState {
  unauthenticated,
  authenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  UserModel? _user;
  AuthState _authState = AuthState.unauthenticated;

  UserModel? get user => _user;
  AuthState get authState => _authState;

  AuthProvider() {
    initialize();
  }

  Future<void> initialize() async {
    _authState = AuthState.loading;
    notifyListeners();
    try {
      _user = await _authRepo.getCurrentUser();
      if (_user != null) {
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _user = null;
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _authState = AuthState.loading;
    notifyListeners();
    try {
      _user = await _authRepo.signInWithGoogle();
      print('AuthProvider: Google-kirjautuminen onnistui: ${_user?.uid}');

      if (_user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          await userDocRef.set({
            'email': _user!.email,
            'isPremium': false,
            'isAdmin': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('AuthProvider: Käyttäjädokumentti luotu Firestoreen: ${_user!.uid}');
        } else {
          print('AuthProvider: Käyttäjädokumentti on jo olemassa Firestoressa: ${_user!.uid}');
        }
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _user = null;
      _authState = AuthState.unauthenticated;
      print('AuthProvider: Google-kirjautumisvirhe: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _authState = AuthState.loading;
    notifyListeners();
    try {
      await _authRepo.signOut();
      _user = null;
      _authState = AuthState.unauthenticated;
    } catch (e) {
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}