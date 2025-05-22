import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget kategorian ja ala-kategorian valitsemiseen
/// esittää pudotusvalikot kategorioille ja ala-kategorioille
class CategorySelector extends StatelessWidget {
  final bool isExpense; // Onko tapahtuma meno tai tulo
  final String? selectedCategory; // Valinnoissa oleva kategoria
  final String? selectedSubcategory; // Valinnoissa oleva ala-kategoria
  final Function(String?) onCategoryChanged; // Callback kategorian vaihdolle
  final Function(String?) onSubcategoryChanged; // Callback  ala-kategorian vaihdolle
  final String? categoryError; // Virheviesti kategorian valinnalle
  final String? subcategoryError; // Virheviesti ala-kategorian valinnalle

  const CategorySelector({
    super.key,
    required this.isExpense,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
    this.categoryError,
    this.subcategoryError,
  });

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);

    // Hae kategoria-lista budjetista
    final categories = budgetProvider.budget?.expenses.keys.toList() ?? [];
    final hasCategories = categories.isNotEmpty;

    // Hae kategorian ala-kategoriat
    final subCategories = selectedCategory != null && budgetProvider.budget != null
        ? budgetProvider.budget!.expenses[selectedCategory]?.keys.toList() ?? []
        : [];
    final hasSubCategories = subCategories.isNotEmpty;

    return Column(
      children: [
        if (isExpense) ...[
          // kategoria valikko tai teksti
          hasCategories
              ? DropdownButtonFormField<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Kategoria',
                    border: const OutlineInputBorder(),
                    errorText: categoryError, // Show error if provided
                  ),
                  dropdownColor: Colors.white,
                  items: categories.map((key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(key),
                    );
                  }).toList(),
                  onChanged: onCategoryChanged,
                )
              : const Text('Ei kategorioita'),
          const SizedBox(height: 16),
        ],
        if (isExpense && selectedCategory != null) ...[
          // ala-kategoria valikko tai teksti
          hasSubCategories
              ? DropdownButtonFormField<String>(
                  value: selectedSubcategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Alakategoria',
                    border: const OutlineInputBorder(),
                    errorText: subcategoryError, //Näytä virheviesti..
                  ),
                  dropdownColor: Colors.white,
                  items: subCategories.map((subCategory) {
                    return DropdownMenuItem<String>(
                      value: subCategory,
                      child: Text(subCategory),
                    );
                  }).toList(),
                  onChanged: onSubcategoryChanged,
                )
              : const Text('Ei alakategorioita valitulle kategorialle'),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}