import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/services/budget_sub_category_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetCategoryController with ChangeNotifier {
  bool _isAdding = false;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _editingSubcategory;
  String? _newlyAddedSubcategory;
  String? _errorMessage;
  final TextEditingController _subcategoryController = TextEditingController();
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  final BudgetSubCategoryService _service = BudgetSubCategoryService();

  bool get isAdding => _isAdding;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  String? get editingSubcategory => _editingSubcategory;
  String? get newlyAddedSubcategory => _newlyAddedSubcategory;
  String? get errorMessage => _errorMessage;
  TextEditingController get subcategoryController => _subcategoryController;
  Map<String, TextEditingController> get nameControllers => _nameControllers;
  Map<String, TextEditingController> get amountControllers => _amountControllers;

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

  void cancelAdding() {
    _isAdding = false;
    _errorMessage = null;
    _subcategoryController.clear();
    notifyListeners();
  }

  void startEditing(String subcategory, BuildContext context) {
    if (_isEditing) return;

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    // Poistettu categoryName-viittaus, koska amount-arvo haetaan suoraan subcategory-arvolla
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

  void cancelEditing() {
    _isEditing = false;
    _editingSubcategory = null;
    _errorMessage = null;
    _nameControllers.remove(_editingSubcategory);
    _amountControllers.remove(_editingSubcategory);
    notifyListeners();
  }

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
      _isSaving = true;
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

      _isAdding = false;
      _isSaving = false;
      _errorMessage = null;
      _subcategoryController.clear();
      _newlyAddedSubcategory = subcategory;
      notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alakategoria "$subcategory" lisätty onnistuneesti!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

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
      _isSaving = true;
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

      _isEditing = false;
      _isSaving = false;
      _editingSubcategory = null;
      _errorMessage = null;
      _nameControllers.remove(oldSubcategory);
      _amountControllers.remove(oldSubcategory);
      notifyListeners();
    }
  }

  Future<void> deleteSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String subcategory,
    required bool deleteEvents,
  }) async {
    await _service.deleteSubcategory(
      context: context,
      userId: userId,
      year: year,
      month: month,
      categoryName: categoryName,
      subcategory: subcategory,
      deleteEvents: deleteEvents,
    );
  }

  Future<void> deleteCategory(BuildContext context, String categoryName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final now = DateTime.now();
      await budgetProvider.deleteExpense(
        userId: authProvider.user!.uid,
        year: now.year,
        month: now.month,
        category: categoryName,
      );
    }
  }

  @override
  void dispose() {
    _subcategoryController.dispose();
    _nameControllers.values.forEach((controller) => controller.dispose());
    _amountControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}