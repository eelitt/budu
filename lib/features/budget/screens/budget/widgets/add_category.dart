import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/screens/budget/widgets/category_dialog.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget, joka vastaa kategorian lisäämisestä budjettiin.
/// Näyttää "Lisää kategoria" -painikkeen ja käsittelee kategorian lisäyksen Firestoreen.
/// Rajoittaa kategorioiden määrän 25:een ja näyttää harmaan painikkeen, jos raja on saavutettu.
class AddCategory extends StatelessWidget {
  const AddCategory({super.key});

  /// Lisää uuden kategorian budjettiin Firestoreen.
  /// [categoryName] on lisättävän kategorian nimi.
  Future<void> _addCategory(BuildContext context, String categoryName) async {
    try {
      // Haetaan AuthProvider käyttäjän UID:tä varten
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        // Haetaan BudgetProvider budjetin tilan päivittämistä varten
        final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
        final now = DateTime.now();
        // Lisätään kategoria Firestoreen BudgetProviderin kautta
        await budgetProvider.addCategory(
          userId: authProvider.user!.uid,
          year: now.year,
          month: now.month,
          category: categoryName,
        );
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Kategorian lisääminen epäonnistui AddCategory:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Kategorian lisääminen epäonnistui: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Haetaan budjetti BudgetProvider:ilta kategorioiden tarkistamiseksi
    final budget = Provider.of<BudgetProvider>(context).budget;
    if (budget == null) {
      return const SizedBox.shrink(); // Jos budjettia ei ole, ei näytetä painiketta
    }

    // Tarkistetaan kategorioiden määrä
    final categoryCount = budget.expenses.length;
    const maxCategories = 25; // Kategorioiden enimmäismäärä
    final isCategoryLimitReached = categoryCount >= maxCategories;

    return ElevatedButton(
      onPressed: isCategoryLimitReached
          ? () {
              // Näytetään snackbar-ilmoitus, jos kategorioiden maksimimäärä on saavutettu
              showSnackBar(
                context,
                'Kategorioiden maksimimäärä ($maxCategories) saavutettu.',
                duration: const Duration(seconds: 3),
              );
            }
          : () async {
              // Näytä dialogi kategorian valitsemiseksi, jos raja ei ole saavutettu
              final selectedCategory = await showAddCategoryDialog(
                context: context,
                currentExpenses: budget.expenses,
              );
              // Jos kategoria valittiin, lisää se budjettiin
              if (selectedCategory != null) {
                await _addCategory(context, selectedCategory);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isCategoryLimitReached ? Colors.grey[400] : Colors.blueGrey[800], // Harmaa, jos raja saavutettu
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16),
          SizedBox(width: 4),
          Text('Lisää kategoria'),
        ],
      ),
    );
  }
}