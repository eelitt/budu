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
      color: Colors.grey[50], // Kevyt taustaväri erottamaan ulommasta suorakulmiosta
      borderRadius: BorderRadius.circular(12),
      elevation: 2, // Palautetaan kevyt varjostus
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PopupMenuButton<Map<String, int>>(
                onSelected: onMonthSelected,
                itemBuilder: (BuildContext context) {
                  return availableMonths.map((monthData) {
                    return PopupMenuItem<Map<String, int>>(
                      value: monthData,
                      child: Text(
                        '${getMonthName(monthData['month']!)} ${monthData['year']}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 15,
                            ),
                      ),
                    );
                  }).toList();
                },
                color: Colors.white,
                position: PopupMenuPosition.under,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedMonth != null
                            ? '${getMonthName(selectedMonth!['month']!)} ${selectedMonth!['year']}'
                            : 'Valitse budjetti',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}