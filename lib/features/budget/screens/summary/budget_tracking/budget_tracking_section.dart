import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/category_expansion_tile.dart';
import 'package:budu/features/budget/screens/summary/summary_section_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Plan vs actual by category for the selected Summary budget.
class BudgetTrackingSection extends StatefulWidget {
  final BudgetModel budget;
  final bool isSharedBudget;
  final String? focusedCategory;
  final int focusToken;

  const BudgetTrackingSection({
    super.key,
    required this.budget,
    this.isSharedBudget = false,
    this.focusedCategory,
    this.focusToken = 0,
  });

  @override
  State<BudgetTrackingSection> createState() => _BudgetTrackingSectionState();
}

class _BudgetTrackingSectionState extends State<BudgetTrackingSection> {
  bool _isExpanded = true;
  final Map<String, GlobalKey> _categoryKeys = {};

  GlobalKey _keyFor(String categoryName) {
    return _categoryKeys.putIfAbsent(categoryName, GlobalKey.new);
  }

  @override
  void didUpdateWidget(BudgetTrackingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusToken > 0 &&
        widget.focusToken != oldWidget.focusToken &&
        widget.focusedCategory != null) {
      setState(() => _isExpanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _categoryKeys[widget.focusedCategory!]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categoryTotals = expenseProvider.getCategoryTotals();
    final budget = widget.budget;

    final budgetCategories = budget.expenses.keys.toList()..sort();
    final plannedKeys = budget.expenses.keys.toSet();

    // Include unplanned categories that have spend so chips can scroll to them.
    final unplannedWithSpend = categoryTotals.keys
        .where((name) => !plannedKeys.contains(name))
        .toList()
      ..sort();

    final categoryWidgets = <Widget>[];

    for (final categoryName in budgetCategories) {
      final categoryExpenses = budget.expenses[categoryName]!.entries
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final categoryBudget =
          categoryExpenses.fold<double>(0.0, (sum, e) => sum + e.value);
      final categorySpent = categoryTotals[categoryName] ?? 0.0;
      final expandToken = widget.focusedCategory == categoryName
          ? widget.focusToken
          : 0;

      categoryWidgets.add(
        KeyedSubtree(
          key: _keyFor(categoryName),
          child: CategoryExpansionTile(
            categoryName: categoryName,
            categoryBudget: categoryBudget,
            categorySpent: categorySpent,
            categoryExpenses: categoryExpenses,
            budgetId: budget.id!,
            isSharedBudget: widget.isSharedBudget,
            expandToken: expandToken,
          ),
        ),
      );
    }

    for (final categoryName in unplannedWithSpend) {
      final categorySpent = categoryTotals[categoryName] ?? 0.0;
      final expandToken = widget.focusedCategory == categoryName
          ? widget.focusToken
          : 0;
      categoryWidgets.add(
        KeyedSubtree(
          key: _keyFor(categoryName),
          child: CategoryExpansionTile(
            categoryName: categoryName,
            categoryBudget: 0,
            categorySpent: categorySpent,
            categoryExpenses: const [],
            budgetId: budget.id!,
            isSharedBudget: widget.isSharedBudget,
            expandToken: expandToken,
          ),
        ),
      );
    }

    final totalBudget = budgetCategories.fold<double>(
      0.0,
      (sum, category) =>
          sum +
          budget.expenses[category]!.values.fold(0.0, (s, v) => s + v),
    );
    final totalSpent = expenseProvider.totalExpenses;
    final unplannedSpent = categoryTotals.entries
        .where((e) => !plannedKeys.contains(e.key))
        .fold<double>(0.0, (sum, e) => sum + e.value);

    return SummarySectionCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('tracking-$_isExpanded-${widget.focusToken}'),
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            if (mounted) setState(() => _isExpanded = expanded);
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
                if (budgetCategories.isNotEmpty || unplannedWithSpend.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${budgetCategories.length + unplannedWithSpend.length} kategoria${(budgetCategories.length + unplannedWithSpend.length) == 1 ? '' : 'a'}',
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
                  if (budgetCategories.isNotEmpty || totalSpent > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yhteensä: ${formatCurrency(totalSpent)} / ${formatCurrency(totalBudget)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: totalSpent > totalBudget
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                          ),
                          if (unplannedSpent > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Suunnittelemattomat: ${formatCurrency(unplannedSpent)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ],
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
