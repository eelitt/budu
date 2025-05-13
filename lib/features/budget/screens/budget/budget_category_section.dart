import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_category_controller.dart';
import 'package:budu/features/budget/screens/budget/utils/category_icon_utils.dart';
import 'package:budu/features/budget/screens/budget/utils/delete_dialog_state_manager.dart';
import 'package:budu/features/budget/screens/budget/utils/expansion_state_manager.dart';
import 'package:budu/features/budget/screens/budget/widgets/add_subcategory_form.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_custom_category_tile.dart';
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
  final GlobalKey _expansionTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = BudgetCategoryController();
    _expansionStateManager = ExpansionStateManager(
      categoryName: widget.categoryName,
      isExpanded: _isExpanded,
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

          final subcategoryCount = displayedExpenses.length;

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
            child: CustomExpansionTile(
              key: _expansionTileKey,
              isExpanded: _isExpanded,
              onExpansionChanged: (expanded) {
                _isExpanded.value = expanded;
                _expansionStateManager.saveExpansionState(expanded, isManual: true);
              },
              title: Stack(
                children: [
                  // Kategorian ikoni vasemmassa yläkulmassa
                  Positioned(
                    left: 12,
                    top: 4,
                    child: Icon(
                      getCategoryIcon(widget.categoryName),
                      color: Colors.blueGrey,
                      size: 24,
                    ),
                  ),
                  // Ala-kategorioiden määrä kategorian ikonin oikealla puolella
                  Positioned(
                    left: 40, // Asetetaan kategorian ikonin (24 px leveä + 4 px väli) oikealle puolelle
                    top: 4,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isExpanded,
                      builder: (context, isExpanded, child) {
                        if (isExpanded) return const SizedBox.shrink(); // Ei näytetä, kun laajennettu
                        return Text(
                          'Ala-kategorioita: $subcategoryCount', // Näyttää ala-kategorioiden määrän
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        );
                      },
                    ),
                  ),
                  // Laajennus/supistus-ikoni oikeassa yläkulmassa
                  Positioned(
                    right: 4,
                    top: 4,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isExpanded,
                      builder: (context, isExpanded, child) {
                        return AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0, // 0.5 = 180 astetta
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.linear,
                          child: Icon(
                           Icons.expand_more,
                            color: Colors.blueGrey,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                  // Kategorian nimi ja toimintopainikkeet ikonin alapuolella
                  Padding(
                    padding: const EdgeInsets.only(top: 34, left: 16, right: 2, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.categoryName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: _handleStartAdding,
                              padding: const EdgeInsets.only(right: 4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () async {
                                final shouldShowDialog = await _deleteDialogStateManager.shouldShowDeleteDialog();
                                if (!shouldShowDialog) {
                                  await controller.deleteCategory(context, widget.categoryName);
                                  showSnackBar(
                                    context,
                                    'Kategoria "${widget.categoryName}" poistettu onnistuneesti!',
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
                                    'Kategoria "${widget.categoryName}" poistettu onnistuneesti!',
                                    duration: const Duration(seconds: 2),
                                  );
                                }
                              },
                              tooltip: 'Poista kategoria',
                              padding: const EdgeInsets.only(left: 4),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                if (controller.isAdding)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16), // Lisätty top padding
                    child: AddSubcategoryForm(
                      controller: controller.subcategoryController,
                      errorMessage: controller.errorMessage,
                      onAdd: () => controller.addSubcategory(context, widget.categoryName),
                      onCancel: controller.cancelAdding,
                    ),
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
            ),
          );
        },
      ),
    );
  }
}