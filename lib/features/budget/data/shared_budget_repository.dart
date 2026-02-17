import 'package:budu/features/budget/models/budget_model.dart'; // Päivitetty: Käytetään yhdistettyä BudgetModel:ia SharedBudget:in sijaan
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:uuid/uuid.dart';

/// Repositorio yhteistalousbudjettien ja kutsujen hallintaan Firestoressa.
/// Kaikki Firestore-operaatiot keskitetty tänne optimoinnin ja modulaarisuuden vuoksi.
/// Käyttää batch-write:eja monioperaatioissa kulujen vähentämiseksi.
/// Päivitetty: Käytetään BudgetModel:ia kaikille budjeteille (sisältää shared-kentät optionalina).
class SharedBudgetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hakee käyttäjän yhteistalousbudjetit (query optimoitu limit:llä).
  Future<List<BudgetModel>> getSharedBudgets(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('shared_budgets')
          .where('users', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => BudgetModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to fetch shared budgets for user $userId',
      );
      rethrow;
    }
  }

  /// Palauttaa reaaliaikaisen streamin käyttäjän yhteistalousbudjeteista (optimoitu limit:llä).
  Stream<List<BudgetModel>> sharedBudgetsStream(String userId) {
    return _firestore
        .collection('shared_budgets')
        .where('users', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BudgetModel.fromMap(doc.data(),doc.id)).toList())
        .handleError((e, stackTrace) async {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to stream shared budgets for user $userId',
      );
    });
  }

  /// Hakee odottavat kutsut käyttäjän sähköpostilla (query optimoitu limit:llä).
  Future<List<Invitation>> getPendingInvitations(String email) async {
    try {
      final String normalizedEmail = email.trim().toLowerCase();
      final snapshot = await _firestore
          .collection('invitations')
          .where('inviteeEmail', isEqualTo: normalizedEmail)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      return snapshot.docs.map((doc) => Invitation.fromMap(doc.data(), doc.id)).toList();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to fetch pending invitations for email $email',
      );
      rethrow;
    }
  }

  /// Palauttaa reaaliaikaisen streamin odottavista kutsuista (optimoitu limit:llä).
  Stream<List<Invitation>> pendingInvitationsStream(String email) {
    return _firestore
        .collection('invitations')
        .where('inviteeEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Invitation.fromMap(doc.data(), doc.id)).toList())
        .handleError((e, stackTrace) async {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to stream pending invitations for email $email',
      );
    });
  }

  /// Luo uuden yhteistalousbudjetin.
  Future<void> createSharedBudget({
    required String sharedBudgetId,
    required String userId,
    required String name,
    required double income,
    required Map<String, Map<String, double>> expenses,
    required DateTime startDate,
    required DateTime endDate,
    required String type,
    bool isPlaceholder = false,
  }) async {
    try {
      final sharedBudget = BudgetModel( // Päivitetty: Käytetään BudgetModel:ia, aseta shared-kentät
        income: income,
        expenses: expenses,
        createdAt: DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        type: type,
        isPlaceholder: isPlaceholder,
        id: sharedBudgetId,
        sharedBudgetId: sharedBudgetId, // Linkki itseensä shared-tapauksessa
        users: [userId],
        createdBy: userId,
        name: name,
      );
      print('SharedBudgetRepository: Luodaan yhteistalousbudjetti, sharedBudgetId: $sharedBudgetId, data: ${sharedBudget.toMap()}');
      await _firestore.collection('shared_budgets').doc(sharedBudgetId).set(sharedBudget.toMap());
      await FirebaseCrashlytics.instance.log('SharedBudgetRepository: Yhteistalousbudjetti luotu, ID: $sharedBudgetId');
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to create shared budget for user $userId',
      );
      rethrow;
    }
  }

  /// Luo uuden kutsun olemassa olevalle yhteistalousbudjetille.
  Future<String> createInvitationForExistingBudget({
    required String sharedBudgetId,
    required String inviterId,
    required String inviteeEmail,
  }) async {
    try {
      final invitationId = const Uuid().v4();
      final invitation = Invitation(
        id: invitationId,
        sharedBudgetId: sharedBudgetId,
        inviterId: inviterId,
        inviteeEmail: inviteeEmail,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      print('SharedBudgetRepository: Luodaan kutsu, invitationId: $invitationId, sharedBudgetId: $sharedBudgetId, data: ${invitation.toMap()}');
      await _firestore.collection('invitations').doc(invitationId).set(invitation.toMap());
      await FirebaseCrashlytics.instance.log('SharedBudgetRepository: Kutsu luotu, ID: $invitationId, sharedBudgetId: $sharedBudgetId');
      return invitationId;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to create invitation for sharedBudgetId $sharedBudgetId',
      );
      rethrow;
    }
  }

  /// Atomically accept an invitation:
  /// - Marks invitation as 'accepted'
  /// - Adds user UID to the shared budget's 'users' array
  Future<void> acceptInvitation({
    required String invitationId,
    required String sharedBudgetId,
    required String userId,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final invitationRef = FirebaseFirestore.instance
            .collection('invitations')
            .doc(invitationId);
        final budgetRef = FirebaseFirestore.instance
            .collection('shared_budgets')
            .doc(sharedBudgetId);

        transaction.update(invitationRef, {'status': 'accepted'});
        transaction.update(budgetRef, {
          'users': FieldValue.arrayUnion([userId]),
        });
      });
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'SharedBudgetRepository: Failed to accept invitation $invitationId',
      );
      rethrow;
    }
  }

/// Decline an invitation (simple status update)
  Future<void> declineInvitation(String invitationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('invitations')
          .doc(invitationId)
          .update({'status': 'declined'});
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'SharedBudgetRepository: Failed to decline invitation $invitationId',
      );
      rethrow;
    }
  }

  /// Päivittää yhteistalousbudjetin tiedot.
  Future<void> updateSharedBudget({
    required String sharedBudgetId,
    required double income,
    required Map<String, Map<String, double>> expenses,
    required DateTime startDate,
    required DateTime endDate,
    required String type,
    bool isPlaceholder = false,
  }) async {
    try {
      final updates = {
        'income': income,
        'expenses': expenses,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'type': type,
        'isPlaceholder': isPlaceholder,
      };
      await _firestore.collection('shared_budgets').doc(sharedBudgetId).update(updates);
      await FirebaseCrashlytics.instance.log('SharedBudgetRepository: Yhteistalousbudjetti päivitetty, sharedBudgetId: $sharedBudgetId');
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to update shared budget $sharedBudgetId',
      );
      rethrow;
    }
  }

  /// Hakee budjetin tiedot yhteistalousbudjetille (käyttää BudgetModel:ia).
  Future<BudgetModel?> getSharedBudgetById(String sharedBudgetId) async {
    try {
      final snapshot = await _firestore.collection('shared_budgets').doc(sharedBudgetId).get();
      if (!snapshot.exists) {
        return null;
      }
      return BudgetModel.fromMap(snapshot.data()!, snapshot.id);
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to fetch shared budget $sharedBudgetId',
      );
      return null;
    }
  }
}