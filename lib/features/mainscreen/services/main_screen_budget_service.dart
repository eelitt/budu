import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreenBudgetService {
  Future<void> loadBudget(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    if (authProvider.user != null) {
      final now = DateTime.now();
      await budgetProvider.loadBudget(authProvider.user!.uid, now.year, now.month);
    } else {
      throw Exception('Käyttäjä ei ole kirjautunut');
    }
  }
}