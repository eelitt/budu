import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/services/budget_category_service.dart';
import 'package:budu/features/budget/screens/budget/utils/category_icon_utils.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_subcategory_form.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_category_list.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetCategorySection extends StatefulWidget {
  final String categoryName;

  const BudgetCategorySection({super.key, required this.categoryName});

  @override
  State<BudgetCategorySection> createState() => _BudgetCategorySectionState();
}

class _BudgetCategorySectionState extends State<BudgetCategorySection> {
  bool _isAdding = false;
  bool _isEditing = false;
  bool _isSaving = false; // Uusi tilamuuttuja tallennuksen tilan seuraamiseen
  String? _editingSubcategory;
  String? _newlyAddedSubcategory; // Uusi muuttuja juuri lisätyn alakategorian seuraamiseen
  final TextEditingController _subcategoryController = TextEditingController();
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  String? _errorMessage;
  final ExpansionTileController _expansionController = ExpansionTileController();
  final GlobalKey _expansionTileKey = GlobalKey();
  final BudgetCategoryService _service = BudgetCategoryService();
  ValueNotifier<bool> _isExpanded = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _loadExpansionState();
  }

  @override
  void dispose() {
    _subcategoryController.dispose();
    _nameControllers.values.forEach((controller) => controller.dispose());
    _amountControllers.values.forEach((controller) => controller.dispose());
    _isExpanded.dispose();
    super.dispose();
  }

  Future<void> _loadExpansionState() async {
    final prefs = await SharedPreferences.getInstance();
    final isExpanded = prefs.getBool('expansion_${widget.categoryName}') ?? false;
    _isExpanded.value = isExpanded;
    if (isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _expansionController.expand();
        }
      });
    }
  }

  Future<void> _saveExpansionState(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('expansion_${widget.categoryName}', expanded);
  }

  void _startAdding() {
    if (_isAdding) return; // Estetään useiden alakategorioiden samanaikainen lisääminen

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
    _isExpanded.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _expansionController.expand();
          }
        });
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
    if (_isEditing) return; // Estetään useiden muokkausten samanaikainen käynnistäminen

    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final expenses = budgetProvider.budget?.expenses[widget.categoryName] ?? {};
    final amount = expenses[subcategory] ?? 0.0;

    setState(() {
      _isEditing = true;
      _editingSubcategory = subcategory;
      _nameControllers[subcategory] = TextEditingController(text: subcategory);
      _amountControllers[subcategory] = TextEditingController(text: amount.toStringAsFixed(2));
    });
    _isExpanded.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _expansionController.expand();
          }
        });
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
      setState(() {
        _isSaving = true; // Asetetaan tallennustila
      });
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
        _isSaving = false; // Poistetaan tallennustila
        _errorMessage = null;
        _subcategoryController.clear();
        _newlyAddedSubcategory = subcategory; // Tallennetaan juuri lisätty alakategoria
      });
      _isExpanded.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _expansionController.expand();
            }
          });
        }
      });
      // Näytä vahvistusviesti
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alakategoria "$subcategory" lisätty onnistuneesti!'),
          duration: const Duration(seconds: 2),
        ),
      );
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
      setState(() {
        _isSaving = true; // Asetetaan tallennustila
      });
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
        _isSaving = false; // Poistetaan tallennustila
        _editingSubcategory = null;
        _errorMessage = null;
        _nameControllers.remove(oldSubcategory);
        _amountControllers.remove(oldSubcategory);
      });
      _isExpanded.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _expansionController.expand();
            }
          });
        }
      });
    }
  }

  Future<bool> _shouldShowDeleteDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('showDeleteCategoryDialog') ?? true;
  }

  Future<void> _setShowDeleteDialog(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showDeleteCategoryDialog', show);
  }

  Future<void> _deleteCategory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final now = DateTime.now();
      // Poistaa kategorian ja kaikki sen alakategoriat budjetista
      await budgetProvider.deleteExpense(
        userId: authProvider.user!.uid,
        year: now.year,
        month: now.month,
        category: widget.categoryName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final budget = budgetProvider.budget;

    final expenses = budget?.expenses[widget.categoryName] ?? {};
    final Map<String, double> displayedExpenses = {};
    expenses.forEach((subcategory, value) {
      final displaySubcategory = subcategory == 'default' ? widget.categoryName : subcategory;
      displayedExpenses[displaySubcategory] = value;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isExpanded,
          builder: (context, isExpanded, child) {
            return ExpansionTile(
              key: _expansionTileKey,
              controller: _expansionController,
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                _isExpanded.value = expanded;
                _saveExpansionState(expanded);
              },
              tilePadding: const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        getCategoryIcon(widget.categoryName),
                        color: Colors.blueGrey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.categoryName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: _startAdding,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                        onPressed: () async {
                          final shouldShowDialog = await _shouldShowDeleteDialog();
                          if (!shouldShowDialog) {
                            await _deleteCategory();
                            return;
                          }

                          final result = await showDeleteConfirmationDialog(
                            context: context,
                            isLastBudget: false,
                            customMessage: 'Haluatko varmasti poistaa kategorian "${widget.categoryName}" ja kaikki sen alakategoriat? Kategoria poistetaan budjetistasi, mutta voit lisätä sen takaisin myöhemmin.',
                            onDontShowAgainChanged: (dontShowAgain) async {
                              await _setShowDeleteDialog(!dontShowAgain);
                            },
                          );

                          if (result == true) {
                            await _deleteCategory();
                          }
                        },
                        tooltip: 'Poista kategoria',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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
                  isSaving: _isSaving, // Välitetään tallennustila
                  editingSubcategory: _editingSubcategory,
                  newlyAddedSubcategory: _newlyAddedSubcategory,
                  nameControllers: _nameControllers,
                  amountControllers: _amountControllers,
                  errorMessage: _errorMessage,
                  service: _service,
                  onCancelEditing: _cancelEditing,
                  onStartEditing: _startEditing,
                  onUpdateSubcategory: _updateSubcategory,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}