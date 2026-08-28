import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/domain/tracking.dart';
import 'package:budu/features/budget/event_dialog/add_event_dialog.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/screens/budget/utils/category_icon_utils.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/sub_category_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategoryExpansionTile extends StatefulWidget {
  final String categoryName;
  final double categoryBudget;
  final double categorySpent;
  final List<MapEntry<String, double>> categoryExpenses;
  final String budgetId;
  final bool isSharedBudget;
  final int expandToken;

  const CategoryExpansionTile({
    super.key,
    required this.categoryName,
    required this.categoryBudget,
    required this.categorySpent,
    required this.categoryExpenses,
    required this.budgetId,
    required this.isSharedBudget,
    this.expandToken = 0,
  });

  @override
  State<CategoryExpansionTile> createState() => _CategoryExpansionTileState();
}

class _CategoryExpansionTileState extends State<CategoryExpansionTile> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(CategoryExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandToken > 0 &&
        widget.expandToken != oldWidget.expandToken) {
      setState(() => _isExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        trackingProgress(widget.categorySpent, widget.categoryBudget);
    final remainingPercentage =
        remainingPercentClamped(widget.categorySpent, widget.categoryBudget);
    final isOverBudget = progress > 1;
    final subCategoryCount = widget.categoryExpenses.length;
    final categoryIcon = getCategoryIcon(widget.categoryName);
    final expenses = Provider.of<ExpenseProvider>(context).expenses;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('cat-${widget.categoryName}-$_isExpanded-${widget.expandToken}'),
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) =>
              setState(() => _isExpanded = expanded),
          tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 0),
          leading: null,
          trailing: const SizedBox.shrink(),
          title: Stack(
            children: [
              Positioned(
                left: 12,
                top: 4,
                child: Icon(categoryIcon, color: Colors.blueGrey, size: 22),
              ),
              Positioned(
                right: 30,
                top: 4,
                child: Text(
                  '$subCategoryCount alakategoria${subCategoryCount == 1 ? '' : 'a'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ),
              Positioned(
                right: 0,
                top: 4,
                child: AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    color: Colors.blueGrey,
                    size: 22,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 28, left: 16, right: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.categoryName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOverBudget)
                                const Icon(
                                  Icons.warning,
                                  color: Colors.red,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${formatCurrency(widget.categorySpent)} / ${formatCurrency(widget.categoryBudget)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress > 1 ? 1 : progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverBudget ? Colors.red : Colors.green,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${remainingPercentage.toStringAsFixed(0)}% jäljellä',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                        ),
                        if (isOverBudget)
                          Text(
                            'Budjetti ylittynyt!',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            ...widget.categoryExpenses.map((entry) {
              final spentAmount = subcategoryActualTotal(
                expenses,
                budgetId: widget.budgetId,
                category: widget.categoryName,
                subcategory: entry.key,
              );
              return SubCategoryTile(
                subCategory: entry.key,
                subCategoryBudget: entry.value,
                spentAmount: spentAmount,
              );
            }),
            if (_isExpanded && subCategoryCount > 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AddEventDialog(
                        initialCategory: widget.categoryName,
                        initialBudgetId: widget.budgetId,
                        isSharedBudget: widget.isSharedBudget,
                      ),
                    );
                  },
                  child: Text(
                    'Lisää meno',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
