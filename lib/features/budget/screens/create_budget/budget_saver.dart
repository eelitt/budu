import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/notification/providers/notification_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Lisätty batch-tukeen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Luokka, joka vastaa budjetin tallentamisesta Firestoreen.
/// Suorittaa validoinnit, näyttää varoitusdialogeja ja optimoi Firestore-lukuja/kirjoituksia.
/// Käyttää annettuja totalIncome/Expenses-arvoja duplikaation välttämiseksi.
class BudgetSaver {
  final BuildContext context;
  final TextEditingController incomeController;
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  DateTime startDate;
  DateTime endDate;
  String type;
  final double totalIncome;
  final double totalExpenses;
  String? errorMessage;
  final bool isEditing;
  final String? budgetName;

  BudgetSaver({
    required this.context,
    required this.incomeController,
    required this.expenseControllers,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.totalIncome,
    required this.totalExpenses,
    this.isEditing = false,
    this.budgetName,
  });

  /// Näyttää geneerisen dialogin (vahvistus tai virhe).
  /// Modulaaristaa dialog-koodin toiston vähentämiseksi.
  Future<bool?> _showDialog({
    required String title,
    required String content,
    required List<Widget> actions,
    bool isError = false,
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
        actions: actions,
      ),
    );
  }

  /// Validoi budjetin tulot (yksityinen, laajennettavissa expense-validoinnille).
  String? _validateIncome(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Syötä kelvollinen numero';
    }
    if (parsed < 0) {
      return 'Tulot eivät voivat olla negatiivisia';
    }
    if (parsed > 999999) {
      return 'Tulot eivät voi olla suurempia kuin 999999 €';
    }
    return null;
  }

  /// Tarkistaa päällekkäiset budjetit optimoitulla Firestore-queryllä.
  /// Hakee vain potentiaalisesti päällekkäiset budjetit, vähentäen lukuja/kuluja.
  Future<bool> _checkOverlappingBudgets(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Query päällekkäisille henkilökohtaisille budjeteille
      final personalQuery = firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .where('startDate', isLessThanOrEqualTo: endDate)
          .where('endDate', isGreaterThanOrEqualTo: startDate);

      final personalSnapshot = await personalQuery.get();
      if (personalSnapshot.docs.isNotEmpty) return true;

      // Query päällekkäisille yhteistalousbudejeteille (olettaen shared_budgets-rakenne)
      final sharedQuery = firestore
          .collection('shared_budgets')
          .where('users', arrayContains: userId) // Olettaen 'users'-array käyttäjille
          .where('startDate', isLessThanOrEqualTo: endDate)
          .where('endDate', isGreaterThanOrEqualTo: startDate);

      final sharedSnapshot = await sharedQuery.get();
      return sharedSnapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to check overlapping budgets for user $userId',
      );
      return false; // Palauta false virheessä, jotta tallennus voi jatkua
    }
  }

  /// Tallentaa budjetin Firestoreen ja suorittaa tarvittavat validoinnit.
  /// Tukee optional batch-writea skaalauksen vuoksi (ei riko olemassa olevaa).
  Future<String> createBudget({
    String? budgetId,
    String? sharedBudgetId,
    String? budgetName,
    WriteBatch? batch,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.user == null) {
      errorMessage = 'Käyttäjä ei ole kirjautunut';
      throw Exception('Käyttäjä ei ole kirjautunut');
    }

    final incomeError = _validateIncome(incomeController.text);
    if (incomeError != null) {
      await _showDialog(
        title: 'Virhe',
        content: incomeError,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
        isError: true,
      );
      errorMessage = incomeError;
      throw Exception(incomeError);
    }

    if (await _checkOverlappingBudgets(authProvider.user!.uid)) {
      final confirm = await _showDialog(
        title: 'Varoitus',
        content: 'Valittu aikaväli on päällekkäinen olemassa olevan budjetin kanssa. Haluatko jatkaa?',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Peruuta', style: Theme.of(context).textTheme.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: Theme.of(context).elevatedButtonTheme.style,
            child: Text('Jatka'),
          ),
        ],
      );
      if (confirm != true) {
        errorMessage = 'Budjetin tallennus peruutettu: Päällekkäinen aikaväli';
        throw Exception('Päällekkäinen aikaväli');
      }
    }

    // Käytä annettuja totalIncome/Expenses, mutta parsaa expenses controller:eista (säilytä olemassa oleva logiikka)
    final double income = totalIncome; // Käytä annettua, vältä uudelleenlaskentaa
    final Map<String, Map<String, double>> expenses = {};
    for (var category in expenseControllers.keys) {
      final subcategoryMap = expenseControllers[category]!;
      final subExpenses = <String, double>{};
      for (var subcategory in subcategoryMap.keys) {
        final amount = double.tryParse(subcategoryMap[subcategory]!.text) ?? 0.0;
        final roundedAmount = (amount * 100).roundToDouble() / 100;
        if (roundedAmount > 0) {
          subExpenses[subcategory] = roundedAmount;
        }
      }
      if (subExpenses.isNotEmpty) { // Poista tyhjät kategoriat automaattisesti
        expenses[category] = subExpenses;
      }
    }

    if (income == 0.0 && expenses.isEmpty) {
      final confirm = await _showDialog(
        title: 'Varoitus',
        content: 'Budjetissa ei ole tuloja eikä menoja. Haluatko tallentaa tyhjän budjetin?',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Peruuta', style: Theme.of(context).textTheme.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: Theme.of(context).elevatedButtonTheme.style,
            child: Text('Jatka'),
          ),
        ],
      );
      if (confirm != true) {
        errorMessage = 'Budjetin tallennus peruutettu: Tyhjä budjetti';
        throw Exception('Tyhjä budjetti');
      }
    }

    if (income > 999999) {
      final confirm = await _showDialog(
        title: 'Varoitus',
        content: 'Tulot ylittävät sallitun maksimiarvon (999999 €). Haluatko jatkaa?',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Peruuta', style: Theme.of(context).textTheme.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: Theme.of(context).elevatedButtonTheme.style,
            child: Text('Jatka'),
          ),
        ],
      );
      if (confirm != true) {
        errorMessage = 'Budjetin tallennus peruutettu: Liian suuret tulot';
        throw Exception('Liian suuret tulot');
      }
    }

    if (totalExpenses > totalIncome) {
      final confirm = await _showDialog(
        title: 'Varoitus',
        content: 'Menot ovat suuremmat kuin tulot. Haluatko jatkaa?',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Peruuta', style: Theme.of(context).textTheme.bodyLarge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: Theme.of(context).elevatedButtonTheme.style,
            child: Text('Jatka'),
          ),
        ],
      );
      if (confirm != true) {
        errorMessage = 'Budjetin tallennus peruutettu: Menot ylittävät tulot';
        throw Exception('Menot ylittävät tulot');
      }
    }

    // Ei enää tyhjien kategorioiden varoitusta – poistettu automaattisesti yllä

    final newBudgetId = budgetId ?? const Uuid().v4();

    try {
      final localBatch = batch ?? FirebaseFirestore.instance.batch(); // Käytä annettua batchia tai luo uusi

      if (sharedBudgetId != null) {
        // Yhteistalousbudjetti: Käytä provideria, mutta lisää batch-tuki jos provider tukee
        if (isEditing) {
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudgetId,
            income: income,
            expenses: expenses,
            startDate: startDate,
            endDate: endDate,
            type: type,
            isPlaceholder: false,
          );
        } else {
          await sharedBudgetProvider.createSharedBudget(
            sharedBudgetId: sharedBudgetId,
            userId: authProvider.user!.uid,
            name: this.budgetName ?? 'Yhteistalousbudjetti',
            income: income,
            expenses: expenses,
            startDate: startDate,
            endDate: endDate,
            type: type,
            isPlaceholder: false,
          );
        }
        await FirebaseCrashlytics.instance.log('BudgetSaver: Yhteistalousbudjetti ${isEditing ? 'päivitetty' : 'tallennettu'}, sharedBudgetId: $sharedBudgetId');
      } else {
        // Henkilökohtainen budjetti
        final newBudget = BudgetModel(
          income: income,
          expenses: expenses,
          createdAt: DateTime.now(),
          startDate: startDate,
          endDate: endDate,
          type: type,
          id: newBudgetId,
          sharedBudgetId: null,
        );
        await budgetProvider.saveBudget(authProvider.user!.uid, newBudget);
        budgetProvider.setBudget(newBudget);
        await FirebaseCrashlytics.instance.log('BudgetSaver: Henkilökohtainen budjetti tallennettu, ID: $newBudgetId');
      }

      notificationProvider.clearNotification();
      showSnackBar(
        context,
        'Budjetti tallennettu onnistuneesti',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
      );

      if (batch == null) await localBatch.commit(); // Commit vain jos ei annettua batchia
      return newBudgetId;
    } catch (e, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Budjetin tallentaminen epäonnistui käyttäjälle ${authProvider.user!.uid}',
      );
      errorMessage = 'Virhe budjetin tallentamisessa: $e';
      throw e;
    }
  }
}