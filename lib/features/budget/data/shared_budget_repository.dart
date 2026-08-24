import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/domain/money.dart';
import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:uuid/uuid.dart';

/// Repositorio yhteistalousbudjettien ja kutsujen hallintaan Firestoressa.
/// Kaikki Firestore-operaatiot keskitetty tänne optimoinnin ja modulaarisuuden vuoksi.
/// Käyttää batch-write:eja monioperaatioissa kulujen vähentämiseksi.
/// Päivitetty: Käytetään BudgetModel:ia kaikille budjeteille (sisältää shared-kentät optionalina).
class SharedBudgetRepository {
  SharedBudgetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _events = EventRepository(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final FirebaseFirestore _firestore;
  final EventRepository _events;

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

  /// Hakee odottavat kutsut käyttäjän sähköpostilla (query optimoitu limit:llä).
  Future<List<Invitation>> getPendingInvitations(String email) async {
    try {
      final String normalizedEmail = normalizeInviteEmailForLookup(email);
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

  Future<void> createSharedBudget({
    required String userId,
    required BudgetModel budget,
  }) async {
    final sharedBudgetId = budget.id ?? budget.sharedBudgetId;
    if (sharedBudgetId == null || sharedBudgetId.isEmpty) {
      throw Exception('sharedBudgetId puuttuu');
    }
    try {
      final memberIds = householdUsersForNewPeriod(
        creatorId: userId,
        previousUsers: budget.users,
      );
      final sharedBudget = budget.copyWith(
        id: sharedBudgetId,
        sharedBudgetId: sharedBudgetId,
        users: memberIds,
        createdBy: userId,
      );
      await _firestore
          .collection('shared_budgets')
          .doc(sharedBudgetId)
          .set(sharedBudget.toMap());
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to create shared budget for user $userId',
      );
      rethrow;
    }
  }

  /// Invite to an existing household plan. Plan must already exist.
  Future<String> createInvitationForExistingBudget({
    required String sharedBudgetId,
    required String inviterId,
    required String inviterEmail,
    required String inviteeEmail,
    required String? inviteeUid,
  }) async {
    final budget = await getSharedBudgetById(sharedBudgetId);
    if (budget == null) {
      throw Exception('Budjettia ei löydy');
    }
    final pending = await getPendingInvitations(inviteeEmail);
    final pendingForBudget = pending
        .where((invite) => invite.sharedBudgetId == sharedBudgetId)
        .map((invite) => invite.inviteeEmail);
    final result = validateInvite(
      inviteeEmail: inviteeEmail,
      inviterEmail: inviterEmail,
      inviteeUid: inviteeUid,
      memberUids: budget.users ?? const [],
      pendingEmails: pendingForBudget,
    );
    if (result != InviteValidation.ok) {
      throw Exception(inviteValidationMessage(result));
    }

    try {
      final invitationId = const Uuid().v4();
      final invitation = Invitation(
        id: invitationId,
        sharedBudgetId: sharedBudgetId,
        inviterId: inviterId,
        inviteeEmail: normalizeInviteEmailForLookup(inviteeEmail),
        status: 'pending',
        createdAt: DateTime.now(),
      );
      await _firestore.collection('invitations').doc(invitationId).set(invitation.toMap());
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
      await _firestore.runTransaction((transaction) async {
        final invitationRef = _firestore.collection('invitations').doc(invitationId);
        final budgetRef =
            _firestore.collection('shared_budgets').doc(sharedBudgetId);

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
      await _firestore
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

  Future<void> updateSharedBudget(BudgetModel budget) async {
    final sharedBudgetId = budget.id ?? budget.sharedBudgetId;
    if (sharedBudgetId == null || sharedBudgetId.isEmpty) {
      throw Exception('sharedBudgetId puuttuu');
    }
    try {
      await _firestore.collection('shared_budgets').doc(sharedBudgetId).update({
        'income': budget.income,
        'expenses': budget.expenses,
        'startDate': budget.startDate.toIso8601String(),
        'endDate': budget.endDate.toIso8601String(),
        'type': budget.type,
        'isPlaceholder': budget.isPlaceholder,
      });
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to update shared budget $sharedBudgetId',
      );
      rethrow;
    }
  }

  Future<double> adjustIncome({
    required String sharedBudgetId,
    required double amount,
    required bool add,
  }) async {
    final budget = await getSharedBudgetById(sharedBudgetId);
    if (budget == null) {
      throw Exception('Budjettia ei löydy');
    }
    final updated = add
        ? incomeAfterAdd(budget.income, amount)
        : incomeAfterSubtract(budget.income, amount);
    await updateSharedBudget(budget.copyWith(income: updated));
    return updated;
  }

  Stream<BudgetModel?> watchSharedBudget(String sharedBudgetId) {
    return _firestore
        .collection('shared_budgets')
        .doc(sharedBudgetId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return BudgetModel.fromMap(snapshot.data()!, snapshot.id);
    });
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

  Future<Invitation> enrichInvitation(Invitation invite) async {
    try {
      final inviterSnap =
          await _firestore.collection('users').doc(invite.inviterId).get();
      final fetchedInviterEmail =
          inviterSnap.data()?['email'] as String?;
      final budgetSnap = await _firestore
          .collection('shared_budgets')
          .doc(invite.sharedBudgetId)
          .get();
      final budgetName =
          budgetSnap.data()?['name'] as String? ?? 'Nimetön budjetti';
      return invite.copyWith(
        inviterEmail: fetchedInviterEmail ?? 'tuntematon@example.com',
        sharedBudgetName: budgetName,
      );
    } catch (_) {
      return invite.copyWith(
        inviterEmail: 'tuntematon@example.com',
        sharedBudgetName: 'Nimetön budjetti',
      );
    }
  }

  /// Deletes the shared plan and its events.
  Future<void> deleteSharedBudget({
    required String userId,
    required String sharedBudgetId,
  }) async {
    try {
      await _events.deleteEventsForBudget(
        userId: userId,
        budgetId: sharedBudgetId,
        isSharedBudget: true,
      );
      await _firestore.collection('shared_budgets').doc(sharedBudgetId).delete();
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to delete shared budget $sharedBudgetId',
      );
      rethrow;
    }
  }
}