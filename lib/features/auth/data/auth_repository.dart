import 'package:budu/features/auth/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // Lisätty as-etuliite
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Google Sign-In
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Käyttäjä peruutti kirjautumisen, ei raportoida Crashlyticsiin (ei virhe)
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      firebase_auth.UserCredential result = await _auth.signInWithCredential(credential);

      // Asetetaan käyttäjän tunniste Crashlyticsiin kontekstia varten
      if (result.user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(result.user!.uid);
      }

      return UserModel(
        uid: result.user!.uid,
        email: result.user!.email!,
        user: _auth.currentUser,
      );
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Google Sign-In failed',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is firebase_auth.FirebaseAuthException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown FirebaseAuth error');
      }

      // Heitetään virhe kutsujalle, jotta se voidaan käsitellä (esim. näyttää SnackBar)
      rethrow;
    }
  }

  // Hae nykyinen käyttäjä
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Asetetaan käyttäjän tunniste Crashlyticsiin kontekstia varten
        await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        return UserModel(uid: user.uid, email: user.email!, user: user);
      }
      return null;
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to get current user',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is firebase_auth.FirebaseAuthException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown FirebaseAuth error');
      }

      // Palautetaan null, koska tämä metodi ei saisi kaataa sovellusta
      return null;
    }
  }

  // Kirjaudu ulos
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Kirjaa ulos Google-tililtä
      await _auth.signOut(); // Kirjaa ulos Firebase Authista

      // Nollataan Crashlyticsin käyttäjän tunniste uloskirjautumisen jälkeen
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Sign out failed',
      );

      // Tunnistetaan virhetyyppi ja lisätään kontekstia
      if (e is firebase_auth.FirebaseAuthException) {
        await FirebaseCrashlytics.instance.setCustomKey('error_code', e.code);
        await FirebaseCrashlytics.instance.setCustomKey('error_message', e.message ?? 'Unknown FirebaseAuth error');
      }

      // Heitetään virhe kutsujalle, jotta se voidaan käsitellä (esim. näyttää SnackBar)
      rethrow;
    }
  }
}