import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/summary_event_tile.dart';
import 'package:budu/features/budget/screens/summary/summary_section_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Expandable event list for the selected Summary budget (supports delete).
class EventsSection extends StatefulWidget {
  final BudgetModel budget;
  final bool isSharedBudget;

  const EventsSection({
    super.key,
    required this.budget,
    required this.isSharedBudget,
  });

  @override
  State<EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends State<EventsSection> {
  bool _isExpanded = true;

  Future<void> _confirmAndDelete(
    ExpenseEvent expense,
    ExpenseProvider expenseProvider,
    String userId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        title: Text(
          'Poista tapahtuma',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Haluatko varmasti poistaa tapahtuman "${expense.category}${expense.subcategory != null && expense.subcategory!.isNotEmpty ? ' (${expense.subcategory})' : ''}" (${formatCurrency(expense.amount)})?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: Text(
              'Peruuta',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            child: Text(
              'Poista',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await expenseProvider.deleteExpense(
        userId,
        expense.id,
        budgetId: widget.budget.id!,
        isSharedBudget: widget.isSharedBudget,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Virhe poistettaessa tapahtumaa: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final events = expenseProvider.expenses;

    return SummarySectionCard(
      padding: const EdgeInsets.all(8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) =>
              setState(() => _isExpanded = expanded),
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
                  if (events.isEmpty)
                    const Text('Ei vielä tapahtumia.')
                  else
                    ...events.asMap().entries.map((entry) {
                      final index = entry.key;
                      final expense = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : 12,
                          bottom: index == events.length - 1 ? 0 : 12,
                        ),
                        child: SummaryEventTile(
                          expense: expense,
                          onDelete: () {
                            final user = authProvider.user;
                            if (user == null) return;
                            _confirmAndDelete(
                              expense,
                              expenseProvider,
                              user.uid,
                            );
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
