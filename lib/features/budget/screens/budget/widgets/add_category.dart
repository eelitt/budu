import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/budget/screens/budget/controllers/shared_budget_screen_controller.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_dialog.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka vastaa kategorian lisäämisestä budjettiin.
/// Näyttää "Lisää kategoria" -painikkeen ja käsittelee kategorian lisäyksen Firestoreen.
/// Rajoittaa kategorioiden määrän 25:een ja näyttää harmaan painikkeen, jos raja on saavutettu.
class AddCategory extends StatelessWidget {
  final bool isSharedBudget;
  final BudgetModel? selectedSharedBudget;
  final SharedBudgetScreenController sharedController;

  const AddCategory({
    super.key,
    this.isSharedBudget = false,
    this.selectedSharedBudget,
    required this.sharedController,
  });

  /// Validoi kategorian nimen ennen lisäystä.
  String? _validateCategoryName(String categoryName, Map<String, Map<String, double>> expenses) {
    if (categoryName.isEmpty) {
      return 'Syötä kategorian nimi';
    }
    if (categoryName.length > 25) {
      return 'Nimi voi olla enintään 25 merkkiä pitkä';
    }
    if (expenses.containsKey(categoryName)) {
      return 'Kategorian nimi on jo käytössä';
    }
    return null;
  }

  /// Lisää uuden kategorian budjettiin Firestoreen.
  /// [categoryName] on lisättävän kategorian nimi.
  Future<void> _addCategory(BuildContext context, String categoryName) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
      final expenses = isSharedBudget ? selectedSharedBudget?.expenses ?? {} : budgetProvider.budget?.expenses ?? {};

      // Validoidaan kategorian nimi
      final error = _validateCategoryName(categoryName, expenses);
      if (error != null) {
        if (context.mounted) {
          showErrorSnackBar(context, error);
        }
        return;
      }

      if (authProvider.user == null) {
        throw Exception('Käyttäjä ei ole kirjautunut');
      }

      if (isSharedBudget && selectedSharedBudget != null) {
        // Yhteistalousbudjetti
        final budget = selectedSharedBudget!;
        final updatedExpenses = Map<String, Map<String, double>>.from(budget.expenses);
        updatedExpenses[categoryName] = {};
        await sharedBudgetProvider.updateSharedBudget(
          sharedBudgetId: budget.id.toString(),
          income: budget.income,
          expenses: updatedExpenses,
          startDate: budget.startDate,
          endDate: budget.endDate,
          type: budget.type,
          isPlaceholder: budget.isPlaceholder,
        );
        // Päivitä SharedBudgetScreenController.selectedBudget
        if (context.mounted) {
          sharedController.updateSelectedBudget(budget.id.toString());
        }
      } else if (budgetProvider.budget?.id != null) {
        // Henkilökohtainen budjetti
        await budgetProvider.addCategory(
          userId: authProvider.user!.uid,
          budgetId: budgetProvider.budget!.id!,
          category: categoryName,
        );
      } else {
        throw Exception('Budjettia ei ole valittu');
      }

      if (context.mounted) {
        showSnackBar(
          context,
          'Kategoria "$categoryName" lisätty onnistuneesti',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        );
      }
      await FirebaseCrashlytics.instance.log('AddCategory: Kategoria "$categoryName" lisätty, isSharedBudget: $isSharedBudget');
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Kategorian lisääminen epäonnistui AddCategory:ssä, isSharedBudget: $isSharedBudget',
      );
      if (context.mounted) {
        showErrorSnackBar(context, 'Kategorian lisääminen epäonnistui: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final expenses = isSharedBudget ? selectedSharedBudget?.expenses ?? {} : budgetProvider.budget?.expenses ?? {};
    final categoryCount = expenses.length;
    const maxCategories = 25;
    final isCategoryLimitReached = categoryCount >= maxCategories;

    if (!isSharedBudget && budgetProvider.budget == null) {
      return const SizedBox.shrink();
    }
    if (isSharedBudget && selectedSharedBudget == null) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: isCategoryLimitReached
          ? () {
              showSnackBar(
                context,
                'Kategorioiden maksimimäärä ($maxCategories) saavutettu.',
                duration: const Duration(seconds: 3),
              );
            }
          : () async {
              final selectedCategory = await showAddCategoryDialog(
                context: context,
                currentExpenses: expenses,
              );
              if (selectedCategory != null) {
                await _addCategory(context, selectedCategory);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isCategoryLimitReached ? Colors.grey[400] : Colors.blueGrey[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16),
          SizedBox(width: 4),
          Text('Lisää kategoria'),
        ],
      ),
    );
  }
}