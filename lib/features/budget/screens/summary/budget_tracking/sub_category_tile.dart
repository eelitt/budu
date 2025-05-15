import 'package:budu/core/utils.dart';
import 'package:budu/features/budget/screens/summary/budget_tracking/progressColorHelper.dart';
import 'package:flutter/material.dart';

class SubCategoryTile extends StatelessWidget {
  final String subCategory;
  final double subCategoryBudget;
  final double spentAmount;
  final String categoryName;

  const SubCategoryTile({
    super.key,
    required this.subCategory,
    required this.subCategoryBudget,
    required this.spentAmount,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final subProgress = subCategoryBudget > 0 ? spentAmount / subCategoryBudget : 0.0;
    final subRemainingPercentage = subCategoryBudget > 0
        ? ((subCategoryBudget - spentAmount) / subCategoryBudget * 100).clamp(0, 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  subCategory,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '${formatCurrency(spentAmount)} / ${formatCurrency(subCategoryBudget)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: subProgress > 1 ? 1 : subProgress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(ProgressColorHelper.getProgressColor(categoryName, subProgress)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '${subRemainingPercentage.toStringAsFixed(0)}% jäljellä',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}