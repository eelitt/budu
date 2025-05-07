import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/category_expansion_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetTrackingSection extends StatefulWidget {
  const BudgetTrackingSection({super.key});

  @override
  State<BudgetTrackingSection> createState() => _BudgetTrackingSectionState();
}

class _BudgetTrackingSectionState extends State<BudgetTrackingSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    final categoryTotals = expenseProvider.getCategoryTotals();
    final budget = budgetProvider.budget!;

    final allMappedCategories = categoryMapping.values.expand((categories) => categories).toSet();
    final mappedMainCategories = categoryMapping.keys.toSet();
    final unmappedCategories = budget.expenses.keys
        .where((key) => !allMappedCategories.contains(key) && !mappedMainCategories.contains(key))
        .toList();

    unmappedCategories.sort();

    final Map<String, double> unmappedExpenses = {};
    for (var category in unmappedCategories) {
      final subcategories = budget.expenses[category]!;
      final categoryTotal = subcategories.values.fold(0.0, (sum, value) => sum + value);
      unmappedExpenses[category] = categoryTotal;
    }
    final double unmappedBudget = unmappedExpenses.values.fold(0.0, (sum, value) => sum + value);
    final double unmappedSpent = categoryTotals.entries
        .where((e) => unmappedCategories.contains(e.key))
        .fold<double>(0.0, (sum, e) => sum + e.value);

    final List<MapEntry<String, List<String>>> sortedCategories = categoryMapping.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final List<Widget> categoryWidgets = sortedCategories.map((categoryEntry) {
      final categoryName = categoryEntry.key;
      final subCategories = categoryEntry.value;

      double directCategoryBudget = 0.0;
      if (budget.expenses.containsKey(categoryName)) {
        directCategoryBudget = budget.expenses[categoryName]!.values.fold(0.0, (sum, value) => sum + value);
      }

      final categoryExpenses = budget.expenses.containsKey(categoryName)
          ? budget.expenses[categoryName]!.entries.map((e) => MapEntry(e.key, e.value)).toList()
          : <MapEntry<String, double>>[];

      categoryExpenses.sort((a, b) => a.key.compareTo(b.key));

      final categoryBudget = subCategories.isNotEmpty
          ? categoryExpenses.fold<double>(0.0, (sum, e) => sum + e.value)
          : directCategoryBudget;
      final categorySpent = categoryTotals[categoryName] ?? 0.0;

      if (categoryBudget == 0.0 && categorySpent == 0.0) {
        return const SizedBox.shrink();
      }

      return CategoryExpansionTile(
        categoryName: categoryName,
        categoryBudget: categoryBudget,
        categorySpent: categorySpent,
        categoryExpenses: categoryExpenses,
      );
    }).toList();

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
      padding: const EdgeInsets.all(6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (bool expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: EdgeInsets.zero, // Poistetaan oletusmarginaalit
          leading: const Padding(
            padding: EdgeInsets.only(left: 4), // Siirretään ikonia lähemmäs vasenta reunaa
            child: Icon(Icons.pie_chart, color: Colors.blueGrey),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8), // Lisätään pieni marginaali otsikon vasempaan reunaan
            child: Text(
              'Budjettiseuranta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          trailing: const Padding(
            padding: EdgeInsets.only(right: 10), // Siirretään laajennus/supistus-ikonia lähemmäs oikeaa reunaa
            child: Icon(Icons.expand_more), // Flutter lisää tämän automaattisesti, mutta varmistetaan oikea ikoni
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(10), // Siirretään padding tänne, jotta se vaikuttaa vain laajennettuun sisältöön
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 
                  ...categoryWidgets,
                  if (unmappedExpenses.isNotEmpty)
                    CategoryExpansionTile(
                      categoryName: 'Muut',
                      categoryBudget: unmappedBudget,
                      categorySpent: unmappedSpent,
                      unmappedExpenses: unmappedExpenses.entries.toList(),
                      isUnmappedCategory: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}