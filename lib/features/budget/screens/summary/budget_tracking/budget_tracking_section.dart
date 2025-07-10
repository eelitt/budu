import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/category_expansion_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class BudgetTrackingSection extends StatefulWidget {
  final BudgetModel budget; // Valittu budjetti SummaryScreen:ltä

  const BudgetTrackingSection({
    super.key,
    required this.budget,
  });

  @override
  State<BudgetTrackingSection> createState() => _BudgetTrackingSectionState();
}

class _BudgetTrackingSectionState extends State<BudgetTrackingSection> {
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
   // Suorita tapahtumien lataus build-vaiheen jälkeen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExpenses();
      }
    });
  }

  /// Lataa tapahtumat oikealle budjetille
  Future<void> _loadExpenses() async {
    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        await expenseProvider.loadExpenses(authProvider.user!.uid, widget.budget.id!);
      }
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to load expenses for budget ${widget.budget.id}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapahtumien lataus epäonnistui: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    final categoryTotals = expenseProvider.getCategoryTotals();
    // Tarkistetaan, onko budjetti olemassa
    if (budgetProvider.budget == null) {
      return const Center(
        child: Text(
          'Budjettia ei ole saatavilla. Luo budjetti ensin.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }
    final budget = budgetProvider.budget!;

    // Haetaan budjetin kategoriat suoraan budjetista
    final budgetCategories = budget.expenses.keys.toList()..sort();

    // Luo kategoriat widgetit
    final List<Widget> categoryWidgets = budgetCategories.map((categoryName) {
      final categoryExpenses = budget.expenses[categoryName]!.entries
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final categoryBudget = categoryExpenses.fold<double>(0.0, (sum, e) => sum + e.value);
      final categorySpent = categoryTotals[categoryName] ?? 0.0;

      return CategoryExpansionTile(
        categoryName: categoryName,
        categoryBudget: categoryBudget,
        categorySpent: categorySpent,
        categoryExpenses: categoryExpenses,
        budgetId: widget.budget.id!, // Välitetään budjetin ID
      );
    }).toList();

    // Lasketaan kokonaisbudjetti ja käytetyt summat
    final totalBudget = budgetCategories.fold<double>(
        0.0, (sum, category) => sum + budget.expenses[category]!.values.fold(0.0, (s, v) => s + v));
    final totalSpent = budgetCategories.fold<double>(
        0.0, (sum, category) => sum + (categoryTotals[category] ?? 0.0));

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
            if (mounted) {
              setState(() {
                _isExpanded = expanded;
              });
            }
          },
          tilePadding: EdgeInsets.zero,
          leading: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.assignment_outlined, color: Colors.blueGrey),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budjettiseuranta',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (budgetCategories.isNotEmpty) // Näytetään vain, jos kategorioita on
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${budgetCategories.length} kategoria${budgetCategories.length == 1 ? '' : 'a'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...categoryWidgets,
                  if (budgetCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Yhteensä: ${totalSpent.toStringAsFixed(2)} / ${totalBudget.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: totalSpent > totalBudget ? Colors.red : Colors.black87,
                            ),
                      ),
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