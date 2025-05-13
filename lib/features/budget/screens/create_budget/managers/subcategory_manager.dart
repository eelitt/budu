import 'package:budu/core/constants.dart';
import 'package:flutter/material.dart';

class SubcategoryManager {
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final Function({required String category, required String subcategory}) onUpdate; // Päivitetty tyyppi

  SubcategoryManager({
    required this.expenseControllers,
    required this.onUpdate,
  });

  static const int maxSubcategories = 6;
  static const int maxSubcategoryLength = 50;

  bool canAddSubcategory(String category) {
    return (expenseControllers[category]?.length ?? 0) < maxSubcategories;
  }

  void removeSubcategory(String category, String subcategory) {
    expenseControllers[category]?.remove(subcategory);
    onUpdate(category: category, subcategory: subcategory);
  }

  String? _validateSubcategoryName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Syötä alakategorian nimi';
    }
    if (value.length > maxSubcategoryLength) {
      return 'Nimi voi olla enintään $maxSubcategoryLength merkkiä';
    }
    return null;
  }

  void addSubcategory(BuildContext context, String category) {
    if (!canAddSubcategory(category)) return;

    final availableSubcategories = categoryMapping[category]!
        .where((subcategory) => !(expenseControllers[category]?.containsKey(subcategory) ?? false))
        .toList();

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
                        onChanged: (value) {
                          updateErrorText(_validateSubcategoryName(value));
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
                } else {
                  if (subcategory.isNotEmpty) {
                    expenseControllers[category]![subcategory] = TextEditingController(text: '0.00');
                    onUpdate(category: category, subcategory: subcategory);
                  }
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