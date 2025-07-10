import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/shared_budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/services/budget_sub_category_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Budjettikategorioiden ja alakategorioiden hallinta.
/// Käsittelee alakategorioiden lisäämistä, muokkaamista ja poistamista budjetissa.
/// Tukee sekä henkilökohtaisia (BudgetProvider) että yhteistalousbudjetteja (SharedBudgetProvider).
/// Varmistaa virheenkäsittelyn kaupallisen sovelluksen vaatimusten mukaisesti.
class BudgetCategoryController with ChangeNotifier {
  bool _isAdding = false; // Näyttääkö uuden alakategorian lisäyslomake
  bool _isEditing = false; // Onko muokkaustila aktiivinen
  bool _isSaving = false; // Onko tallennus käynnissä
  String? _editingSubcategory; // Muokattavan alakategorian nimi
  String? _newlyAddedSubcategory; // Viimeksi lisätyn alakategorian nimi
  String? _errorMessage; // Virheviesti käyttäjälle
  final TextEditingController _subcategoryController = TextEditingController(); // Uuden alakategorian tekstikenttä
  final Map<String, TextEditingController> _nameControllers = {}; // Alakategorioiden nimien tekstikentät
  final Map<String, TextEditingController> _amountControllers = {}; // Alakategorioiden summien tekstikentät
  final BudgetSubCategoryService _service = BudgetSubCategoryService(); // Palvelu alakategorioiden käsittelyyn

  // Getterit tilamuuttujille
  bool get isAdding => _isAdding;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  String? get editingSubcategory => _editingSubcategory;
  String? get newlyAddedSubcategory => _newlyAddedSubcategory;
  String? get errorMessage => _errorMessage;
  TextEditingController get subcategoryController => _subcategoryController;
  Map<String, TextEditingController> get nameControllers => _nameControllers;
  Map<String, TextEditingController> get amountControllers => _amountControllers;

  /// Aloittaa uuden alakategorian lisäämisen.
  /// Tarkistaa, että alakategorioiden määrä ei ylitä rajaa, ja asettaa tilan lisäystilaan.
  void startAdding(BuildContext context, String categoryName, bool isSharedBudget, BudgetModel? sharedBudget) {
    if (_isAdding) return;

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = isSharedBudget
        ? sharedBudget?.expenses[categoryName] ?? {}
        : budgetProvider.budget?.expenses[categoryName] ?? {};
    final error = _service.checkSubcategoryLimit(expenses);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _isAdding = true;
    _errorMessage = null;
    _subcategoryController.clear();
    notifyListeners();
  }

  /// Peruuttaa alakategorian lisäämisen ja nollaa tilan.
  void cancelAdding() {
    _isAdding = false;
    _errorMessage = null;
    _subcategoryController.clear();
    notifyListeners();
  }

  /// Aloittaa olemassa olevan alakategorian muokkauksen.
  /// Hakee nykyisen summan budjetista ja asettaa muokkaustilan päälle.
  void startEditing(String subcategory, BuildContext context, bool isSharedBudget, BudgetModel? sharedBudget) {
    if (_isEditing) return;

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    double amount = 0.0;

    if (isSharedBudget && sharedBudget != null) {
      // Yhteistalousbudjetti
      amount = sharedBudget.expenses.entries
              .firstWhere(
                (entry) => entry.value.containsKey(subcategory),
                orElse: () => MapEntry('', {subcategory: 0.0}),
              )
              .value[subcategory] ??
          0.0;
    } else {
      // Henkilökohtainen budjetti
      amount = budgetProvider.budget?.expenses.entries
              .firstWhere(
                (entry) => entry.value.containsKey(subcategory),
                orElse: () => MapEntry('', {subcategory: 0.0}),
              )
              .value[subcategory] ??
          0.0;
    }

    _isEditing = true;
    _editingSubcategory = subcategory;
    _errorMessage = null;
    _nameControllers[subcategory] = TextEditingController(text: subcategory);
    _amountControllers[subcategory] = TextEditingController(text: amount.toStringAsFixed(2));
    notifyListeners();
  }

  /// Peruuttaa alakategorian muokkauksen ja nollaa tilan.
  void cancelEditing() {
    _isEditing = false;
    _editingSubcategory = null;
    _errorMessage = null;
    _nameControllers.remove(_editingSubcategory);
    _amountControllers.remove(_editingSubcategory);
    notifyListeners();
  }

  /// Lisää uuden alakategorian budjettiin.
  /// Validoi syötteen ja tallentaa alakategorian Firestoreen.
  Future<void> addSubcategory(
    BuildContext context,
    String categoryName,
    bool isSharedBudget,
    BudgetModel? sharedBudget, {
    SharedBudgetScreenController? sharedController,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final expenses = isSharedBudget
        ? sharedBudget?.expenses[categoryName] ?? {}
        : budgetProvider.budget?.expenses[categoryName] ?? {};

    final subcategory = _subcategoryController.text.trim();
    final error = _service.validateSubcategoryName(subcategory, expenses, null);

    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return;
    }

    try {
      _isSaving = true;
      _errorMessage = null;
      notifyListeners();

      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        if (!updatedExpenses.containsKey(categoryName)) {
          updatedExpenses[categoryName] = {};
        }
        updatedExpenses[categoryName]![subcategory] = 0.0;
        await sharedBudgetProvider.updateSharedBudget(
          sharedBudgetId: sharedBudget.id.toString(),
          income: sharedBudget.income,
          expenses: updatedExpenses,
          startDate: sharedBudget.startDate,
          endDate: sharedBudget.endDate,
          type: sharedBudget.type,
          isPlaceholder: sharedBudget.isPlaceholder,
        );
        // Päivitä SharedBudgetScreenController.selectedBudget
        if (sharedController != null) {
          sharedController.updateSelectedBudget(sharedBudget.id.toString());
        }
      } else if (authProvider.user != null && budgetProvider.budget?.id != null) {
        // Henkilökohtainen budjetti
        await _service.addSubcategory(
          context: context,
          userId: authProvider.user!.uid,
          budgetId: budgetProvider.budget!.id!,
          categoryName: categoryName,
          subcategory: subcategory,
          amount: 0.0,
        );
      } else {
        throw Exception('Käyttäjä ei ole kirjautunut tai budjettia ei ole valittu');
      }

      _isAdding = false;
      _isSaving = false;
      _newlyAddedSubcategory = subcategory;
      _errorMessage = null;
      _subcategoryController.clear();
      notifyListeners();

      if (context.mounted) {
        showSnackBar(
          context,
          'Alakategoria "$subcategory" lisätty onnistuneesti!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e, stackTrace) {
      _isSaving = false;
      _errorMessage = 'Alakategorian lisäys epäonnistui: $e';
      notifyListeners();
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to add subcategory, isSharedBudget: $isSharedBudget',
      );
      if (context.mounted) {
        showErrorSnackBar(context, _errorMessage!);
      }
    }
  }

  /// Päivittää olemassa olevan alakategorian nimen ja summan Firestoreen.
  /// Validoi syötteen ja tallentaa muutokset.
  Future<void> updateSubcategory(
    BuildContext context,
    String categoryName,
    String oldSubcategory,
    bool isSharedBudget,
    BudgetModel? sharedBudget, {
    SharedBudgetScreenController? sharedController,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final expenses = isSharedBudget
        ? sharedBudget?.expenses[categoryName] ?? {}
        : budgetProvider.budget?.expenses[categoryName] ?? {};

    final newSubcategory = _nameControllers[oldSubcategory]!.text.trim();
    final amountText = _amountControllers[oldSubcategory]!.text.trim();

    final nameError = _service.validateSubcategoryName(newSubcategory, expenses, oldSubcategory);
    final amountError = _service.validateAmount(amountText);

    if (nameError != null) {
      _errorMessage = nameError;
      notifyListeners();
      return;
    }
    if (amountError != null) {
      _errorMessage = amountError;
      notifyListeners();
      return;
    }

    final amount = double.parse(amountText);

    try {
      _isSaving = true;
      _errorMessage = null;
      notifyListeners();

      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        if (updatedExpenses.containsKey(categoryName)) {
          final subcategories = Map<String, double>.from(updatedExpenses[categoryName]!);
          subcategories.remove(oldSubcategory);
          subcategories[newSubcategory] = amount;
          updatedExpenses[categoryName] = subcategories;
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id.toString(),
            income: sharedBudget.income,
            expenses: updatedExpenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
          // Päivitä SharedBudgetScreenController.selectedBudget
          if (sharedController != null) {
            sharedController.updateSelectedBudget(sharedBudget.id.toString());
          }
        }
      } else if (authProvider.user != null && budgetProvider.budget?.id != null) {
        // Henkilökohtainen budjetti
        await _service.updateSubcategory(
          context: context,
          userId: authProvider.user!.uid,
          budgetId: budgetProvider.budget!.id!,
          categoryName: categoryName,
          oldSubcategory: oldSubcategory,
          newSubcategory: newSubcategory,
          amount: amount,
        );
      } else {
        throw Exception('Käyttäjä ei ole kirjautunut tai budjettia ei ole valittu');
      }

      _isEditing = false;
      _isSaving = false;
      _editingSubcategory = null;
      _nameControllers.remove(oldSubcategory);
      _amountControllers.remove(oldSubcategory);
      _errorMessage = null;
      notifyListeners();

      if (context.mounted) {
        showSnackBar(
          context,
          'Alakategoria "$oldSubcategory" päivitetty onnistuneesti nimelle "$newSubcategory"',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e, stackTrace) {
      _isSaving = false;
      _errorMessage = 'Alakategorian päivitys epäonnistui: $e';
      notifyListeners();
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to update subcategory, isSharedBudget: $isSharedBudget',
      );
      if (context.mounted) {
        showErrorSnackBar(context, _errorMessage!);
      }
    }
  }

  /// Poistaa alakategorian budjetista Firestoresta.
  /// Delegoi poiston BudgetSubCategoryService:lle yhteistalousbudjeteille tai päivittää SharedBudgetProvider:lle.
  Future<void> deleteSubcategory({
    required BuildContext context,
    required String userId,
    required String budgetId,
    required String categoryName,
    required String subcategory,
    required bool deleteEvents,
    bool isSharedBudget = false,
    BudgetModel? sharedBudget,
    SharedBudgetScreenController? sharedController,
  }) async {
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

    try {
      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        if (updatedExpenses.containsKey(categoryName)) {
          final subcategories = Map<String, double>.from(updatedExpenses[categoryName]!);
          subcategories.remove(subcategory);
          updatedExpenses[categoryName] = subcategories;
          if (subcategories.isEmpty) {
            updatedExpenses.remove(categoryName);
          }
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id.toString(),
            income: sharedBudget.income,
            expenses: updatedExpenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
          // Päivitä SharedBudgetScreenController.selectedBudget
          if (sharedController != null) {
            sharedController.updateSelectedBudget(sharedBudget.id.toString());
          }
        }
      } else {
        // Henkilökohtainen budjetti
        await _service.deleteSubcategory(
          context: context,
          userId: userId,
          budgetId: budgetId,
          categoryName: categoryName,
          subcategory: subcategory,
          deleteEvents: deleteEvents,
        );
      }

      notifyListeners();
      if (context.mounted) {
        showSnackBar(
          context,
          'Alakategoria "$subcategory" poistettu onnistuneesti!',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Alakategorian poisto epäonnistui: $e';
      notifyListeners();
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to delete subcategory, isSharedBudget: $isSharedBudget',
      );
      if (context.mounted) {
        showErrorSnackBar(context, _errorMessage!);
      }
    }
  }

  /// Poistaa koko kategorian budjetista Firestoresta.
  /// Delegoi poiston BudgetProvider:lle tai SharedBudgetProvider:lle.
  Future<void> deleteCategory(
    BuildContext context,
    String categoryName,
    bool isSharedBudget,
    BudgetModel? sharedBudget,
    SharedBudgetScreenController? sharedController,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);

    try {
      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        updatedExpenses.remove(categoryName);
        await sharedBudgetProvider.updateSharedBudget(
          sharedBudgetId: sharedBudget.id.toString(),
          income: sharedBudget.income,
          expenses: updatedExpenses,
          startDate: sharedBudget.startDate,
          endDate: sharedBudget.endDate,
          type: sharedBudget.type,
          isPlaceholder: sharedBudget.isPlaceholder,
        );
        // Päivitä SharedBudgetScreenController.selectedBudget
        if (sharedController != null) {
          sharedController.updateSelectedBudget(sharedBudget.id.toString());
        }
      } else if (authProvider.user != null && budgetProvider.budget?.id != null) {
        // Henkilökohtainen budjetti
        await budgetProvider.deleteExpense(
          userId: authProvider.user!.uid,
          budgetId: budgetProvider.budget!.id!,
          category: categoryName,
        );
      } else {
        throw Exception('Käyttäjä ei ole kirjautunut tai budjettia ei ole valittu');
      }

      notifyListeners();
      if (context.mounted) {
        showSnackBar(
          context,
          'Kategoria "$categoryName" poistettu onnistuneesti!',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        );
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Kategorian poisto epäonnistui: $e';
      notifyListeners();
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to delete category, isSharedBudget: $isSharedBudget',
      );
      if (context.mounted) {
        showErrorSnackBar(context, _errorMessage!);
      }
    }
  }

  /// Vapauttaa resurssit, kuten tekstikenttien ohjaimet, kun kontrolleri poistetaan käytöstä.
  @override
  void dispose() {
    _subcategoryController.dispose();
    for (var controller in _nameControllers.values) {
      controller.dispose();
    }
    for (var controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}