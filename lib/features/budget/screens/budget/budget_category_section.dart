import 'package:budu/core/constants.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'budget_subcategory_item.dart';

class BudgetCategorySection extends StatelessWidget {
  final String categoryName;

  const BudgetCategorySection({super.key, required this.categoryName});

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case "Asuminen":
        return Icons.home;
      case "Liikkuminen":
        return Icons.directions_car;
      case "Kodin kulut":
        return Icons.power;
      case "Viihde":
        return Icons.movie;
      case "Harrastukset":
        return Icons.sports;
      case "Ruoka":
        return Icons.fastfood;
      case "Terveys":
        return Icons.local_hospital;
      case "Hygienia":
        return Icons.cleaning_services;
      case "Lemmikit":
        return Icons.pets;
      case "Sijoittaminen":
        return Icons.savings;
      case "Velat":
        return Icons.money_off;
      case "Muut":
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final budget = budgetProvider.budget;
    if (budget == null) return const SizedBox.shrink();

    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categoryTotals = expenseProvider.getCategoryTotals();

    final subCategories = categoryMapping[categoryName] ?? [];
    final categoryExpenses = budget.expenses.entries
        .where((entry) => subCategories.contains(entry.key))
        .toList();

    // Lasketaan kategorian budjetti ja kulutus suoraan categoryName-avaimella, jos alakategorioita ei ole
    final directCategoryBudget = budget.expenses[categoryName] ?? 0.0;
    final directCategorySpent = categoryTotals[categoryName] ?? 0.0;

    // Jos ei ole alakategorioita eikä suoraa budjettia/kulutusta, piilotetaan kategoria
    if (subCategories.isEmpty && directCategoryBudget == 0.0 && directCategorySpent == 0.0) {
      return const SizedBox.shrink();
    }

    // Jos on alakategorioita, lasketaan niiden summa; muuten käytetään suoraa arvoa
    final categoryBudget = subCategories.isNotEmpty
        ? categoryExpenses.fold<double>(0.0, (sum, e) => sum + e.value)
        : directCategoryBudget;
    final categorySpent = subCategories.isNotEmpty
        ? categoryTotals.entries
            .where((e) => subCategories.contains(e.key))
            .fold<double>(0.0, (sum, e) => sum + e.value)
        : directCategorySpent;
    final progress = categoryBudget > 0 ? categorySpent / categoryBudget : 0.0;
    final remainingPercentage = categoryBudget > 0
        ? ((categoryBudget - categorySpent) / categoryBudget * 100).clamp(0, 100)
        : 100.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(
            _getCategoryIcon(categoryName),
            color: Colors.blueGrey,
            size: 24,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  categoryName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${formatCurrency(categorySpent)} / ${formatCurrency(categoryBudget)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress > 1 ? 1 : progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progress > 1 ? Colors.red : Colors.blue),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${remainingPercentage.toStringAsFixed(0)}% jäljellä',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
            ],
          ),
          children: categoryExpenses.map((entry) {
            final subCategory = entry.key;
            final budgetAmount = entry.value;
            final spentAmount = categoryTotals[subCategory] ?? 0.0;
            final subProgress = budgetAmount > 0 ? spentAmount / budgetAmount : 0.0;
            double subRemainingPercentage = budgetAmount > 0
                ? ((budgetAmount - spentAmount) / budgetAmount * 100).clamp(0, 100)
                : 100.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: BudgetSubcategoryItem(
                subCategory: subCategory,
                budgetAmount: budgetAmount,
                spentAmount: spentAmount,
                subProgress: subProgress,
                subRemainingPercentage: subRemainingPercentage,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}