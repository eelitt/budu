import 'package:budu/core/constants.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:flutter/material.dart';

class BudgetInitializer {
  final BudgetModel? sourceBudget;
  final TextEditingController incomeController;
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final Function() updateSummary;

  BudgetInitializer({
    required this.sourceBudget,
    required this.incomeController,
    required this.expenseControllers,
    required this.updateSummary,
  });

  void initialize() {
    // Alustetaan tyhjä budjetti, jos sourceBudget puuttuu
    final BudgetModel budget = sourceBudget ?? BudgetModel(
      income: 0.0,
      expenses: {},
      createdAt: DateTime.now(),
      year: DateTime.now().year,
      month: DateTime.now().month,
    );

    // Pyöristetään tulot kahden desimaalin tarkkuudella
    final roundedIncome = (budget.income * 100).roundToDouble() / 100;
    incomeController.text = roundedIncome.toStringAsFixed(2);

    // Kopioidaan ylä- ja alakategoriat viimeisimmästä budjetista, jos budjetti on olemassa
    if (sourceBudget != null) {
      for (var category in budget.expenses.keys) {
        final subcategories = budget.expenses[category]!;
        expenseControllers[category] = {};
        for (var subcategory in subcategories.keys) {
          // Pyöristetään arvo kahden desimaalin tarkkuudella
          final roundedValue = (subcategories[subcategory]! * 100).roundToDouble() / 100;
          expenseControllers[category]![subcategory] = TextEditingController(
            text: roundedValue.toStringAsFixed(2),
          );
        }
      }
    }

    // Jos budjettia ei ole, alustetaan vain yläkategoriat ilman alakategorioita
    if (sourceBudget == null) {
      for (var category in categoryMapping.keys) {
        expenseControllers[category] = {};
      }
    } else {
      // Varmistetaan, että kaikki yläkategoriat ovat mukana, vaikka niillä ei olisi arvoja
      for (var category in categoryMapping.keys) {
        if (!expenseControllers.containsKey(category)) {
          expenseControllers[category] = {};
          // Lisätään yläkategoria oletusarvolla 0.00 vain, jos budjetissa on alakategorioita
          if (budget.expenses.containsKey(category)) {
            expenseControllers[category]![category] = TextEditingController(text: '0.00');
          }
        }
      }
    }

    // Kuunnellaan muutoksia tulojen ja menojen arvoissa yhteenvetoa varten
    incomeController.addListener(updateSummary);
    expenseControllers.forEach((category, subcategoryMap) {
      subcategoryMap.forEach((subcategory, controller) {
        controller.addListener(updateSummary);
      });
    });
  }

  void dispose() {
    incomeController.removeListener(updateSummary);
    incomeController.dispose();
    expenseControllers.forEach((category, subcategoryMap) {
      subcategoryMap.forEach((subcategory, controller) {
        controller.removeListener(updateSummary);
        controller.dispose();
      });
    });
  }
}