import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:flutter/material.dart';

/// Summary event card with optional delete action.
class SummaryEventTile extends StatelessWidget {
  final ExpenseEvent expense;
  final VoidCallback? onDelete;

  const SummaryEventTile({
    super.key,
    required this.expense,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.type == EventType.income;
    final amountColor = isIncome ? Colors.green : Colors.red;
    final subcategory = expense.subcategory?.trim();
    final hasSubcategory = subcategory != null && subcategory.isNotEmpty;
    final description = expense.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                color: amountColor,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasDescription) ...[
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (hasSubcategory) ...[
                      Text(
                        subcategory,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      '${expense.createdAt.day}.${expense.createdAt.month}.${expense.createdAt.year} '
                      '${expense.createdAt.hour}:${expense.createdAt.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}${formatCurrency(expense.amount)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
