import 'package:flutter/material.dart';

class SummarySection extends StatelessWidget {
  final double totalIncome;
  final double totalExpenses;

  const SummarySection({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yhteenveto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tulot:'),
              Text(
                '${totalIncome.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Menot:'),
              Text(
                '${totalExpenses.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jäljellä:'),
              Text(
                '${(totalIncome - totalExpenses).toStringAsFixed(2)} €',
                style: TextStyle(
                  color: (totalIncome - totalExpenses) >= 0 ? Colors.black : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}