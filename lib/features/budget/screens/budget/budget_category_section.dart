// lib/features/budget/screens/budget/budget_category_section.dart
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/screens/budget/services/budget_category_service.dart';
import 'package:budu/features/budget/screens/budget/utils/category_icon_utils.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_subcategory_form.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_category_list.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetCategorySection extends StatefulWidget {
  final String categoryName;

  const BudgetCategorySection({super.key, required this.categoryName});

  @override
  State<BudgetCategorySection> createState() => _BudgetCategorySectionState();
}

class _BudgetCategorySectionState extends State<BudgetCategorySection> {
  bool _isAdding = false;
  bool _isEditing = false;
  String? _editingSubcategory;
  final TextEditingController _subcategoryController = TextEditingController();
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  String? _errorMessage;
  final ExpansionTileController _expansionController = ExpansionTileController();
  final GlobalKey _expansionTileKey = GlobalKey();
  final BudgetCategoryService _service = BudgetCategoryService();

  @override
  void dispose() {
    _subcategoryController.dispose();
    _nameControllers.values.forEach((controller) => controller.dispose());
    _amountControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _startAdding() {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};
    final error = _service.checkSubcategoryLimit(expenses);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() {
      _isAdding = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _expansionController.expand();
      }
    });
  }

  void _cancelAdding() {
    setState(() {
      _isAdding = false;
      _errorMessage = null;
      _subcategoryController.clear();
    });
  }

  void _startEditing(String subcategory) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};
    final amount = expenses[subcategory] ?? 0.0;

    setState(() {
      _isEditing = true;
      _editingSubcategory = subcategory;
      _nameControllers[subcategory] = TextEditingController(text: subcategory);
      _amountControllers[subcategory] = TextEditingController(text: amount.toStringAsFixed(2));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _expansionController.expand();
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingSubcategory = null;
      _errorMessage = null;
      _nameControllers.remove(_editingSubcategory);
      _amountControllers.remove(_editingSubcategory);
    });
  }

  Future<void> _addSubcategory() async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};

    final subcategory = _subcategoryController.text.trim();
    final error = _service.validateSubcategoryName(subcategory, expenses, null);

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final now = DateTime.now();
      await _service.addSubcategory(
        context: context,
        userId: authProvider.user!.uid,
        year: now.year,
        month: now.month,
        categoryName: widget.categoryName,
        subcategory: subcategory,
        amount: 0.0,
      );
      setState(() {
        _isAdding = false;
        _errorMessage = null;
        _subcategoryController.clear();
      });
    }
  }

  Future<void> _updateSubcategory(String oldSubcategory) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};

    final newSubcategory = _nameControllers[oldSubcategory]!.text.trim();
    final amountText = _amountControllers[oldSubcategory]!.text.trim();

    final nameError = _service.validateSubcategoryName(newSubcategory, expenses, oldSubcategory);
    final amountError = _service.validateAmount(amountText);

    if (nameError != null) {
      setState(() {
        _errorMessage = nameError;
      });
      return;
    }
    if (amountError != null) {
      setState(() {
        _errorMessage = amountError;
      });
      return;
    }

    final amount = double.parse(amountText);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final now = DateTime.now();
      await _service.updateSubcategory(
        context: context,
        userId: authProvider.user!.uid,
        year: now.year,
        month: now.month,
        categoryName: widget.categoryName,
        oldSubcategory: oldSubcategory,
        newSubcategory: newSubcategory,
        amount: amount,
      );
      setState(() {
        _isEditing = false;
        _editingSubcategory = null;
        _errorMessage = null;
        _nameControllers.remove(oldSubcategory);
        _amountControllers.remove(oldSubcategory);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final budget = budgetProvider.budget;

    final expenses = budget?.expenses[widget.categoryName] ?? {};
    final Map<String, double> displayedExpenses = {};
    expenses.forEach((subcategory, value) {
      final displaySubcategory = subcategory == 'default' ? widget.categoryName : subcategory;
      displayedExpenses[displaySubcategory] = value;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Säilytetään kortin taustaväri valkoisena
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(),
        child: ExpansionTile(
          key: _expansionTileKey,
          controller: _expansionController,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            getCategoryIcon(widget.categoryName),
            color: Colors.blueGrey,
            size: 24,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.categoryName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: _startAdding,
              ),
            ],
          ),
          children: [
            if (_isAdding)
              AddSubcategoryForm(
                controller: _subcategoryController,
                errorMessage: _errorMessage,
                onAdd: _addSubcategory,
                onCancel: _cancelAdding,
              ),
            BudgetCategoryList(
              categoryName: widget.categoryName,
              displayedExpenses: displayedExpenses,
              isEditing: _isEditing,
              editingSubcategory: _editingSubcategory,
              nameControllers: _nameControllers,
              amountControllers: _amountControllers,
              errorMessage: _errorMessage,
              service: _service,
              onCancelEditing: _cancelEditing,
              onStartEditing: _startEditing,
              onUpdateSubcategory: _updateSubcategory,
            ),
          ],
        ),
      ),
    );
  }
}