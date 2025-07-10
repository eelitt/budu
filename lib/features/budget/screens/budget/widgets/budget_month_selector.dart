import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget, joka näyttää pudotusvalikon budjettien valitsemiseen.
/// Tukee sekä henkilökohtaisia (BudgetModel) että yhteistalousbudjetteja (BudgetModel).
/// Näyttää saatavilla olevat budjetit aikaväleinä ja antaa käyttäjän valita niistä.
class BudgetMonthSelector extends StatelessWidget {
  final bool isSharedBudget; // Määrittää, onko valittuna yhteistalousbudjetti
  final List<BudgetModel> availableBudgets; // Lista saatavilla olevista henkilökohtaisista budjeteista
  final List<BudgetModel> availableSharedBudgets; // Lista saatavilla olevista yhteistalousbudjeteista
  final BudgetModel? selectedBudget; // Tällä hetkellä valittu henkilökohtainen budjetti
  final BudgetModel? selectedSharedBudget; // Tällä hetkellä valittu yhteistalousbudjetti
  final Function(dynamic) onBudgetSelected; // Callback-funktio, jota kutsutaan, kun budjetti valitaan

  const BudgetMonthSelector({
    super.key,
    required this.isSharedBudget,
    required this.availableBudgets,
    required this.availableSharedBudgets,
    this.selectedBudget,
    this.selectedSharedBudget,
    required this.onBudgetSelected,
  });

  /// Muotoilee budjetin aikavälin näyttöä varten (esim. "1.5.2025 - 31.5.2025").
  /// Tukee sekä BudgetModel- että SharedBudget-olioita.
  String _formatBudgetPeriod(dynamic budget) {
    if (budget == null) {
      return 'Ei valittua budjettia'; // Null-tarkistus: Palauta oletusteksti, jos budget null
    }
    final dateFormat = DateFormat('d.M.yyyy');
    if (budget is BudgetModel) {
      return '${dateFormat.format(budget.startDate)} - ${dateFormat.format(budget.endDate)}';
    } 
    return 'Tuntematon aikaväli';
  }

  @override
  Widget build(BuildContext context) {
    // Valitaan budjettien lista isSharedBudget-arvon perusteella
    final budgets = isSharedBudget ? availableSharedBudgets : availableBudgets;
    final selected = isSharedBudget ? selectedSharedBudget : selectedBudget;

    // Jos saatavilla olevia budjetteja ei ole, näytetään viesti
    if (budgets.isEmpty) {
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
            // Pudotusvalikko budjettien valintaan
            Expanded(
              child: PopupMenuButton<dynamic>(
                onSelected: onBudgetSelected, // Kutsutaan callbackia, kun budjetti valitaan
                itemBuilder: (BuildContext context) {
                  // Luodaan pudotusvalikon kohteet saatavilla olevista budjeteista
                  return budgets.map((budget) {
                    return PopupMenuItem<dynamic>(
                      value: budget,
                      child: Text(
                        _formatBudgetPeriod(budget), // Näyttää budjetin aikavälin
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
                    // Näyttää valitun budjetin tai oletustekstin
                    Expanded(
                      child: Text(
                        selected != null
                            ? _formatBudgetPeriod(selected)
                            : 'Valitse budjetti', // Oletusteksti, jos budjettia ei ole valittu
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