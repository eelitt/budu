import 'package:budu/features/budget/screens/budget/utils/month_utils.dart';
import 'package:flutter/material.dart';

class BudgetHeader extends StatelessWidget {
  final Map<String, int>? selectedMonth;

  const BudgetHeader({
    super.key,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(16),
      child: Text(
        selectedMonth != null
            ? 'Muokkaa budjettia: \n ${getMonthName(selectedMonth!['month']!)} ${selectedMonth!['year']}'
            : 'Ei valittua budjettia',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
      ),
    );
  }
}