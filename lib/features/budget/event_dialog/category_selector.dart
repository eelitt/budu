import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CategorySelector extends StatelessWidget {
  final bool isExpense;
  final String? selectedCategory;
  final String? selectedSubcategory;
  final Function(String?) onCategoryChanged;
  final Function(String?) onSubcategoryChanged;

  const CategorySelector({
    super.key,
    required this.isExpense,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);

    // Haetaan valitun kategorian alakategoriat
    final subCategories = selectedCategory != null && budgetProvider.budget != null
        ? budgetProvider.budget!.expenses[selectedCategory]?.keys.toList() ?? []
        : [];

    return Column(
      children: [
        if (isExpense)
          DropdownButtonFormField<String>(
            value: selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kategoria',
              border: OutlineInputBorder(),
            ),
            dropdownColor: Colors.white, // Asetetaan avautuvan valikon taustaväri valkoiseksi
            items: budgetProvider.budget?.expenses.keys.map((key) {
              return DropdownMenuItem<String>(
                value: key,
                child: Text(key),
              );
            }).toList() ?? [],
            onChanged: (value) {
              onCategoryChanged(value);
            },
          ),
        if (isExpense) const SizedBox(height: 16),
        if (isExpense && subCategories.isNotEmpty)
          DropdownButtonFormField<String>(
            value: selectedSubcategory,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Alakategoria',
              border: OutlineInputBorder(),
            ),
            dropdownColor: Colors.white, // Asetetaan avautuvan valikon taustaväri valkoiseksi
            items: subCategories.map((subCategory) {
              return DropdownMenuItem<String>(
                value: subCategory,
                child: Text(subCategory),
              );
            }).toList(),
            onChanged: (value) {
              onSubcategoryChanged(value);
            },
          ),
        if (isExpense && subCategories.isNotEmpty) const SizedBox(height: 16),
      ],
    );
  }
}