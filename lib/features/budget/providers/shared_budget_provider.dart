import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:budu/features/budget/data/shared_budget_repository.dart';
import 'package:budu/features/budget/domain/shared_rules.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:budu/features/notification/data/notification_repository.dart';
import 'package:flutter/material.dart';

class SharedBudgetProvider with ChangeNotifier {
  SharedBudgetProvider({
    SharedBudgetRepository? repository,
    UserProfileRepository? profiles,
    NotificationRepository? notifications,
  })  : _repository = repository ?? SharedBudgetRepository(),
        _profiles = profiles ?? UserProfileRepository(),
        _notifications = notifications ?? NotificationRepository();

  final SharedBudgetRepository _repository;
  final UserProfileRepository _profiles;
  final NotificationRepository _notifications;
  List<BudgetModel> _sharedBudgets = [];
  List<Invitation> _invitations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Invitation> get pendingInvitations =>
      _invitations.where((inv) => inv.status == 'pending').toList();
  List<BudgetModel> get sharedBudgets => _sharedBudgets;
  List<Invitation> get invitations => _invitations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSharedBudget => _sharedBudgets.isNotEmpty;

  BudgetModel? get latestSharedBudget {
    if (_sharedBudgets.isEmpty) return null;
    BudgetModel? latest;
    for (final budget in _sharedBudgets) {
      if (latest == null || budget.endDate.isAfter(latest.endDate)) {
        latest = budget;
      }
    }
    return latest;
  }

  void _replaceInList(BudgetModel budget) {
    _sharedBudgets = [
      ..._sharedBudgets.where((b) => b.id != budget.id),
      budget,
    ];
  }

  Future<void> fetchSharedBudgets(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sharedBudgets = await _repository.getSharedBudgets(userId);
    } catch (e) {
      _errorMessage = 'Yhteistalousbudjettien lataus epäonnistui: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPendingInvitations(String userEmail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final normalizedEmail = userEmail.trim().toLowerCase();
      var invitations = await _repository.getPendingInvitations(normalizedEmail);
      invitations = await Future.wait(
        invitations.map(_repository.enrichInvitation),
      );
      _invitations = invitations;
    } catch (e) {
      _errorMessage = 'Kutsujen lataaminen epäonnistui: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createSharedBudget({
    required String userId,
    required BudgetModel budget,
  }) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.createSharedBudget(userId: userId, budget: budget);
      _sharedBudgets = await _repository.getSharedBudgets(userId);
    } catch (e) {
      _errorMessage = 'Yhteistalousbudjetin luominen epäonnistui: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<InviteValidation> validateNewInvite({
    required String inviterEmail,
    required String inviteeEmail,
    required List<String> memberUids,
    required Iterable<String> queuedEmails,
  }) async {
    final inviteeUid = await _profiles.getUidByEmail(inviteeEmail);
    return validateInvite(
      inviteeEmail: inviteeEmail,
      inviterEmail: inviterEmail,
      inviteeUid: inviteeUid,
      memberUids: memberUids,
      pendingEmails: queuedEmails,
    );
  }

  Future<String> inviteUser({
    required String sharedBudgetId,
    required String inviterId,
    required String inviterEmail,
    required String inviteeEmail,
  }) async {
    final inviteeUid = await _profiles.getUidByEmail(inviteeEmail);
    final invitationId = await _repository.createInvitationForExistingBudget(
      sharedBudgetId: sharedBudgetId,
      inviterId: inviterId,
      inviterEmail: inviterEmail,
      inviteeEmail: inviteeEmail,
      inviteeUid: inviteeUid,
    );
    final budget = await _repository.getSharedBudgetById(sharedBudgetId);
    final budgetName = budget?.name ?? 'yhteistalousbudjettiin';
    if (inviteeUid != null) {
      await _notifications.createNotification(
        userId: inviteeUid,
        type: 'invitation',
        message: 'Olet kutsuttu yhteistalousbudjettiin "$budgetName"',
        invitationId: invitationId,
      );
    }
    return invitationId;
  }

  Future<void> deleteSharedBudget({
    required String userId,
    required String sharedBudgetId,
  }) async {
    await _repository.deleteSharedBudget(
      userId: userId,
      sharedBudgetId: sharedBudgetId,
    );
    _sharedBudgets =
        _sharedBudgets.where((budget) => budget.id != sharedBudgetId).toList();
    notifyListeners();
  }

  Future<void> acceptInvitation({
    required String invitationId,
    required String sharedBudgetId,
    required String userId,
  }) async {
    try {
      await _repository.acceptInvitation(
        invitationId: invitationId,
        sharedBudgetId: sharedBudgetId,
        userId: userId,
      );
    } catch (e) {
      _errorMessage = 'Kutsun hyväksyminen epäonnistui: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> declineInvitation(String invitationId) async {
    try {
      await _repository.declineInvitation(invitationId);
    } catch (e) {
      _errorMessage = 'Kutsun hylkääminen epäonnistui: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<BudgetModel?> getSharedBudgetById(String sharedBudgetId) async {
    return await _repository.getSharedBudgetById(sharedBudgetId);
  }

  Stream<BudgetModel?> watchSharedBudget(String sharedBudgetId) {
    return _repository.watchSharedBudget(sharedBudgetId);
  }

  Future<void> updateSharedBudget(BudgetModel budget) async {
    _errorMessage = null;
    try {
      await _repository.updateSharedBudget(budget);
      final updated = await _repository.getSharedBudgetById(
        budget.id ?? budget.sharedBudgetId ?? '',
      );
      if (updated != null) {
        _replaceInList(updated);
      }
    } catch (e) {
      _errorMessage = 'Budjetin päivitys epäonnistui: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> adjustIncome({
    required String sharedBudgetId,
    required double amount,
    required bool add,
  }) async {
    final updated = await _repository.adjustIncome(
      sharedBudgetId: sharedBudgetId,
      amount: amount,
      add: add,
    );
    BudgetModel? current;
    for (final budget in _sharedBudgets) {
      if (budget.id == sharedBudgetId) {
        current = budget;
        break;
      }
    }
    if (current != null) {
      _replaceInList(current.copyWith(income: updated));
    }
    notifyListeners();
  }
}
