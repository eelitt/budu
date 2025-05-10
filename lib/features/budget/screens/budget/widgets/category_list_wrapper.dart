import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_category_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoryListWrapper extends StatefulWidget {
  final BudgetModel budget;

  const CategoryListWrapper({super.key, required this.budget});

  @override
  State<CategoryListWrapper> createState() => _CategoryListWrapperState();
}

class _CategoryListWrapperState extends State<CategoryListWrapper> {
  late Map<String, Map<String, double>> expenses;

  @override
  void initState() {
    super.initState();
    expenses = Map.from(widget.budget.expenses);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
        final budget = budgetProvider.budget;
        if (budget != null) {
          // Päivitetään expenses-arvo reaaliajassa BudgetProvider-tilasta
          expenses = Map.from(budget.expenses);
        }

        final sortedCategories = expenses.keys.toList()..sort();
        final List<Widget> categoryWidgets = [];
        for (int i = 0; i < sortedCategories.length; i++) {
          final categoryName = sortedCategories[i];
          categoryWidgets.add(BudgetCategorySection(categoryName: categoryName));
          if (i < sortedCategories.length - 1) {
            categoryWidgets.add(const SizedBox(height: 16));
          }
        }
        return Column(children: categoryWidgets);
      },
    );
  }
}