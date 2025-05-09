import 'package:flutter/material.dart';

class BudgetCalculator {
  final TextEditingController incomeController;
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final Function() setStateCallback;

  BudgetCalculator({
    required this.incomeController,
    required this.expenseControllers,
    required this.setStateCallback,
  });

  void updateSummary() {
    setStateCallback();
  }

  double get totalIncome {
    return double.tryParse(incomeController.text) ?? 0.0;
  }

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