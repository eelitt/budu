import 'package:budu/features/budget/screens/budget/utils/month_utils.dart';
import 'package:flutter/material.dart';

/// Widget, joka näyttää pudotusvalikon budjettikuukausien valitsemiseen.
/// Näyttää saatavilla olevat budjettikuukaudet ja vuoden, ja antaa käyttäjän valita niistä.
class BudgetMonthSelector extends StatelessWidget {
  final List<Map<String, int>> availableMonths; // Lista saatavilla olevista budjettikuukausista (kuukausi ja vuosi)
  final Map<String, int>? selectedMonth; // Tällä hetkellä valittu budjettikuukausi
  final Function(Map<String, int>?) onMonthSelected; // Callback-funktio, jota kutsutaan, kun kuukausi valitaan

  const BudgetMonthSelector({
    super.key,
    required this.availableMonths,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Jos saatavilla olevia budjettikuukausia ei ole, näytetään viesti
    if (availableMonths.isEmpty) {
      return const Text('Ei saatavilla olevia budjetteja');
    }

    return Material(
      color: Colors.grey[50], // Kevyt taustaväri erottamaan ulommasta suorakulmiosta
      borderRadius: BorderRadius.circular(12), // Pyöristetyt kulmat
      elevation: 2, // Kevyt varjo syvyyden luomiseksi
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Sisäinen välistys
        child: Row(
          children: [
            // Kalenteri-ikoni pudotusvalikon vieressä
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Colors.blueGrey,
            ),
            const SizedBox(width: 8), // Väli ikonin ja pudotusvalikon välillä
            // Pudotusvalikko budjettikuukausien valintaan
            Expanded(
              child: PopupMenuButton<Map<String, int>>(
                onSelected: onMonthSelected, // Kutsutaan callbackia, kun kuukausi valitaan
                itemBuilder: (BuildContext context) {
                  // Luodaan pudotusvalikon kohteet saatavilla olevista budjettikuukausista
                  return availableMonths.map((monthData) {
                    return PopupMenuItem<Map<String, int>>(
                      value: monthData,
                      child: Text(
                        '${getMonthName(monthData['month']!)} ${monthData['year']}', // Näyttää kuukauden nimen ja vuoden
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 15,
                            ),
                      ),
                    );
                  }).toList();
                },
                color: Colors.white, // Pudotusvalikon taustaväri
                position: PopupMenuPosition.under, // Pudotusvalikko avautuu painikkeen alle
                child: Row(
                  children: [
                    // Näyttää valitun kuukauden tai oletustekstin
                    Expanded(
                      child: Text(
                        selectedMonth != null
                            ? '${getMonthName(selectedMonth!['month']!)} ${selectedMonth!['year']}'
                            : 'Valitse budjetti', // Oletusteksti, jos kuukautta ei ole valittu
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                      ),
                    ),
                    // Nuoli-ikoni, joka osoittaa pudotusvalikon avautuvan
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