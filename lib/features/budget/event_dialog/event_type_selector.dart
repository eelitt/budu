import 'package:flutter/material.dart';

class EventTypeSelector extends StatelessWidget {
  final bool isExpense;
  final Function(bool) onTypeChanged;

  const EventTypeSelector({
    super.key,
    required this.isExpense,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ChoiceChip(
          label: const Text('Tulo'),
          selected: !isExpense,
          selectedColor: Colors.green,
          backgroundColor: const Color(0xFFFFFCF5), // Asetetaan vihreä väri valitulle tilalle
          onSelected: (selected) {
            onTypeChanged(!selected);
          },
        ),
        ChoiceChip(
          label: const Text('Meno'),
          selected: isExpense,
          selectedColor: Colors.red,
          backgroundColor: const Color(0xFFFFFCF5),
          onSelected: (selected) {
            onTypeChanged(selected);
          },
        ),
      ],
    );
  }
}