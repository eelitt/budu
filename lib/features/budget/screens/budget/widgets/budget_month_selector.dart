import 'package:budu/features/budget/screens/budget/utils/month_utils.dart';
import 'package:flutter/material.dart';

class BudgetMonthSelector extends StatelessWidget {
  final List<Map<String, int>> availableMonths;
  final Map<String, int>? selectedMonth;
  final Function(Map<String, int>?) onMonthSelected;

  const BudgetMonthSelector({
    super.key,
    required this.availableMonths,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (availableMonths.isEmpty) {
      return const Text('Ei saatavilla olevia budjetteja');
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 8),
            DropdownButton<Map<String, int>>(
              value: selectedMonth,
              hint: Text(
                'Valitse budjetti',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black87,
                    ),
              ),
              isExpanded: false,
              underline: const SizedBox(),
              items: availableMonths.map((monthData) {
                return DropdownMenuItem<Map<String, int>>(
                  value: monthData,
                  child: Text(
                    '${getMonthName(monthData['month']!)} ${monthData['year']}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                        ),
                  ),
                );
              }).toList(),
              onChanged: onMonthSelected,
            ),
          ],
        ),
      ),
    );
  }
}