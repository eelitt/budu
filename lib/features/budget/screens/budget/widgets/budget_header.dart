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
    return Text(
      selectedMonth != null
          ? 'Budjetti: ${getMonthName(selectedMonth!['month']!)} ${selectedMonth!['year']}'
          : 'Ei valittua budjettia',
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
    );
  }
}