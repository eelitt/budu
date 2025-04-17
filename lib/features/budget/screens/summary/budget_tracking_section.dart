import 'package:budu/core/constants.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetTrackingSection extends StatelessWidget {
  const BudgetTrackingSection({super.key});

  Color _getProgressColor(String categoryName, double progress) {
    if (progress > 1) return Colors.red; // Ylitys aina punainen
    switch (categoryName) {
      case "Asuminen":
        return Colors.green;
      case "Liikkuminen":
        return Colors.blue;
      case "Kodin kulut":
        return Colors.orange;
      case "Viihde":
        return Colors.pink;
      case "Harrastukset":
        return Colors.cyan;
      case "Ruoka":
        return Colors.purple;
      case "Terveys":
        return Colors.redAccent;
      case "Hygienia":
        return Colors.teal;
      case "Lemmikit":
        return Colors.brown;
      case "Sijoittaminen":
        return Colors.lightGreen;
      case "Velat":
        return Colors.black;
      default:
        return Colors.grey; // "Muut"-kategoria
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    final categoryTotals = expenseProvider.getCategoryTotals();
    final budget = budgetProvider.budget!;

    final allMappedCategories = categoryMapping.values.expand((categories) => categories).toSet();
    final List<MapEntry<String, double>> unmappedExpenses = budget.expenses.entries
        .where((entry) => !allMappedCategories.contains(entry.key))
        .toList();
    final double unmappedBudget = unmappedExpenses.fold<double>(0.0, (sum, e) => sum + e.value);
    final double unmappedSpent = categoryTotals.entries
        .where((e) => !allMappedCategories.contains(e.key))
        .fold<double>(0.0, (sum, e) => sum + e.value);
    final double unmappedProgress = unmappedBudget > 0 ? unmappedSpent / unmappedBudget : 0.0;
    final double unmappedRemainingPercentage = unmappedBudget > 0
        ? ((unmappedBudget - unmappedSpent) / unmappedBudget * 100).clamp(0, 100)
        : 0.0;

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text('Budjettiseuranta', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 16),
          ...categoryMapping.entries.map((categoryEntry) {
            final categoryName = categoryEntry.key;
            final subCategories = categoryEntry.value;
            final categoryExpenses = budget.expenses.entries
                .where((entry) => subCategories.contains(entry.key))
                .toList();

            // Lasketaan suoraan kategorian budjetti ja kulutus, jos alakategorioita ei ole
            final directCategoryBudget = budget.expenses[categoryName] ?? 0.0;
            final directCategorySpent = categoryTotals[categoryName] ?? 0.0;

            // Piilotetaan vain, jos ei ole alakategorioita eikä suoraa budjettia/kulutusta
            if (subCategories.isEmpty && directCategoryBudget == 0.0 && directCategorySpent == 0.0) {
              return const SizedBox.shrink();
            }

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

            return Material(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 0),
                leading: Icon(
                  categoryName == "Asuminen"
                      ? Icons.home
                      : categoryName == "Liikkuminen"
                          ? Icons.directions_car
                          : categoryName == "Kodin kulut"
                              ? Icons.power
                              : categoryName == "Viihde"
                                  ? Icons.movie
                                  : categoryName == "Harrastukset"
                                      ? Icons.sports
                                      : categoryName == "Ruoka"
                                          ? Icons.fastfood
                                          : categoryName == "Terveys"
                                              ? Icons.local_hospital
                                              : categoryName == "Hygienia"
                                                  ? Icons.cleaning_services
                                                  : categoryName == "Lemmikit"
                                                      ? Icons.pets
                                                      : categoryName == "Sijoittaminen"
                                                          ? Icons.savings
                                                          : categoryName == "Velat"
                                                              ? Icons.money_off
                                                              : Icons.category,
                  color: Colors.blueGrey,
                  size: 24,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          categoryName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(categoryName, progress)),
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
                  final subRemainingPercentage = budgetAmount > 0
                      ? ((budgetAmount - spentAmount) / budgetAmount * 100).clamp(0, 100)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                subCategory,
                                style: Theme.of(context).textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '${formatCurrency(spentAmount)} / ${formatCurrency(budgetAmount)}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: subProgress > 1 ? 1 : subProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(categoryName, subProgress)),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),
          if (unmappedExpenses.isNotEmpty) ...[
            Material(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 0),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 0),
                leading: const Icon(
                  Icons.category,
                  color: Colors.blueGrey,
                  size: 24,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          'Muut',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Text(
                      '${formatCurrency(unmappedSpent)} / ${formatCurrency(unmappedBudget)}',
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
                      value: unmappedProgress > 1 ? 1 : unmappedProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor('Muut', unmappedProgress)),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${unmappedRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
                children: unmappedExpenses.map((entry) {
                  final subCategory = entry.key;
                  final budgetAmount = entry.value;
                  final spentAmount = categoryTotals[subCategory] ?? 0.0;
                  final subProgress = budgetAmount > 0 ? spentAmount / budgetAmount : 0.0;
                  final subRemainingPercentage = budgetAmount > 0
                      ? ((budgetAmount - spentAmount) / budgetAmount * 100).clamp(0, 100)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                subCategory,
                                style: Theme.of(context).textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '${formatCurrency(spentAmount)} / ${formatCurrency(budgetAmount)}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: subProgress > 1 ? 1 : subProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor('Muut', subProgress)),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}