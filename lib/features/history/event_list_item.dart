import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budu/features/budget/models/expense_event.dart';

class EventListItem extends StatelessWidget {
  final ExpenseEvent event;

  const EventListItem({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isIncome = event.type == EventType.income;
    final amountColor = isIncome ? Colors.green : Colors.red;
    final subcategory = event.subcategory?.trim();
    final hasSubcategory =
        subcategory != null && subcategory.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: amountColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.category,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (hasSubcategory)
                    Text(
                      subcategory,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  if (event.description != null)
                    Text(
                      event.description!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  Text(
                    DateFormat('d.M.yyyy').format(event.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? "+" : "-"}${event.amount.toStringAsFixed(2)} €',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
