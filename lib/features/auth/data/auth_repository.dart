import 'package:budu/features/auth/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();


  // Google Sign-In
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Käyttäjä peruutti kirjautumisen

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      return UserModel(uid: result.user!.uid, email: result.user!.email!, user: _auth.currentUser);
    } catch (e) {
      rethrow;
    }
  }

 

  // Hae nykyinen käyttäjä
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return UserModel(uid: user.uid, email: user.email!, user: user);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Kirjaudu ulos
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Kirjaa ulos Google-tililtä
      await _auth.signOut(); // Kirjaa ulos Firebase Authista
    } catch (e) {
      rethrow;
    }
  }
}