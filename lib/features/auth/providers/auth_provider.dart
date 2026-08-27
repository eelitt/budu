import 'package:budu/features/auth/models/user_model.dart';
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import '../data/user_profile_repository.dart';

enum AuthState {
  unauthenticated,
  authenticated,
  loading,
}

class AuthProvider with ChangeNotifier {
  AuthProvider({
    AuthRepository? authRepository,
    UserProfileRepository? userProfileRepository,
  })  : _authRepo = authRepository ?? AuthRepository(),
        _userProfiles = userProfileRepository ?? UserProfileRepository();

  final AuthRepository _authRepo;
  final UserProfileRepository _userProfiles;
  UserModel? _user;
  AuthState _authState = AuthState.unauthenticated;
  bool _isInitialized = false;

  UserModel? get user => _user;
  AuthState get authState => _authState;
  bool get isInitialized => _isInitialized;

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
      rethrow;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      _user = await _authRepo.signInWithGoogle();

      if (_user != null) {
        await _userProfiles.ensureUserDocument(
          uid: _user!.uid,
          email: _user!.email,
        );
        _authState = AuthState.authenticated;
      } else {
        _authState = AuthState.unauthenticated;
      }
      notifyListeners();
    } catch (e) {
      _user = null;
      _authState = AuthState.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _authState = AuthState.loading;
    notifyListeners();
    await _authRepo.signOut();
    _user = null;
    _authState = AuthState.unauthenticated;
    notifyListeners();
  }
}
