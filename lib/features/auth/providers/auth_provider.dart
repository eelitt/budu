import 'package:budu/features/auth/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
  bool _isInitialized = false; // Uusi lippu alustuksen seurantaa varten

  UserModel? get user => _user;
  AuthState get authState => _authState;
  bool get isInitialized => _isInitialized;

  AuthProvider();

  Future<void> initialize() async {
    _authState = AuthState.loading;
    try {
      _user = await _authRepo.getCurrentUser();
      if (_user != null) {
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to initialize AuthProvider',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is FirebaseException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown Firebase error');
      }

      _user = null;
      _authState = AuthState.unauthenticated;
    } finally {
      _isInitialized = true;

    }
  }

  Future<void> signInWithGoogle() async {
    _authState = AuthState.loading;
 
    try {
      _user = await _authRepo.signInWithGoogle();
      print('AuthProvider: Google-kirjautuminen onnistui: ${_user?.uid}');

      if (_user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          try {
            await userDocRef.set({
              'email': _user!.email,
              'isPremium': false,
              'isAdmin': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
            print('AuthProvider: Käyttäjädokumentti luotu Firestoreen: ${_user!.uid}');
          } catch (firestoreError) {
            // Raportoidaan Firestore-virhe Crashlyticsiin
            await FirebaseCrashlytics.instance.recordError(
              firestoreError,
              StackTrace.current,
              reason: 'Failed to create user document in Firestore',
            );

            // Tunnistetaan virhetyyppi ja lisätään kontekstia
            if (firestoreError is FirebaseException) {
              await FirebaseCrashlytics.instance.setCustomKey('error_code', firestoreError.code);
              await FirebaseCrashlytics.instance.setCustomKey('error_message', firestoreError.message ?? 'Unknown Firestore error');
            }

            // Heitetään virhe eteenpäin
            throw Exception('Failed to create user document: $firestoreError');
          }
        } else {
          print('AuthProvider: Käyttäjädokumentti on jo olemassa Firestoressa: ${_user!.uid}');
        }
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      // Raportoidaan vain Firestore-virheet tässä kerroksessa, koska AuthRepository jo raportoi signInWithGoogle-virheet
      if (e.toString().contains('Failed to create user document')) {
        // Firestore-virhe on jo raportoitu, ei raportoida uudelleen
      } else {
        // Raportoidaan muut virheet Crashlyticsiin
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Google Sign-In failed in AuthProvider',
        );

        // Tunnistetaan virhetyyppi ja lisätään kontekstia
        if (e is firebase_auth.FirebaseAuthException) {
          await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
          await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown FirebaseAuth error');
        }
      }

      _user = null;
      _authState = AuthState.unauthenticated;
      print('AuthProvider: Google-kirjautumisvirhe: $e');
      rethrow;
    } 
  }

  Future<void> signOut() async {
    _authState = AuthState.loading;
    try {
      await _authRepo.signOut();
      _user = null;
      _authState = AuthState.unauthenticated;
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin, mutta vain jos se ei ole jo raportoitu AuthRepository:ssa
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Sign out failed in AuthProvider',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is firebase_auth.FirebaseAuthException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown FirebaseAuth error');
      }

      rethrow;
    } 
  }
}