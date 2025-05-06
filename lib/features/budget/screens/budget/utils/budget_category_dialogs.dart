// lib/features/budget/screens/budget/utils/budget_category_dialogs.dart
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<bool> confirmDeleteSubcategory({
  required BuildContext context,
  required String subcategory,
  required String categoryName,
}) async {
  // Ensin varmistetaan poisto
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Poista alakategoria'),
      content: Text('Haluatko poistaa alakategorian "$subcategory"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Peruuta'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Poista'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return false; // Peruutettu, ei jatketa
  }

  // Tarkistetaan, onko alakategorialla meno-tapahtumia
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
  if (authProvider.user == null) {
    return false;
  }

  final now = DateTime.now();
  final hasEvents = await expenseProvider.hasSubcategoryEvents(
    userId: authProvider.user!.uid,
    year: now.year,
    month: now.month,
    category: categoryName,
    subcategory: subcategory,
  );

  if (hasEvents) {
    // Jos meno-tapahtumia on, näytetään toinen dialogi
    final deleteEvents = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meno-tapahtumat löydetty'),
        content: Text('Alakategoriassa "$subcategory" on meno-tapahtumia. Poistetaanko myös tapahtumat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Poista kaikki'),
          ),
        ],
      ),
    );
    return deleteEvents ?? false;
  }

  // Jos meno-tapahtumia ei ole, jatketaan poistoa
  return true;
}