import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class SummarySection extends StatelessWidget {
  final BudgetModel? selectedBudget; // Parametri valitulle budjetille

  const SummarySection({super.key, this.selectedBudget});

  /// Muotoilee budjetin aikavälin näyttöä varten (esim. "1.5.2025 - 31.5.2025").
  String _formatBudgetPeriod(BudgetModel budget) {
    final dateFormat = DateFormat('d.M.yyyy');
    return '${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    // Tarkistetaan, onko budjetti olemassa
    if (budgetProvider.budget == null) {
      // Näytetään viesti, jos budjettia ei ole saatavilla
      return const Center(
        child: Text(
          'Budjettia ei ole saatavilla. Luo budjetti ensin.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }
    final totalBudget = budgetProvider.budget!.totalExpenses; // Budjetoidut menot yhteensä
    final totalIncome = budgetProvider.budget!.income;
    final balance = totalIncome - totalBudget; // Saldo budjetoiduilla menoilla

    // Lasketaan ylittyneet kategoriat ja kokonaisylitys
    final categoryTotals = expenseProvider.getCategoryTotals();
    final List<MapEntry<String, double>> overBudgetCategories = [];
    double totalOverBudget = 0.0;

    budgetProvider.budget!.expenses.forEach((categoryName, subCategories) {
      final categoryBudget = subCategories.values.fold<double>(0.0, (sum, value) => sum + value);
      final categorySpent = categoryTotals[categoryName] ?? 0.0;
      final overBudgetAmount = categorySpent - categoryBudget;

      if (overBudgetAmount > 0) {
        overBudgetCategories.add(MapEntry(categoryName, overBudgetAmount));
        totalOverBudget += overBudgetAmount;
      }
    });

    // Lasketaan toteutuneet menot yhteensä ja korjattu saldo
    final totalSpent = categoryTotals.values.fold<double>(0.0, (sum, value) => sum + value);
    final adjustedBalance = totalIncome - totalSpent; // Saldo toteutuneilla menoilla

    // Onko kokonaisbudjetti ylittynyt?
    final isBudgetExceeded = totalSpent > totalBudget;

    // Onko budjetti alijäämäinen (budjetoidut menot > tulot)?
    final isBudgetDeficit = totalBudget > totalIncome;

    // Näytetään varoitusikoni, jos jokin kategoria on ylittynyt, kokonaisbudjetti on ylittynyt tai budjetti on alijäämäinen
    final showWarning = overBudgetCategories.isNotEmpty || isBudgetExceeded || isBudgetDeficit;

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Yhteenveto',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (showWarning) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.warning,
                            color: Colors.red,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    if (selectedBudget != null) // Näytetään vain, jos selectedBudget on määritelty
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${_formatBudgetPeriod(selectedBudget!)} budjetti',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward, color: Colors.green),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Tulot yhteensä',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  formatCurrency(totalIncome),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward, color: Colors.red),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Budjetoidut menot yhteensä',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  formatCurrency(totalBudget),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isBudgetDeficit ? Colors.red : Colors.black87,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isBudgetDeficit) ...[
            const SizedBox(height: 4),
            Text(
              'Menot ylittävät tulot!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward, color: Colors.red),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Toteutuneet menot yhteensä',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  formatCurrency(totalSpent),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: totalSpent > totalBudget ? Colors.red : Colors.black87,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isBudgetExceeded) ...[
            const SizedBox(height: 4),
            Text(
              'Budjetti ylittynyt!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          if (overBudgetCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ylittyneitä kategorioita: ${overBudgetCategories.length} (yhteensä ${formatCurrency(totalOverBudget)})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo (budjetoitu)'),
              Text(
                formatCurrency(balance),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: balance >= 0 ? Colors.green : Colors.red,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saldo (toteutunut)'),
              Text(
                formatCurrency(adjustedBalance),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: adjustedBalance >= 0 ? Colors.green : Colors.red,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}