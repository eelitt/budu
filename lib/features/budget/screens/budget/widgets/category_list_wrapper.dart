import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_category_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka käärii ja näyttää budjettikategorioiden listan.
/// Kuuntelee BudgetProvider-tilaa ja päivittää kategorioiden listan reaaliajassa.
class CategoryListWrapper extends StatefulWidget {
  final BudgetModel budget; // Budjettimalli, joka sisältää kategoriat ja niiden menot

  const CategoryListWrapper({super.key, required this.budget});

  @override
  State<CategoryListWrapper> createState() => _CategoryListWrapperState();
}

/// CategoryListWrapperin tilallinen tila, joka hallinnoi kategorioiden listaa ja niiden päivitystä.
class _CategoryListWrapperState extends State<CategoryListWrapper> {
  late Map<String, Map<String, double>> expenses; // Kategorioiden menot, alustetaan budjetista

  @override
  void initState() {
    super.initState();
    // Alustetaan expenses-arvo budjetin menoilla
    expenses = Map.from(widget.budget.expenses);
  }

  @override
  Widget build(BuildContext context) {
    // Kuuntelee BudgetProvider-tilaa ja päivittää käyttöliittymän, kun budjetti muuttuu
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
        final budget = budgetProvider.budget;
        if (budget != null) {
          // Päivitetään expenses-arvo reaaliajassa BudgetProvider-tilasta
          expenses = Map.from(budget.expenses);
        }

        // Järjestetään kategoriat aakkosjärjestykseen
        final sortedCategories = expenses.keys.toList()..sort();
        final List<Widget> categoryWidgets = [];
        // Luodaan widget-lista jokaiselle kategorialle
        for (int i = 0; i < sortedCategories.length; i++) {
          final categoryName = sortedCategories[i];
          // Lisätään BudgetCategorySection jokaiselle kategorialle
          categoryWidgets.add(BudgetCategorySection(categoryName: categoryName));
          // Lisätään väli kategorioiden väliin, paitsi viimeisen jälkeen
          if (i < sortedCategories.length - 1) {
            categoryWidgets.add(const SizedBox(height: 16));
          }
        }

        // Palautetaan sarake, joka sisältää kaikki kategoriat
        return Column(children: categoryWidgets);
      },
    );
  }
}