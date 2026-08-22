import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class UserProfile {
  final String uid;
  final String? email;
  final bool isAdmin;
  final bool isPremium;
  final String? sharedBudgetId;

  const UserProfile({
    required this.uid,
    this.email,
    this.isAdmin = false,
    this.isPremium = false,
    this.sharedBudgetId,
  });
}

/// Firestore `users/{uid}` — not Google sign-in (that's [AuthRepository]).
class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final snap = await _doc(uid).get();
      if (!snap.exists) return null;
      final data = snap.data() ?? {};
      return UserProfile(
        uid: uid,
        email: data['email'] as String?,
        isAdmin: data['isAdmin'] as bool? ?? false,
        isPremium: data['isPremium'] as bool? ?? false,
        sharedBudgetId: data['sharedBudgetId'] as String?,
      );
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to get user profile $uid',
      );
      rethrow;
    }
  }

  /// Creates `users/{uid}` if missing. Existing docs are left unchanged.
  Future<void> ensureUserDocument({
    required String uid,
    required String email,
  }) async {
    try {
      final snap = await _doc(uid).get();
      if (snap.exists) return;
      await _doc(uid).set({
        'email': email,
        'isPremium': false,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to create user document $uid',
      );
      throw Exception('Failed to create user document: $e');
    }
  }

  Future<void> mergeProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _doc(uid).set(data, SetOptions(merge: true));
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to update user profile $uid',
      );
      rethrow;
    }
  }
}
