import 'package:budu/core/constants.dart';
import 'package:flutter/material.dart';

/// Luokka, joka hallinnoi budjettialakategorioiden lisäämistä ja poistamista.
/// Tukee ennalta määriteltyjen ja omien alakategorioiden lisäämistä.
class SubcategoryManager {
  final Map<String, Map<String, TextEditingController>> expenseControllers; // Kategorioiden ja alakategorioiden ohjaimet
  final Function({required String category, required String subcategory}) onUpdate; // Callback-funktio, jota kutsutaan, kun alakategoriat päivittyvät

  SubcategoryManager({
    required this.expenseControllers,
    required this.onUpdate,
  });

  /// Palauttaa true, jos uusia alakategorioita voi lisätä (alakategorioiden määrä alle maksimin).
  bool canAddSubcategory(String category) {
    return (expenseControllers[category]?.length ?? 0) < Constants.maxSubcategories;
  }

  /// Poistaa alakategorian kategoriasta.
  /// [category] on yläkategoria, [subcategory] on poistettava alakategoria.
  void removeSubcategory(String category, String subcategory) {
    expenseControllers[category]?.remove(subcategory);
    onUpdate(category: category, subcategory: subcategory);
  }

  /// Validoi alakategorian nimen.
  /// [value] on tarkistettava nimi.
  /// Palauttaa virheviestin, jos nimi on virheellinen, muuten null.
  String? _validateSubcategoryName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Syötä alakategorian nimi';
    }
    if (value.length > Constants.maxCategoryNameLength) {
      return 'Nimi voi olla enintään ${Constants.maxCategoryNameLength} merkkiä';
    }
    return null;
  }

  /// Näyttää dialogin, jossa käyttäjä voi valita ennalta määritellyn alakategorian tai lisätä oman.
  /// [category] on yläkategoria, johon alakategoria lisätään.
  void addSubcategory(BuildContext context, String category) {
    if (!canAddSubcategory(category)) {
      // Näytetään varoitus, jos alakategorioiden maksimimäärä on saavutettu
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          title: Text(
            'Virhe',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          content: Text(
            'Alakategorioiden maksimimäärä (${Constants.maxSubcategories}) on saavutettu.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black87,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
      return;
    }

 // Haetaan saatavilla olevat ennalta määritellyt alakategoriat, jos kategoria löytyy Constants.categoryMapping:ista
    final availableSubcategories = Constants.categoryMapping.containsKey(category)
        ? Constants.categoryMapping[category]!
            .where((subcategory) => !(expenseControllers[category]?.containsKey(subcategory) ?? false))
            .toList()
        : <String>[]; // Jos kategoria on oma, ei ole ennalta määriteltyjä alakategorioita

    showDialog(
      context: context,
      builder: (context) {
        String? selectedSubcategory;
        final customController = TextEditingController();
        String? errorText;
        late void Function(String?) updateErrorText;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lisää alakategoria',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kategoria: $category',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateErrorText = (String? newErrorText) {
                  setState(() {
                    errorText = newErrorText;
                  });
                };

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pudotusvalikko ennalta määriteltyjen alakategorioiden valintaan
                    Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.white,
                        dropdownMenuTheme: DropdownMenuThemeData(
                          menuStyle: MenuStyle(
                            backgroundColor: const WidgetStatePropertyAll(Colors.white),
                            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: DropdownButton<String>(
                          value: selectedSubcategory,
                          hint: const Text('Valitse alakategoria'),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Muu (syötä oma)'),
                            ),
                            ...availableSubcategories.map((subcategory) {
                              return DropdownMenuItem<String>(
                                value: subcategory,
                                child: Text(subcategory),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedSubcategory = value;
                              errorText = null;
                            });
                          },
                          menuMaxHeight: 300,
                        ),
                      ),
                    ),
                    // Tekstikenttä oman alakategorian syöttämiseen
                    if (selectedSubcategory == null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customController,
                        decoration: InputDecoration(
                          labelText: 'Oma alakategoria',
                          border: const OutlineInputBorder(),
                          errorText: errorText,
                          errorMaxLines: 2,
                        ),
                        maxLength: Constants.maxCategoryNameLength,
                        onChanged: (value) {
                          final error = _validateSubcategoryName(value);
                          if (error != null) {
                            setState(() => errorText = error);
                          } else if (expenseControllers[category]?.containsKey(value.trim()) ?? false) {
                            setState(() => errorText = 'Alakategoria on jo olemassa');
                          } else {
                            setState(() => errorText = null);
                          }
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Peruuta',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final subcategory = selectedSubcategory ?? customController.text.trim();
                final validationError = _validateSubcategoryName(subcategory);
                if (validationError != null) {
                  updateErrorText(validationError);
                } else if (expenseControllers[category]?.containsKey(subcategory) ?? false) {
                  updateErrorText('Alakategoria on jo olemassa');
                } else if (subcategory.isNotEmpty) {
                  expenseControllers[category]![subcategory] = TextEditingController(text: '0.00');
                  onUpdate(category: category, subcategory: subcategory);
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
                foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
              ),
              child: Text(
                'Lisää',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                    ),
              ),
            ),
          ],
      );
      },
    );
  }
}