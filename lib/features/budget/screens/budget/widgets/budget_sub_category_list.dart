import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/budget_category_controller.dart';
import 'package:budu/features/budget/screens/budget/widgets/budget_sub_category_dialogs.dart';
import 'package:budu/features/budget/screens/budget/widgets/edit_subcategory_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetSubCategoryList extends StatelessWidget {
  final String categoryName;
  final Map<String, double> displayedExpenses;
  final bool isEditing;
  final bool isSaving;
  final String? editingSubcategory;
  final String? newlyAddedSubcategory;
  final Map<String, TextEditingController> nameControllers;
  final Map<String, TextEditingController> amountControllers;
  final String? errorMessage;
  final BudgetCategoryController service;
  final VoidCallback onCancelEditing;
  final Function(String, BuildContext) onStartEditing; // Päivitetty tyyppi
  final Function(String) onUpdateSubcategory;

  const BudgetSubCategoryList({
    super.key,
    required this.categoryName,
    required this.displayedExpenses,
    required this.isEditing,
    required this.isSaving,
    required this.editingSubcategory,
    required this.newlyAddedSubcategory,
    required this.nameControllers,
    required this.amountControllers,
    required this.errorMessage,
    required this.service,
    required this.onCancelEditing,
    required this.onStartEditing,
    required this.onUpdateSubcategory,
  });

  @override
  Widget build(BuildContext context) {
    final entries = displayedExpenses.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final List<Widget> subcategoryWidgets = entries.map((entry) {
      final subcategory = entry.key;
      final amount = entry.value;
      final isNewlyAdded = subcategory == newlyAddedSubcategory;
      final isCurrentlySaving = isSaving && (subcategory == newlyAddedSubcategory || subcategory == editingSubcategory);

      return AnimatedContainer(
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isNewlyAdded ? Colors.blueGrey[50] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: isEditing && editingSubcategory == subcategory
                  ? EditSubcategoryForm(
                      nameController: nameControllers[subcategory]!,
                      amountController: amountControllers[subcategory]!,
                      onSave: () => onUpdateSubcategory(subcategory),
                      onCancel: onCancelEditing,
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        subcategory,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54, fontSize: 14),
                      ),
                    ),
            ),
            Row(
              children: [
                if (!(isEditing && editingSubcategory == subcategory)) ...[
                  if (isCurrentlySaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Text(
                      '${amount.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54, fontSize: 12),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => onStartEditing(subcategory, context), // Välitetään context
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () async {
                      final deleteEvents = await confirmDeleteSubcategory(
                        context: context,
                        subcategory: subcategory,
                        categoryName: categoryName,
                      );
                      if (!deleteEvents) return;

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      if (authProvider.user != null) {
                        final now = DateTime.now();
                        await service.deleteSubcategory(
                          context: context,
                          userId: authProvider.user!.uid,
                          year: now.year,
                          month: now.month,
                          categoryName: categoryName,
                          subcategory: subcategory,
                          deleteEvents: deleteEvents,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }).toList();

    return Column(
      children: [
        ...subcategoryWidgets,
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}