import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/budget_category_section.dart';
import 'package:budu/features/budget/screens/budget/controllers/shared_budget_screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka käärii ja näyttää budjettikategorioiden listan.
/// Kuuntelee SharedBudgetScreenController.selectedBudget-streamia ja BudgetProvider-tilaa reaaliaikaisten päivitysten vuoksi.
/// Tukee sekä henkilökohtaisia (BudgetModel) että yhteistalousbudjetteja (SharedBudget).
class CategoryListWrapper extends StatelessWidget {
  final bool isSharedBudget; // Määrittää, onko budjetti yhteistalousbudjetti
  final BudgetModel budget; // Henkilökohtainen tai yhteistalousbudjetti
  final BudgetModel sharedBudget; // Yhteistalousbudjetti (käytetään lisäominaisuuksiin)
  final SharedBudgetScreenController sharedController; // Kontrolleri yhteistalousbudjetin tilan hallintaan

  const CategoryListWrapper({
    super.key,
    required this.isSharedBudget,
    required this.budget,
    required this.sharedBudget,
    required this.sharedController,
  });

  @override
  Widget build(BuildContext context) {
    return isSharedBudget
        ? StreamBuilder<BudgetModel?>(
            stream: sharedController.selectedBudget,
            builder: (context, snapshot) {
              final expenses = snapshot.data?.expenses ?? {};

              // Järjestetään kategoriat aakkosjärjestykseen
              final sortedCategories = expenses.keys.toList()..sort();
              final List<Widget> categoryWidgets = [];

              // Luodaan widget-lista jokaiselle kategorialle
              for (int i = 0; i < sortedCategories.length; i++) {
                final categoryName = sortedCategories[i];
                // Lisätään BudgetCategorySection jokaiselle kategorialle, välittäen isSharedBudget, budget, sharedBudget ja sharedController
                categoryWidgets.add(BudgetCategorySection(
                  categoryName: categoryName,
                  isSharedBudget: isSharedBudget,
                  budget: snapshot.data!,
                  sharedBudget: sharedBudget,
                  sharedController: sharedController,
                ));
                // Lisätään väli kategorioiden väliin, paitsi viimeisen jälkeen
                if (i < sortedCategories.length - 1) {
                  categoryWidgets.add(const SizedBox(height: 16));
                }
              }

              // Palautetaan sarake, joka sisältää kaikki kategoriat
              return Column(children: categoryWidgets);
            },
          )
        : Consumer<BudgetProvider>(
            builder: (context, budgetProvider, child) {
              final expenses = budget?.expenses ?? {};

              // Järjestetään kategoriat aakkosjärjestykseen
              final sortedCategories = expenses.keys.toList()..sort();
              final List<Widget> categoryWidgets = [];

              // Luodaan widget-lista jokaiselle kategorialle
              for (int i = 0; i < sortedCategories.length; i++) {
                final categoryName = sortedCategories[i];
                // Lisätään BudgetCategorySection jokaiselle kategorialle, välittäen isSharedBudget, budget, sharedBudget ja sharedController
                categoryWidgets.add(BudgetCategorySection(
                  categoryName: categoryName,
                  isSharedBudget: isSharedBudget,
                  budget: budget,
                  sharedBudget: sharedBudget,
                  sharedController: sharedController,
                ));
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