import 'package:flutter/material.dart';

/// Widget tapahtuman tyypin (tulo vai meno) valintaan.
/// Näyttää kaksi ChoiceChip-komponenttia: "Tulo" ja "Meno".
class EventTypeSelector extends StatelessWidget {
  final bool isExpense; // Määrittää, onko tapahtuma meno (true) vai tulo (false)
  final Function(bool) onTypeChanged; // Callback-funktio tyypin muutoksen välittämiseen

  const EventTypeSelector({
    super.key,
    required this.isExpense,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Värien määrittely vakioina luettavuuden ja ylläpidon helpottamiseksi
    const selectedIncomeColor = Colors.green; // Valitun tulon väri
    const selectedExpenseColor = Colors.red; // Valitun menon väri
    const backgroundColor = Color(0xFFFFFCF5); // Ei-valitun sirun taustaväri

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Tasainen välistys sirujen välillä
      children: [
        // ChoiceChip "Tulo"-vaihtoehdolle
        ChoiceChip(
          label: const Text('Tulo'), // Teksti sirulle
          selected: !isExpense, // Valittu, jos tapahtuma ei ole meno
          selectedColor: selectedIncomeColor, // Vihreä väri valitulle tilalle
          backgroundColor: backgroundColor, // Vaalea tausta ei-valitulle tilalle
          onSelected: (selected) {
            onTypeChanged(!selected); // Kutsuu callbackia tyypin vaihdolla
          },
        ),
        // ChoiceChip "Meno"-vaihtoehdolle
        ChoiceChip(
          label: const Text('Meno'), // Teksti sirulle
          selected: isExpense, // Valittu, jos tapahtuma on meno
          selectedColor: selectedExpenseColor, // Punainen väri valitulle tilalle
          backgroundColor: backgroundColor, // Vaalea tausta ei-valitulle tilalle
          onSelected: (selected) {
            onTypeChanged(selected); // Kutsuu callbackia tyypin vaihdolla
          },
        ),
      ],
    );
  }
}