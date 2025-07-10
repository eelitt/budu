import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

/// Kontrolleri yhteistalousbudjettien tilan hallintaan.
/// Käsittelee budjetin lataamista, nollausta ja poistamista.
/// Käyttää BehaviorSubject:ia budjetin tilan reaaliaikaiseen seurantaan.
class SharedBudgetScreenController {
  final BuildContext context;
  final VoidCallback onStateChanged;
  final VoidCallback? onBudgetDeleted;
  bool _isInitialized = false;
  bool _isLoadingBudget = false;

  final BehaviorSubject<BudgetModel?> _selectedBudget = BehaviorSubject<BudgetModel?>();
  ValueStream<BudgetModel?> get selectedBudget => _selectedBudget.stream;

  SharedBudgetScreenController({
    required this.context,
    required this.onStateChanged,
    this.onBudgetDeleted,
  }) {
    _initialize();
  }

  bool get isInitialized => _isInitialized;
  bool get isLoadingBudget => _isLoadingBudget;

  Future<void> _initialize() async {
    _isInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onStateChanged();
    });
  }

  /// Lataa budjetin tiedot yhteistalousbudjetille.
  Future<void> loadBudget({required String userId, required String sharedBudgetId}) async {
    _isLoadingBudget = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onStateChanged();
    });

    try {
      final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      final budget = await sharedBudgetProvider.getSharedBudgetById(sharedBudgetId);
      if (budget != null) {
       // _selectedBudget.add(budget);
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load shared budget $sharedBudgetId for user $userId',
      );
    } finally {
      _isLoadingBudget = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onStateChanged();
      });
    }
  }

  /// Päivittää selectedBudget SharedBudgetProvider.sharedBudgets:n perusteella.
  void updateSelectedBudget(String sharedBudgetId) {
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final updatedBudget = sharedBudgetProvider.sharedBudgets.firstWhere(
      (budget) => budget.id == sharedBudgetId,
      orElse: () => sharedBudgetProvider.sharedBudgets.isNotEmpty
          ? sharedBudgetProvider.sharedBudgets.first
          : _selectedBudget.value != null && _selectedBudget.value!.id != null
              ? BudgetModel.fromMap(_selectedBudget.value!.toMap(), _selectedBudget.value!.id)
              : throw Exception('No valid shared budget available'),
    );
    _selectedBudget.add(BudgetModel(
      id: updatedBudget.id,
      income: updatedBudget.income,
      expenses: updatedBudget.expenses,
      createdAt: updatedBudget.createdAt,
      startDate: updatedBudget.startDate,
      endDate: updatedBudget.endDate,
      type: updatedBudget.type,
      isPlaceholder: updatedBudget.isPlaceholder,
      sharedBudgetId: updatedBudget.id,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onStateChanged();
    });
  }

  /// Nollaa budjetin menot ja tapahtumat.
  Future<void> resetBudgetExpenses({required String userId, required String sharedBudgetId}) async {
    try {
      final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

      final budget = sharedBudgetProvider.sharedBudgets.firstWhere((b) => b.id == sharedBudgetId);
      await sharedBudgetProvider.updateSharedBudget(
        sharedBudgetId: sharedBudgetId,
        income: budget.income,
        expenses: {},
        startDate: budget.startDate,
        endDate: budget.endDate,
        type: budget.type,
        isPlaceholder: budget.isPlaceholder,
      );
      await expenseProvider.deleteAllExpensesForBudget(
        userId: userId,
        budgetId: sharedBudgetId,
        isSharedBudget: true,
      );
      await loadBudget(userId: userId, sharedBudgetId: sharedBudgetId);
      await FirebaseCrashlytics.instance.log('SharedBudgetScreenController: Expenses reset for sharedBudgetId $sharedBudgetId');
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to reset expenses for sharedBudgetId $sharedBudgetId',
      );
      rethrow;
    }
  }

  /// Poistaa budjetin ja siihen liittyvät tapahtumat.
  Future<void> deleteBudget({required String userId, required String sharedBudgetId}) async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      await expenseProvider.deleteAllExpensesForBudget(
        userId: userId,
        budgetId: sharedBudgetId,
        isSharedBudget: true,
      );
      await FirebaseFirestore.instance.collection('shared_budgets').doc(sharedBudgetId).delete();
      _selectedBudget.add(null);
      onBudgetDeleted?.call();
      await FirebaseCrashlytics.instance.log('SharedBudgetScreenController: Shared budget deleted, ID: $sharedBudgetId');
      if (context.mounted) {
        Navigator.pushNamed(context, AppRouter.mainRoute, arguments: {'index': 0});
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to delete shared budget $sharedBudgetId',
      );
      rethrow;
    }
  }

  void dispose() {
    _selectedBudget.close();
  }
}