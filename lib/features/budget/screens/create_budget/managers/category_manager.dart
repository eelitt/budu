import 'package:budu/core/constants.dart';
import 'package:flutter/material.dart';

/// Luokka, joka hallinnoi budjettikategorioiden lisäämistä ja poistamista.
/// Tukee ennalta määriteltyjen kategorioiden ja omien kategorioiden lisäämistä.
class CategoryManager {
  final Map<String, Map<String, TextEditingController>> expenseControllers; // Kategorioiden ja alakategorioiden ohjaimet
  final VoidCallback onUpdate; // Callback-funktio, jota kutsutaan, kun kategoriat päivittyvät

  CategoryManager({
    required this.expenseControllers,
    required this.onUpdate,
  });

  /// Palauttaa true, jos uusia kategorioita voi lisätä (kategorioiden määrä alle maksimin).
  bool get canAddCategory {
    return expenseControllers.length < Constants.maxCategories;
  }

  /// Poistaa kategorian ja sen alakategoriat.
  /// [category] on poistettava kategoria.
  void removeCategory(String category) {
    expenseControllers.remove(category);
    onUpdate();
  }

  /// Näyttää dialogin, jossa käyttäjä voi valita ennalta määritellyn kategorian tai lisätä oman kategorian.
  void addCategory(BuildContext context) {
    if (!canAddCategory) {
      // Näytetään varoitus, jos kategorioiden maksimimäärä on saavutettu
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
            'Kategorioiden maksimimäärä (${Constants.maxCategories}) on saavutettu.',
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

    // Haetaan saatavilla olevat ennalta määritellyt kategoriat
    final availableCategories = Constants.categoryMapping.keys
        .where((category) => !expenseControllers.containsKey(category))
        .toList();

    String? selectedCategory;
    final customController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        title: Text(
          'Lisää kategoria',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pudotusvalikko ennalta määriteltyjen kategorioiden valintaan
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
                        value: selectedCategory,
                        hint: const Text('Valitse kategoria'),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Oma kategoria'),
                          ),
                          ...availableCategories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                            errorText = null;
                          });
                        },
                        menuMaxHeight: 300,
                      ),
                    ),
                  ),
                  // Tekstikenttä oman kategorian syöttämiseen
                  if (selectedCategory == null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        labelText: 'Oma kategoria',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                        errorMaxLines: 2,
                      ),
                      maxLength: Constants.maxCategoryNameLength,
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() => errorText = 'Syötä kategorian nimi');
                        } else if (value.length > Constants.maxCategoryNameLength) {
                          setState(() => errorText = 'Nimi voi olla enintään ${Constants.maxCategoryNameLength} merkkiä');
                        } else if (expenseControllers.containsKey(value.trim())) {
                          setState(() => errorText = 'Kategoria on jo olemassa');
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
              final newCategory = selectedCategory ?? customController.text.trim();
              if (newCategory.isEmpty) {
                return;
              }
              if (expenseControllers.containsKey(newCategory)) {
                return;
              }
              expenseControllers[newCategory] = {};
              Navigator.pop(context);
              onUpdate();
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
      ),
    );
  }
}