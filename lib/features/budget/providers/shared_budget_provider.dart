import 'package:budu/features/budget/data/shared_budget_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Provider yhteistalousbudjettien ja kutsujen hallintaan.
/// Välittää dataa repositorysta UI:lle, hallinnoi tilaa ja käyttää streameja reaaliaikaiseen dataan.
/// Peruuttaa subskriptiot muistivuotojen estämiseksi.
class SharedBudgetProvider with ChangeNotifier {
  final SharedBudgetRepository _repository = SharedBudgetRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      if (budget.endDate != null &&
          (latest == null || budget.endDate!.isAfter(latest!.endDate!))) {
        latest = budget;
      }
    }
    return latest;
  }
  
  /// Hakee käyttäjän yhteistalousbudjetit ja päivittää tilan (käyttää repositorya).
  Future<void> fetchSharedBudgets(String userId) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Päivitä UI heti loading-tilassa

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
  if (_isLoading) return;

  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedEmail = userEmail.trim().toLowerCase();
    var invitations = await _repository.getPendingInvitations(normalizedEmail);

    // Enrich in parallel (efficient for rare/low count)
    invitations = await Future.wait(
      invitations.map((invite) async {
        try {
          // Fetch inviter email from /users/{inviterId}
          final inviterSnap = await _firestore
              .collection('users')
              .doc(invite.inviterId)
              .get();
          final inviterData = inviterSnap.data();
          final fetchedInviterEmail = inviterData?['email'] as String?;

          // Fetch budget name
          final budgetSnap = await _firestore
              .collection('shared_budgets')
              .doc(invite.sharedBudgetId)
              .get();
          final budgetName = budgetSnap.data()?['name'] as String? ?? 'Nimetön budjetti';

          return invite.copyWith(
            inviterEmail: fetchedInviterEmail ?? 'tuntematon@example.com',
            sharedBudgetName: budgetName,
          );
        } catch (e) {
          // Graceful fallback on error – don't break whole load
          print('Enrichment error for invite ${invite.id}: $e');
          return invite.copyWith(
            inviterEmail: 'tuntematon@example.com',
            sharedBudgetName: 'Nimetön budjetti',
          );
        }
      }),
    );

    _invitations = invitations;
  } catch (e) {
    _errorMessage = 'Kutsujen lataaminen epäonnistui: $e';
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  /// Luo uuden yhteistalousbudjetin (käyttää repositorya).
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
    if (_isLoading) throw Exception('Toiminto jo käynnissä');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.createSharedBudget(
        sharedBudgetId: sharedBudgetId,
        userId: userId,
        name: name,
        income: income,
        expenses: expenses,
        startDate: startDate,
        endDate: endDate,
        type: type,
        isPlaceholder: isPlaceholder,
      );
      await fetchSharedBudgets(userId); // Refetch varmistaa ajantasaisen datan
    } catch (e) {
      _errorMessage = 'Yhteistalousbudjetin luominen epäonnistui: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Luo kutsun olemassa olevalle yhteistalousbudjetille (käyttää repositorya).
  Future<String> createInvitationForExistingBudget({
    required String sharedBudgetId,
    required String inviterId,
    required String inviteeEmail,
  }) async {
    if (_isLoading) throw Exception('Toiminto jo käynnissä');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final invitationId = await _repository.createInvitationForExistingBudget(
        sharedBudgetId: sharedBudgetId,
        inviterId: inviterId,
        inviteeEmail: inviteeEmail,
      );
      return invitationId;
    } catch (e) {
      _errorMessage = 'Kutsun luominen epäonnistui: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Updated accept – now passes userId
  Future<void> acceptInvitation({
    required String invitationId,
    required String sharedBudgetId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _repository.acceptInvitation(
        invitationId: invitationId,
        sharedBudgetId: sharedBudgetId,
        userId: userId,
      );
    } catch (e) {
      _errorMessage = 'Kutsun hyväksyminen epäonnistui: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Decline unchanged (no userId needed)
  Future<void> declineInvitation(String invitationId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _repository.declineInvitation(invitationId);
    } catch (e) {
      _errorMessage = 'Kutsun hylkääminen epäonnistui: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  /// Hakee budjetin tiedot yhteistalousbudjetille (käyttää repositorya).
  Future<BudgetModel?> getSharedBudgetById(String sharedBudgetId) async {
    return await _repository.getSharedBudgetById(sharedBudgetId);
  }

  /// Päivittää yhteistalousbudjetin tiedot ja tilan (käyttää repositorya, refetch varmistaa).
  Future<void> updateSharedBudget({
    required String sharedBudgetId,
    required double income,
    required Map<String, Map<String, double>> expenses,
    required DateTime startDate,
    required DateTime endDate,
    required String type,
    bool isPlaceholder = false,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateSharedBudget(
        sharedBudgetId: sharedBudgetId,
        income: income,
        expenses: expenses,
        startDate: startDate,
        endDate: endDate,
        type: type,
        isPlaceholder: isPlaceholder,
      );
      // Refetch repositorysta manuaalisen päivityksen sijaan (varmempi reaaliaikaisessa datassa)
      final updatedBudget = await _repository.getSharedBudgetById(sharedBudgetId);
      if (updatedBudget != null) {
        _sharedBudgets = [
          ..._sharedBudgets.where((budget) => budget.id != sharedBudgetId),
          updatedBudget,
        ];
      }
    } catch (e) {
      _errorMessage = 'Budjetin päivitys epäonnistui: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

 
}