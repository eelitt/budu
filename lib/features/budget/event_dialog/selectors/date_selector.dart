import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget päivämäärän valintaan AddEventDialogissa.
/// Näyttää päivämäärän tekstinä ja painikkeen päivämäärävalitsimen avaamiseen.
class DateSelector extends StatelessWidget {
  final DateTime selectedDate; // Valittu päivämäärä
  final VoidCallback onSelectDate; // Callback päivämäärän valitsimen avaamiseen

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Päivämäärä: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: onSelectDate,
        ),
      ],
    );
  }
}