import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Widget kategorian ja ala-kategorian valitsemiseen
/// esittää pudotusvalikot kategorioille ja ala-kategorioille
class CategorySelector extends StatelessWidget {
  final bool isExpense;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final Function(String?) onCategoryChanged;
  final Function(String?) onSubcategoryChanged;
  final String? categoryError;
  final String? subcategoryError;
  final BudgetModel? budget;

  const CategorySelector({
    super.key,
    required this.isExpense,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
    this.categoryError,
    this.subcategoryError,
    this.budget,
    bool hasSubcategoriesForSelectedCategory = false, // Ei käytetä, poistettu
  });

  @override
  Widget build(BuildContext context) {
    // Hae kategoria-lista budjetista
    final allCategories = budget?.expenses.keys.toList() ?? [];
    allCategories.sort(); // Järjestä kategoriat aakkosjärjestykseen

    // Kaikki kategoriat näytetään, riippumatta alakategorioista
    final categories = allCategories;
    final hasCategories = categories.isNotEmpty;

    // Hae kategorian ala-kategoriat
    final subCategories = selectedCategory != null && budget != null
        ? budget!.expenses[selectedCategory]?.keys.toList() ?? []
        : [];
    subCategories.sort(); // Järjestä alakategoriat aakkosjärjestykseen
    final hasSubCategories = subCategories.isNotEmpty;

    // Lokita, jos budjetissa ei ole kategorioita
    if (!hasCategories && budget != null) {
      FirebaseCrashlytics.instance.log('Budjetissa ${budget!.id} ei ole kategorioita');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kategoria-valikko
        hasCategories
            ? DropdownButtonFormField<String>(
                value: categories.contains(selectedCategory) ? selectedCategory : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Kategoria',
                  border: const OutlineInputBorder(),
                  errorText: categoryError,
                ),
                dropdownColor: Colors.white,
                items: categories.map((key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(key),
                  );
                }).toList(),
                onChanged: (value) {
                  onCategoryChanged(value);
                  // Nollaa alakategoria, jos kategoria vaihtuu
                  if (value != selectedCategory) {
                    onSubcategoryChanged(null);
                  }
                },
              )
            : const Text(
                'Ei kategorioita saatavilla',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
        const SizedBox(height: 16),
        // Alakategoria-valikko, jos meno ja kategoriassa on alakategorioita
        if (isExpense && selectedCategory != null && hasSubCategories)
          DropdownButtonFormField<String>(
            value: subCategories.contains(selectedSubcategory) ? selectedSubcategory : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Alakategoria',
              border: const OutlineInputBorder(),
              errorText: subcategoryError,
            ),
            dropdownColor: Colors.white,
            items: subCategories.map((subCategory) {
              return DropdownMenuItem<String>(
                value: subCategory,
                child: Text(subCategory),
              );
            }).toList(),
            onChanged: onSubcategoryChanged,
          ),
        if (isExpense && selectedCategory != null && !hasSubCategories)
          const Text(
            'Ei alakategorioita tälle kategorialle',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}