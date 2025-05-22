import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/services/budget_sub_category_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Budjettikategorioiden ja alakategorioiden hallinta.
/// Käsittelee alakategorioiden lisäämistä, muokkaamista ja poistamista budjetissa.
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
  void startAdding(BuildContext context, String categoryName) {
    if (_isAdding) return;

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[categoryName] ?? {};
    final error = _service.checkSubcategoryLimit(expenses);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _isAdding = true;
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
  void startEditing(String subcategory, BuildContext context) {
    if (_isEditing) return;

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final amount = budgetProvider.budget?.expenses.entries
            .firstWhere(
              (entry) => entry.value.containsKey(subcategory),
              orElse: () => MapEntry('', {subcategory: 0.0}),
            )
            .value[subcategory] ??
        0.0;

    _isEditing = true;
    _editingSubcategory = subcategory;
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
  Future<void> addSubcategory(BuildContext context, String categoryName) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[categoryName] ?? {};

    final subcategory = _subcategoryController.text.trim();
    final error = _service.validateSubcategoryName(subcategory, expenses, null);

    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        // Yhdistä tilanpäivitykset: aseta _isSaving ja nollaa _errorMessage yhdessä
        _isSaving = true;
        _errorMessage = null;
        notifyListeners();

        final now = DateTime.now();
        await _service.addSubcategory(
          context: context,
          userId: authProvider.user!.uid,
          year: now.year,
          month: now.month,
          categoryName: categoryName,
          subcategory: subcategory,
          amount: 0.0,
        );

        // Budjetin tilanpäivitys (BudgetProvider) hoitaa käyttöliittymän budjettipäivityksen
        _isAdding = false;
        _isSaving = false;
        _subcategoryController.clear();
        _newlyAddedSubcategory = subcategory;
        notifyListeners();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alakategoria "$subcategory" lisätty onnistuneesti!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Failed to add subcategory in BudgetCategoryController',
        );

        // Näytä ystävällinen virheilmoitus käyttäjälle
        if (context.mounted) {
          showErrorSnackBar(context, 'Alakategorian lisäys epäonnistui: $e');
        }

        // Päivitä tila: poista tallennustila ja näytä virhe
        _isSaving = false;
        _errorMessage = 'Alakategorian lisäys epäonnistui';
        notifyListeners();
      }
    }
  }

  /// Päivittää olemassa olevan alakategorian nimen ja summan Firestoreen.
  /// Validoi syötteen ja tallentaa muutokset.
  Future<void> updateSubcategory(BuildContext context, String categoryName, String oldSubcategory) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[categoryName] ?? {};

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        // Yhdistä tilanpäivitykset: aseta _isSaving ja nollaa _errorMessage yhdessä
        _isSaving = true;
        _errorMessage = null;
        notifyListeners();

        final now = DateTime.now();
        await _service.updateSubcategory(
          context: context,
          userId: authProvider.user!.uid,
          year: now.year,
          month: now.month,
          categoryName: categoryName,
          oldSubcategory: oldSubcategory,
          newSubcategory: newSubcategory,
          amount: amount,
        );

        // Budjetin tilanpäivitys (BudgetProvider) hoitaa käyttöliittymän budjettipäivityksen
        _isEditing = false;
        _isSaving = false;
        _editingSubcategory = null;
        _nameControllers.remove(oldSubcategory);
        _amountControllers.remove(oldSubcategory);
        notifyListeners();
      } catch (e) {
        // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Failed to update subcategory in BudgetCategoryController',
        );

        // Näytä ystävällinen virheilmoitus käyttäjälle
        if (context.mounted) {
          showErrorSnackBar(context, 'Alakategorian päivitys epäonnistui: $e');
        }

        // Päivitä tila: poista tallennustila ja näytä virhe
        _isSaving = false;
        _errorMessage = 'Alakategorian päivitys epäonnistui';
        notifyListeners();
      }
    }
  }

  /// Poistaa alakategorian budjetista Firestoresta.
  /// Delegoi poiston BudgetSubCategoryService:lle, mutta käsittelee virheet hallitusti.
  Future<void> deleteSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String subcategory,
    required bool deleteEvents,
  }) async {
    try {
      await _service.deleteSubcategory(
        context: context,
        userId: userId,
        year: year,
        month: month,
        categoryName: categoryName,
        subcategory: subcategory,
        deleteEvents: deleteEvents,
      );
      // Budjetin tilanpäivitys (BudgetProvider) hoitaa käyttöliittymän päivityksen
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete subcategory in BudgetCategoryController',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Alakategorian poisto epäonnistui: $e');
      }
    }
  }

  /// Poistaa koko kategorian budjetista Firestoresta.
  /// Delegoi poiston BudgetProvider:lle, mutta käsittelee virheet hallitusti.
  Future<void> deleteCategory(BuildContext context, String categoryName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      try {
        final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
        final now = DateTime.now();
        await budgetProvider.deleteExpense(
          userId: authProvider.user!.uid,
          year: now.year,
          month: now.month,
          category: categoryName,
        );
        // Budjetin tilanpäivitys (BudgetProvider) hoitaa käyttöliittymän päivityksen
      } catch (e) {
        // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
        await FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Failed to delete category in BudgetCategoryController',
        );

        // Näytä ystävällinen virheilmoitus käyttäjälle
        if (context.mounted) {
          showErrorSnackBar(context, 'Kategorian poisto epäonnistui: $e');
        }
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