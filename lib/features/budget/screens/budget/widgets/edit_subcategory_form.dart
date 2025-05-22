import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lomakewidget, joka mahdollistaa budjettialakategorian nimen ja summan muokkaamisen.
/// Näyttää tekstikentät nimeä ja summaa varten sekä painikkeet tallentamiseen ja peruuttamiseen.
class EditSubcategoryForm extends StatelessWidget {
  final TextEditingController nameController; // Tekstikentän ohjain alakategorian nimen muokkaamiseen
  final TextEditingController amountController; // Tekstikentän ohjain alakategorian summan muokkaamiseen
  final VoidCallback onSave; // Callback-funktio, jota kutsutaan, kun muokkaukset tallennetaan
  final VoidCallback onCancel; // Callback-funktio, jota kutsutaan, kun muokkaus peruutetaan

  const EditSubcategoryForm({
    super.key,
    required this.nameController,
    required this.amountController,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tekstikenttä alakategorian nimen muokkaamiseen
        Expanded(
          child: TextField(
            controller: nameController, // Liitetään ohjain tekstikenttään
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300), // Reunan väri
                borderRadius: BorderRadius.circular(4), // Pyöristetyt kulmat
              ),
              filled: true, // Taustaväri käytössä
              fillColor: Colors.grey.shade100, // Taustaväri
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Sisäinen välistys
            ),
            maxLength: 20, // Rajoitetaan alakategorian nimi enintään 20 merkkiin
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Poistetaan merkkilaskuri
          ),
        ),
        const SizedBox(width: 8), // Väli tekstikenttien välillä
        // Tekstikenttä alakategorian summan muokkaamiseen
        SizedBox(
          width: 80, // Kiinteä leveys summakentälle
          child: TextField(
            controller: amountController, // Liitetään ohjain tekstikenttään
            keyboardType: const TextInputType.numberWithOptions(decimal: true), // Numeronäppäimistö desimaaleilla
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300), // Reunan väri
                borderRadius: BorderRadius.circular(4), // Pyöristetyt kulmat
              ),
              filled: true, // Taustaväri käytössä
              fillColor: Colors.grey.shade100, // Taustaväri
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Sisäinen välistys
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), // Sallitaan vain numerot ja pisteet
              LengthLimitingTextInputFormatter(5), // Rajoitetaan syöte 5 merkkiin (esim. 99.99 €)
            ],
          ),
        ),
        const SizedBox(width: 8), // Väli tekstikentän ja painikkeiden välillä
        // Vahvistuspainike (vihreä ruksi), joka tallentaa muokkaukset
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green, size: 20),
          onPressed: onSave,
        ),
        // Peruutuspainike (punainen ruksi), joka peruuttaa muokkaukset
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red, size: 20),
          onPressed: onCancel,
        ),
      ],
    );
  }
}