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
      backgroundColor: Colors.white, // Asetetaan taustaväri valkoiseksi
      title: Text(
        'Poista alakategoria',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
      ),
      content: Text(
        'Haluatko poistaa alakategorian "$subcategory"?',
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Poista',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                ),
          ),
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
        backgroundColor: Colors.white, // Asetetaan taustaväri valkoiseksi
        title: Text(
          'Meno-tapahtumat löydetty',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        content: Text(
          'Alakategoriassa "$subcategory" on meno-tapahtumia. Poistetaanko myös tapahtumat?',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Poista kaikki',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                  ),
            ),
          ),
        ],
      ),
    );
    return deleteEvents ?? false;
  }

  // Jos meno-tapahtumia ei ole, jatketaan poistoa
  return true;
}