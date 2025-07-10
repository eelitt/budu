import 'package:flutter/material.dart';

/// Widget kuvauksen syöttämiseen AddEventDialogissa.
/// Näyttää tekstikentän, johon käyttäjä voi syöttää tapahtuman kuvauksen.
class DescriptionInputField extends StatelessWidget {
  final TextEditingController controller; // Ohjain kuvauksen syöttökentälle
  final String? errorText; // Virheilmoitus kuvaukselle
  final Function(String) onChanged; // Callback arvon muutokselle

  const DescriptionInputField({
    super.key,
    required this.controller,
    this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Kuvaus (valinnainen)',
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      maxLines: 2,
      maxLength: 75, // Enintään 75 merkkiä
      onChanged: onChanged,
    );
  }
}