import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Palvelu pääsivun budjetin lataamiseen.
/// Käsittelee budjetin lataamista Firestoresta käyttäjän UID:n ja viimeisimmän budjetin ID:n perusteella.
class MainScreenBudgetService {
  Future<void> loadBudget(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    
    if (authProvider.user == null) {
      throw Exception('Käyttäjä ei ole kirjautunut');
    }

    try {
      // Haetaan saatavilla olevat budjetit
      final availableBudgets = await budgetProvider.getAvailableBudgets(authProvider.user!.uid);
      if (availableBudgets.isEmpty) {
        throw Exception('Ei saatavilla olevia budjetteja');
      }

      // Valitaan viimeisin budjetti (lajiteltu startDate:n mukaan laskevasti)
      final latestBudget = availableBudgets.first;
      await budgetProvider.loadBudget(authProvider.user!.uid, latestBudget.id!);
    } catch (e) {
      // Heitetään poikkeus eteenpäin kutsujalle
      throw Exception('Budjetin lataaminen epäonnistui: $e');
    }
  }
}