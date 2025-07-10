import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget budjetin valintaan AddEventDialogissa.
/// Näyttää alasvetovalikon saatavilla olevista budjeteista aikaväleinä.
class BudgetSelector extends StatelessWidget {
  final String? selectedBudgetId; // Valittu budjetin ID
  final List<BudgetModel> availableBudgets; // Saatavilla olevat budjetit
  final Function(String?) onChanged; // Callback budjetin vaihdolle

  const BudgetSelector({
    super.key,
    required this.selectedBudgetId,
    required this.availableBudgets,
    required this.onChanged,
  });

  /// Muotoilee budjetin aikavälin näyttöä varten (esim. "1.5.2025 - 31.5.2025").
  String _formatBudgetPeriod(BudgetModel budget) {
    final dateFormat = DateFormat('d.M.yyyy');
    return '${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedBudgetId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Budjetti',
        border: OutlineInputBorder(),
      ),
      dropdownColor: Colors.white,
      items: availableBudgets.map((budget) {
        return DropdownMenuItem<String>(
          value: budget.id,
          child: Text(_formatBudgetPeriod(budget)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}