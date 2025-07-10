import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Yhteenvetolohko budjetin luontisivulla, joka näyttää tulot, menot, jäljellä olevan summan ja budjetin aikavälin.
class SummarySection extends StatelessWidget {
  final double totalIncome;
  final double totalExpenses;
  final DateTime? startDate; // Budjetin aloituspäivä
  final DateTime? endDate; // Budjetin päättymispäivä

  const SummarySection({
    super.key,
    required this.totalIncome,
    required this.totalExpenses,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    // Muotoillaan aikaväli
    final dateFormat = DateFormat('d.M.yyyy');
    final periodText = (startDate != null && endDate != null)
        ? 'Ajanjakso: ${dateFormat.format(startDate!)} - ${dateFormat.format(endDate!)}'
        : 'Aikaväliä ei valittu';

    // Lokitetaan, jos aikaväli puuttuu
    if (startDate == null || endDate == null) {
      FirebaseCrashlytics.instance.log('SummarySection: Aikaväli puuttuu (startDate: $startDate, endDate: $endDate)');
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yhteenveto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            periodText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tulot:'),
              Text(
                '${totalIncome.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.green, fontSize: 15),
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
                style: const TextStyle(color: Colors.red, fontSize: 15),
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
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}