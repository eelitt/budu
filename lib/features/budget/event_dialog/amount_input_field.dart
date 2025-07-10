import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget summan syöttämiseen AddEventDialogissa.
/// Näyttää tekstikentän, johon käyttäjä voi syöttää tapahtuman summan.
class AmountInputField extends StatelessWidget {
  final TextEditingController controller; // Ohjain summan syöttökentälle
  final String? errorText; // Virheilmoitus summalle
  final Function(String) onChanged; // Callback arvon muutokselle

  const AmountInputField({
    super.key,
    required this.controller,
    this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Summa (€)',
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // Sallii vain numerot
        LengthLimitingTextInputFormatter(5), // Enintään 5 numeroa
      ],
      onChanged: onChanged,
    );
  }
}