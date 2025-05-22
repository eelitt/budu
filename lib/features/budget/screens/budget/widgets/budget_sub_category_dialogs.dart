import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Näyttää vahvistusdialogit alakategorian poistamiselle ja tarkistaa, onko alakategorialla meno-tapahtumia.
/// Jos meno-tapahtumia on, kysyy käyttäjältä, poistetaanko myös tapahtumat.
/// Palauttaa true, jos poisto vahvistetaan ja tapahtumat (jos olemassa) poistetaan, muuten false.
Future<bool> confirmDeleteSubcategory({
  required BuildContext context,
  required String subcategory, // Poistettavan alakategorian nimi
  required String categoryName, // Yläkategorian nimi, johon alakategoria kuuluu
}) async {
  // Näytetään ensimmäinen dialogi, jossa kysytään vahvistusta alakategorian poistamiselle
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white, // Dialogin taustaväri
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
        // Peruuta-painike, joka sulkee dialogin ja palauttaa false
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Peruuta',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        // Poista-painike, joka vahvistaa poiston ja palauttaa true
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

  // Jos poistoa ei vahvisteta, palautetaan false
  if (confirmed != true) {
    return false; // Peruutettu, ei jatketa
  }

  // Haetaan AuthProvider ja ExpenseProvider meno-tapahtumien tarkistamista varten
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
  if (authProvider.user == null) {
    return false; // Jos käyttäjää ei ole, ei voida jatkaa
  }

  // Tarkistetaan, onko alakategorialla meno-tapahtumia
  final now = DateTime.now();
  final hasEvents = await expenseProvider.hasSubcategoryEvents(
    userId: authProvider.user!.uid,
    year: now.year,
    month: now.month,
    category: categoryName,
    subcategory: subcategory,
  );

  if (hasEvents) {
    // Jos meno-tapahtumia on, näytetään toinen dialogi, jossa kysytään, poistetaanko myös tapahtumat
    final deleteEvents = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Dialogin taustaväri
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
          // Peruuta-painike, joka sulkee dialogin ja palauttaa false
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Peruuta',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          // Poista kaikki -painike, joka vahvistaa tapahtumien poiston ja palauttaa true
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
    // Palautetaan true, jos tapahtumat halutaan poistaa, muuten false
    return deleteEvents ?? false;
  }

  // Jos meno-tapahtumia ei ole, jatketaan poistoa (palautetaan true)
  return true;
}