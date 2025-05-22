import 'package:budu/core/constants.dart';
import 'package:budu/core/utils.dart';
import 'package:flutter/material.dart';

/// Näyttää dialogin kategorian lisäämistä varten.
/// Sallii käyttäjän valita kategorian pudotusvalikosta tai lisätä oman kategorian.
Future<String?> showAddCategoryDialog({
  required BuildContext context,
  required Map<String, Map<String, double>> currentExpenses,
}) async {
  final availableCategories = Constants.categoryMapping.keys
      .where((category) => !currentExpenses.containsKey(category))
      .toList();

  String? selectedCategory;
  String? customCategoryName;
  String? errorMessage;
  bool isCustomCategory = false;

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
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
                  // Pudotusvalikko kategorioiden valintaan
                  Material(
                    color: Colors.white, // Teeman mukainen kortin väri
                    borderRadius: BorderRadius.circular(8),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.75),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          setState(() {
                            if (value == 'Lisää oma') {
                              isCustomCategory = true;
                              selectedCategory = null;
                            } else {
                              isCustomCategory = false;
                              selectedCategory = value;
                              customCategoryName = null;
                              errorMessage = null;
                            }
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          final options = [
                            ...availableCategories,
                            'Lisää oma', // Lisätään "Lisää oma" -vaihtoehto
                          ];
                          return options.map((option) {
                            return PopupMenuItem<String>(
                              value: option,
                              child: Text(
                                option,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black87,
                                    ),
                              ),
                            );
                          }).toList();
                        },
                        color: Colors.white,
                        position: PopupMenuPosition.under,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedCategory ?? (isCustomCategory ? 'Oma kategoria' : 'Valitse kategoria'),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.black87,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tekstikenttä oman kategorian nimen syöttämiseen
                  if (isCustomCategory) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: customCategoryName,
                      onChanged: (value) {
                        setState(() {
                          customCategoryName = value;
                          if (value.isEmpty) {
                            errorMessage = 'Kategorian nimi ei voi olla tyhjä';
                          } else if (value.length > 20) {
                            errorMessage = 'Kategorian nimi voi olla enintään 20 merkkiä';
                          } else {
                            errorMessage = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Kategorian nimi',
                        labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                            ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        errorText: errorMessage,
                        errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black87,
                          ),
                      maxLength: 20, // Rajoitetaan syöte 20 merkkiin
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
              // Tallenna valittu kategoria tai oma kategoria
              if (isCustomCategory) {
                if (customCategoryName != null && customCategoryName!.isNotEmpty && errorMessage == null) {
                  Navigator.pop(context, customCategoryName);
                }
              } else if (selectedCategory != null) {
                Navigator.pop(context, selectedCategory);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
              foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

  // Näytetään Snackbar, jos kategoria lisättiin
  if (result != null) {
    showSnackBar(
      context,
      'Kategoria "$result" lisätty!',
      duration: const Duration(seconds: 2),
    );
  }

  return result;
}