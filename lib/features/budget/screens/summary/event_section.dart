import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart'; // Lisätty BudgetProvider-importti
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EventsSection extends StatelessWidget {
  const EventsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false); // Lisätty BudgetProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
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
              const Icon(Icons.event, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text('Tapahtumat', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 16),
          expenseProvider.expenses.isEmpty
              ? const Text('Ei vielä tapahtumia.')
              : Column(
                  children: expenseProvider.expenses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final expense = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : 12,
                        bottom: index == expenseProvider.expenses.length - 1 ? 0 : 12,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.1),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            expense.type == EventType.income
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                            color: expense.type == EventType.income ? Colors.green : Colors.red,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          // Näytetään vain yläkategoria tässä
                                          Text(
                                            expense.category,
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (expense.description != null && expense.description!.isNotEmpty)
                                        Text(
                                          expense.description!,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.black54,
                                              ),
                                        ),
                                      if (expense.description != null && expense.description!.isNotEmpty)
                                        const SizedBox(height: 4),
                                      // Näytetään alakategoria, jos se on olemassa
                                      if (expense.subcategory != null && expense.subcategory!.isNotEmpty)
                                        Text(
                                          expense.subcategory!,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.black54,
                                              ),
                                        ),
                                      if (expense.subcategory != null && expense.subcategory!.isNotEmpty)
                                        const SizedBox(height: 4),
                                      // Näytetään päivämäärä
                                      Text(
                                        '${expense.createdAt.day}.${expense.createdAt.month}.${expense.createdAt.year} '
                                        '${expense.createdAt.hour}:${expense.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.black54,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  expense.type == EventType.income
                                      ? '+${formatCurrency(expense.amount)}'
                                      : '-${formatCurrency(expense.amount)}',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: expense.type == EventType.income ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Poista tapahtuma'),
                                        content: Text(
                                            'Haluatko varmasti poistaa tapahtuman "${expense.category}${expense.subcategory != null && expense.subcategory!.isNotEmpty ? ' (${expense.subcategory})' : ''}" (${formatCurrency(expense.amount)})?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Peruuta'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Poista'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        // Päivitetty: Lisätty budgetProvider-parametri deleteExpense-kutsuun
                                        await expenseProvider.deleteExpense(authProvider.user!.uid, expense.id, budgetProvider);
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Virhe poistettaessa tapahtumaa: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}