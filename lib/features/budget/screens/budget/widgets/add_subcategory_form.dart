import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';

/// Lomakewidget, joka mahdollistaa uuden alakategorian lisäämisen budjettikategoriaan.
/// Näyttää tekstikentän alakategorian nimen syöttämistä varten sekä painikkeet lisäyksen vahvistamiseen ja peruuttamiseen.
/// Tukee sekä henkilökohtaisia (BudgetProvider) että yhteistalousbudjetteja (SharedBudget).
class AddSubcategoryForm extends StatelessWidget {
  final TextEditingController controller; // Tekstikentän ohjain alakategorian nimen syöttämistä varten
  final String? errorMessage; // Virheviesti, joka näytetään, jos syöte ei ole kelvollinen
  final VoidCallback onAdd; // Callback-funktio, jota kutsutaan, kun alakategoria lisätään
  final VoidCallback onCancel; // Callback-funktio, jota kutsutaan, kun lisäys peruutetaan
  final bool isSharedBudget; // Määrittää, onko budjetti yhteistalousbudjetti
  final BudgetModel sharedBudget; // Yhteistalousbudjetti, jos valittuna
  final String categoryName; // Kategorian nimi, johon alakategoria lisätään

  const AddSubcategoryForm({
    super.key,
    required this.controller,
    required this.errorMessage,
    required this.onAdd,
    required this.onCancel,
    required this.isSharedBudget,
    required this.sharedBudget,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tekstikenttä alakategorian nimen syöttämistä varten
        Expanded(
          child: TextField(
            controller: controller, // Liitetään ohjain tekstikenttään
            decoration: InputDecoration(
              labelText: 'Uusi alakategoria', // Tekstikentän otsikko
              border: const OutlineInputBorder(), // Tekstikentän reunaviiva
              errorText: errorMessage, // Näyttää virheviestin, jos syöte on virheellinen
            ),
            maxLength: 20, // Rajoitetaan alakategorian nimi enintään 20 merkkiin
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // Poistetaan merkkilaskuri
          ),
        ),
        // Vahvistuspainike (vihreä ruksi), joka kutsuu onAdd-callbackia
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: onAdd,
        ),
        // Peruutuspainike (punainen ruksi), joka kutsuu onCancel-callbackia
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: onCancel,
        ),
      ],
    );
  }
}