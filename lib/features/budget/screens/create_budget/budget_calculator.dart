import 'package:flutter/material.dart';

/// Luokka, joka laskee budjetin kokonaistulot ja -menot.
/// Päivittää budjetin yhteenvedon, kun tulot tai menot muuttuvat.
class BudgetCalculator {
  final TextEditingController incomeController; // Tekstikentän ohjain tulojen syöttämiseen
  final Map<String, Map<String, TextEditingController>> expenseControllers; // Kategorioiden ja alakategorioiden ohjaimet
  final Function() setStateCallback; // Callback-funktio, jota kutsutaan päivityksen jälkeen

  BudgetCalculator({
    required this.incomeController,
    required this.expenseControllers,
    required this.setStateCallback,
  });

  /// Päivittää budjetin yhteenvedon kutsumalla setStateCallback-funktiota.
  void updateSummary() {
    setStateCallback();
  }

  /// Palauttaa budjetin kokonaistulot.
  /// Parsii arvon incomeController-tekstikentästä, oletusarvo 0.0.
  double get totalIncome {
    return double.tryParse(incomeController.text) ?? 0.0;
  }

  /// Palauttaa budjetin kokonaismenot.
  /// Laskee kaikkien kategorioiden ja alakategorioiden summat.
  double get totalExpenses {
    double total = 0.0;
    expenseControllers.forEach((category, subcategoryMap) {
      subcategoryMap.forEach((subcategory, controller) {
        total += double.tryParse(controller.text) ?? 0.0;
      });
    });
    return total;
  }
}