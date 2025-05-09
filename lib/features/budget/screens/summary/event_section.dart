import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EventsSection extends StatefulWidget {
  const EventsSection({super.key});

  @override
  State<EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends State<EventsSection> {
  bool _isExpanded = true; // Oletuksena lohko on laajennettu

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
      padding: const EdgeInsets.all(8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (bool expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: EdgeInsets.zero,
          leading: const Padding(
            padding: EdgeInsets.only(left: 1),
            child: Icon(Icons.attach_money, color: Colors.blueGrey),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Tapahtumat',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          trailing: const Padding(
            padding: EdgeInsets.only(right: 11),
            child: Icon(Icons.expand_more),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
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
                                      color: Colors.black.withValues(alpha: 0.1),
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
                                              if (expense.subcategory != null && expense.subcategory!.isNotEmpty)
                                                Text(
                                                  expense.subcategory!,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: Colors.black54,
                                                      ),
                                                ),
                                              if (expense.subcategory != null && expense.subcategory!.isNotEmpty)
                                                const SizedBox(height: 4),
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
            ),
          ],
        ),
      ),
    );
  }
}