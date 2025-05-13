import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetSaver {
  final BuildContext context;
  final TextEditingController incomeController;
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final int newYear;
  final int newMonth;
  final double totalIncome;
  final double totalExpenses;
  String? errorMessage;

  BudgetSaver({
    required this.context,
    required this.incomeController,
    required this.expenseControllers,
    required this.newYear,
    required this.newMonth,
    required this.totalIncome,
    required this.totalExpenses,
  });

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        content: Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.black87,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Peruuta',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
              foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
            ),
            child: Text(
              'Jatka',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateIncome(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Salli tyhjä arvo, käsitellään muualla
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Syötä kelvollinen numero';
    }
    if (parsed < 0) {
      return 'Tulot eivät voi olla negatiivisia';
    }
    if (parsed > 999999) {
      return 'Tulot eivät voi olla suurempia kuin 999999 €';
    }
    return null;
  }

  Future<void> createBudget() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Validointi: Tarkista incomeController-arvo
    final incomeError = _validateIncome(incomeController.text);
    if (incomeError != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          title: Text(
            'Virhe',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          content: Text(
            incomeError,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black87,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
      return;
    }

    final double income = double.tryParse(incomeController.text) ?? 0.0;
    final Map<String, Map<String, double>> expenses = {};

    // Tallennetaan ylä- ja alakategoriat
    for (var category in expenseControllers.keys) {
      final subcategoryMap = expenseControllers[category]!;
      expenses[category] = {};
      for (var subcategory in subcategoryMap.keys) {
        final amount = double.tryParse(subcategoryMap[subcategory]!.text) ?? 0.0;
        // Pyöristetään arvo kahden desimaalin tarkkuudella tallennuksessa
        final roundedAmount = (amount * 100).roundToDouble() / 100;
        if (roundedAmount > 0) {
          expenses[category]![subcategory] = roundedAmount;
        }
      }
      // Säilytetään tyhjät yläkategoriat (ei poisteta niitä)
    }

    // Validointi 1: Varoita, jos budjetti on tyhjä (ei tuloja eikä menoja)
    if (income == 0.0 && expenses.isEmpty) {
      final confirm = await _showConfirmationDialog(
        title: 'Varoitus',
        content: 'Budjetissa ei ole tuloja eikä menoja. Haluatko tallentaa tyhjän budjetin?',
      );
      if (confirm != true) return;
    }

    // Validointi 2: Varoita, jos tulot ylittävät 99999 € (ylimääräinen tarkistus)
    if (income > 999999) {
      final confirm = await _showConfirmationDialog(
        title: 'Varoitus',
        content: 'Tulot ylittävät sallitun maksimiarvon (999999 €). Haluatko jatkaa?',
      );
      if (confirm != true) return;
    }

    // Validointi 3: Varoita, jos menot ovat suuremmat kuin tulot
    if (totalExpenses > totalIncome) {
      final confirm = await _showConfirmationDialog(
        title: 'Varoitus',
        content: 'Menot ovat suuremmat kuin tulot. Haluatko jatkaa?',
      );
      if (confirm != true) return;
    }

    // Validointi 4: Varoita, jos budjetissa on tyhjiä yläkategorioita
    final emptyCategories = expenseControllers.keys
        .where((category) => expenses[category]!.isEmpty)
        .toList();
    if (emptyCategories.isNotEmpty) {
      final confirm = await _showConfirmationDialog(
        title: 'Varoitus',
        content: 'Budjetissa on tyhjiä yläkategorioita (${emptyCategories.join(', ')}). Haluatko jatkaa?',
      );
      if (confirm != true) return;
    }

    final newBudget = BudgetModel(
      income: income,
      expenses: expenses,
      createdAt: DateTime.now(),
      year: newYear,
      month: newMonth,
    );

    try {
      // Tallennetaan budjetti Firestoreen
      await budgetProvider.saveBudget(authProvider.user!.uid, newBudget);

      // Päivitetään BudgetProvider-tila suoraan
      budgetProvider.setBudget(newBudget);

      if (context.mounted) {
        // Navigoidaan /main-reitille, jotta MainScreen voi hoitaa budjetin latauksen ja bannerien näyttämisen
        Navigator.pushReplacementNamed(
          context,
          '/main',
          arguments: {
            'index': 0, // Asetetaan BudgetScreen-välilehti aktiiviseksi
          },
        );
      }
    } catch (e) {
      print('Error creating budget: $e');
      errorMessage = 'Virhe budjetin tallentamisessa: $e';
    }
  }
}