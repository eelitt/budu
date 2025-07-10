import 'package:budu/features/budget/data/shared_budget_repository.dart';
import 'package:budu/features/budget/models/budget_model.dart'; // Päivitetty: Käytetään yhdistettyä BudgetModel:ia SharedBudget:in sijaan
import 'package:budu/features/budget/models/invitation_model.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // Lisätty StreamSubscription:ia varten

/// Provider yhteistalousbudjettien ja kutsujen hallintaan.
/// Välittää dataa repositorysta UI:lle, hallinnoi tilaa ja käyttää streameja reaaliaikaiseen dataan.
/// Peruuttaa subskriptiot muistivuotojen estämiseksi.
/// Päivitetty: Käytetään BudgetModel:ia sharedBudgets-listalle (sisältää shared-kentät).
class SharedBudgetProvider with ChangeNotifier {
  final SharedBudgetRepository _repository = SharedBudgetRepository();
  List<BudgetModel> _sharedBudgets = [];
  List<Invitation> _invitations = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<BudgetModel>>? _sharedBudgetsSubscription;
  StreamSubscription<List<Invitation>>? _invitationsSubscription;

  List<BudgetModel> get sharedBudgets => _sharedBudgets;
  List<Invitation> get invitations => _invitations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  /// Aloittaa reaaliaikaisen kuuntelun käyttäjän yhteistalousbudjeteille.
  void listenToSharedBudgets(String userId) {
    _sharedBudgetsSubscription?.cancel();
    _sharedBudgetsSubscription = _repository.sharedBudgetsStream(userId).listen(
      (budgets) {
        _sharedBudgets = budgets;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Yhteistalousbudjettien stream epäonnistui: $e';
        notifyListeners();
      },
    );
  }

  /// Hakee odottavat kutsut käyttäjän sähköpostilla (käyttää repositorya).
  Future<void> fetchPendingInvitations(String email) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _invitations = await _repository.getPendingInvitations(email);
    } catch (e) {
      _errorMessage = 'Kutsujen lataus epäonnistui: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Aloittaa reaaliaikaisen kuuntelun odottaville kutsuille.
  void listenToPendingInvitations(String email) {
    _invitationsSubscription?.cancel();
    _invitationsSubscription = _repository.pendingInvitationsStream(email).listen(
      (invitations) {
        _invitations = invitations;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Kutsujen stream epäonnistui: $e';
        notifyListeners();
      },
    );
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

  /// Hyväksyy kutsun ja lisää käyttäjän yhteistalousbudjettiin (käyttää repositorya).
  Future<void> acceptInvitation({
    required String invitationId,
    required String userId,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.acceptInvitation(
        invitationId: invitationId,
        userId: userId,
      );
      await fetchSharedBudgets(userId); // Refetch päivittää listan
    } catch (e) {
      _errorMessage = 'Kutsun hyväksyminen epäonnistui: $e';
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

  /// Peruuttaa reaaliaikaiset kuuntelijat muistivuotojen estämiseksi.
  void cancelSubscriptions() {
    _sharedBudgetsSubscription?.cancel();
    _invitationsSubscription?.cancel();
    _sharedBudgetsSubscription = null;
    _invitationsSubscription = null;
  }
}