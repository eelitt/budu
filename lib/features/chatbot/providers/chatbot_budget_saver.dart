import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../budget/models/budget_model.dart';
import '../../budget/providers/budget_provider.dart';

class ChatbotBudgetSaver {
  final bool isCompleted;
  final double income;
  final Map<String, Map<String, double>> expenses;

  ChatbotBudgetSaver({
    required this.isCompleted,
    required this.income,
    required this.expenses,
  });

  Future<void> saveBudget(BuildContext context, String userId) async {
    if (isCompleted) {
      final budget = BudgetModel(
        income: income,
        expenses: expenses,
        createdAt: DateTime.now(),
        year: DateTime.now().year,
        month: DateTime.now().month,
      );
      print('Saving budget: ${budget.toMap()}');
      await Provider.of<BudgetProvider>(context, listen: false).saveBudget(userId, budget);
    }
  }
}