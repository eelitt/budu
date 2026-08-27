import 'package:budu/features/auth/domain/auth_errors.dart';
import 'package:budu/features/auth/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({
    firebase_auth.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _authOverride = auth,
        _googleSignInOverride = googleSignIn;

  final firebase_auth.FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleSignInOverride;

  firebase_auth.FirebaseAuth get _auth =>
      _authOverride ?? firebase_auth.FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInOverride ?? GoogleSignIn();

  /// Google Sign-In. Returns null when the user cancels (not an error).
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(result.user!.uid);
      }

      return UserModel(
        uid: result.user!.uid,
        email: result.user!.email!,
        user: _auth.currentUser,
      );
    } catch (e) {
      throw _asAuthFailure(AuthErrorKind.signIn, 'Google Sign-In failed', e);
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        return UserModel(uid: user.uid, email: user.email!, user: user);
      }
      return null;
    } catch (e) {
      throw _asAuthFailure(
        AuthErrorKind.currentUser,
        'Failed to get current user',
        e,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (e) {
      throw _asAuthFailure(AuthErrorKind.signOut, 'Sign out failed', e);
    }
  }

  AuthFailure _asAuthFailure(AuthErrorKind kind, String message, Object e) {
    if (e is AuthFailure) return e;
    String? code;
    if (e is firebase_auth.FirebaseAuthException) {
      code = e.code;
    }
    return AuthFailure(
      kind: kind,
      message: message,
      cause: e,
      code: code,
    );
  }
}
