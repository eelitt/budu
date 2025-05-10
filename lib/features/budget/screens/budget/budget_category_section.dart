import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_category_controller.dart';
import 'package:budu/features/budget/screens/budget/utils/category_icon_utils.dart';
import 'package:budu/features/budget/screens/budget/utils/delete_dialog_state_manager.dart';
import 'package:budu/features/budget/screens/budget/utils/expansion_state_manager.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_subcategory_form.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_sub_category_list.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_confirmation_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetCategorySection extends StatefulWidget {
  final String categoryName;

  const BudgetCategorySection({super.key, required this.categoryName});

  @override
  State<BudgetCategorySection> createState() => _BudgetCategorySectionState();
}

class _BudgetCategorySectionState extends State<BudgetCategorySection> {
  late BudgetCategoryController _controller;
  late ExpansionStateManager _expansionStateManager;
  late DeleteDialogStateManager _deleteDialogStateManager;
  final ValueNotifier<bool> _isExpanded = ValueNotifier<bool>(false);
  final ExpansionTileController _expansionController = ExpansionTileController();
  final GlobalKey _expansionTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = BudgetCategoryController();
    _expansionStateManager = ExpansionStateManager(
      categoryName: widget.categoryName,
      isExpanded: _isExpanded,
      expansionController: _expansionController,
    );
    _deleteDialogStateManager = DeleteDialogStateManager();
    _expansionStateManager.loadExpansionState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _isExpanded.dispose();
    super.dispose();
  }

  void _handleStartAdding() {
    _controller.startAdding(context, widget.categoryName);
    _expansionStateManager.expandProgrammatically();
  }

  void _handleStartEditing(String subcategory, BuildContext context) {
    _controller.startEditing(subcategory, context);
    _expansionStateManager.expandProgrammatically();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableProvider<BudgetCategoryController>.value(
      value: _controller,
      child: Consumer2<BudgetCategoryController, BudgetProvider>(
        builder: (context, controller, budgetProvider, child) {
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
                    initiallyExpanded: false,
                    onExpansionChanged: (expanded) {
                      _expansionStateManager.saveExpansionState(expanded, isManual: true);
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
                              onPressed: _handleStartAdding,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                              onPressed: () async {
                                final shouldShowDialog = await _deleteDialogStateManager.shouldShowDeleteDialog();
                                if (!shouldShowDialog) {
                                  await controller.deleteCategory(context, widget.categoryName);
                                  showSnackBar(
                                    context,
                                    'Kategoria "${widget.categoryName}" poistettu!',
                                    duration: const Duration(seconds: 2),
                                  );
                                  return;
                                }

                                final result = await showDeleteConfirmationDialog(
                                  context: context,
                                  isLastBudget: false,
                                  customMessage: 'Haluatko varmasti poistaa kategorian "${widget.categoryName}" ja kaikki sen alakategoriat? Kategoria poistetaan budjetistasi, mutta voit lisätä sen takaisin myöhemmin.',
                                  onDontShowAgainChanged: (dontShowAgain) async {
                                    await _deleteDialogStateManager.setShowDeleteDialog(!dontShowAgain);
                                  },
                                );

                                if (result == true) {
                                  await controller.deleteCategory(context, widget.categoryName);
                                  showSnackBar(
                                    context,
                                    'Kategoria "${widget.categoryName}" poistettu!',
                                    duration: const Duration(seconds: 2),
                                  );
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
                      if (controller.isAdding)
                        AddSubcategoryForm(
                          controller: controller.subcategoryController,
                          errorMessage: controller.errorMessage,
                          onAdd: () => controller.addSubcategory(context, widget.categoryName),
                          onCancel: controller.cancelEditing,
                        ),
                      BudgetSubCategoryList(
                        categoryName: widget.categoryName,
                        displayedExpenses: displayedExpenses,
                        isEditing: controller.isEditing,
                        isSaving: controller.isSaving,
                        editingSubcategory: controller.editingSubcategory,
                        newlyAddedSubcategory: controller.newlyAddedSubcategory,
                        nameControllers: controller.nameControllers,
                        amountControllers: controller.amountControllers,
                        errorMessage: controller.errorMessage,
                        service: controller,
                        onCancelEditing: controller.cancelEditing,
                        onStartEditing: _handleStartEditing,
                        onUpdateSubcategory: (oldSubcategory) =>
                            controller.updateSubcategory(context, widget.categoryName, oldSubcategory),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}