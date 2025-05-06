import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);

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
              const Icon(Icons.account_balance_wallet, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text('Yhteenveto', style: Theme.of(context).textTheme.headlineSmall),
              // Päivitetty: Näytetään varoitusikoni myös, jos budjetti on alijäämäinen
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
                        // Päivitetty: Euromäärä punaisella, jos budjetti on alijäämäinen
                        color: isBudgetDeficit ? Colors.red : Colors.black87,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Lisätty: Varoitusteksti, jos budjetti on alijäämäinen
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
          // Varoitusteksti, jos kokonaisbudjetti on ylittynyt
          if (isBudgetExceeded) ...[
            const SizedBox(height: 4),
            Text(
              'Budjetti ylittynyt!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          // Ylittyneiden kategorioiden yhteenveto (tiivistetty)
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
              const Text('Saldo (budjetoitu)'), // Päivitetty otsikko
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