import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Palvelu budjettikategorioiden ja alakategorioiden käsittelyyn.
/// Käsittelee alakategorioiden lisäämistä, päivittämistä ja poistamista Firestoreen.
class BudgetSubCategoryService {
  /// Lisää alakategorian budjettiin Firestoreen.
  Future<void> addSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String subcategory,
    required double amount,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      await budgetProvider.addSubcategory(
        userId,
        year,
        month,
        categoryName,
        subcategory,
        amount,
      );
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add subcategory in BudgetSubCategoryService',
      );

      // Heitä virhe eteenpäin, jotta kutsuja (BudgetCategoryController) voi käsitellä sen
      rethrow;
    }
  }

  /// Päivittää alakategorian Firestoreen poistamalla vanhan ja lisäämällä uuden.
  Future<void> updateSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String oldSubcategory,
    required String newSubcategory,
    required double amount,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      await budgetProvider.removeSubcategory(
        userId,
        year,
        month,
        categoryName,
        oldSubcategory,
      );
      await budgetProvider.addSubcategory(
        userId,
        year,
        month,
        categoryName,
        newSubcategory,
        amount,
      );
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update subcategory in BudgetSubCategoryService',
      );

      // Heitä virhe eteenpäin, jotta kutsuja (BudgetCategoryController) voi käsitellä sen
      rethrow;
    }
  }

  /// Poistaa alakategorian budjetista Firestoresta ja siihen liittyvät tapahtumat.
  Future<void> deleteSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String subcategory,
    required bool deleteEvents,
  }) async {
    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

      if (deleteEvents) {
        await expenseProvider.deleteSubcategoryEvents(
          userId: userId,
          year: year,
          month: month,
          category: categoryName,
          subcategory: subcategory,
        );
      }

      await budgetProvider.removeSubcategory(
        userId,
        year,
        month,
        categoryName,
        subcategory,
      );
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete subcategory in BudgetSubCategoryService',
      );

      // Heitä virhe eteenpäin, jotta kutsuja (BudgetCategoryController) voi käsitellä sen
      rethrow;
    }
  }

  /// Validoi alakategorian nimen.
  /// Palauttaa virheviestin, jos nimi on virheellinen, muuten null.
  String? validateSubcategoryName(
    String subcategory,
    Map<String, double> expenses,
    String? editingSubcategory,
  ) {
    if (subcategory.isEmpty) {
      return 'Syötä alakategorian nimi';
    }
    if (subcategory.length > 20) {
      return 'Nimi voi olla\nenintään 20 merkkiä pitkä';
    }
    if (subcategory != editingSubcategory && expenses.containsKey(subcategory)) {
      return 'Alakategorian\nnimi on jo käytössä';
    }
    return null;
  }

  /// Validoi euromäärän.
  /// Palauttaa virheviestin, jos summa on virheellinen, muuten null.
  String? validateAmount(String amountText) {
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) {
      return 'Syötä positiivinen numero';
    }
    if (amount > 99999) {
      return 'Euromäärä voi olla enintään 99 999 €';
    }
    final decimalPlaces = amountText.contains('.') ? amountText.split('.')[1].length : 0;
    if (decimalPlaces > 2) {
      return 'Euromäärä voi sisältää enintään 2 desimaalia';
    }
    return null;
  }

  /// Tarkistaa alakategorioiden maksimimäärän.
  /// Palauttaa virheviestin, jos raja ylittyy, muuten null.
  String? checkSubcategoryLimit(Map<String, double> expenses) {
    final subcategoryCount = expenses.length;
    if (subcategoryCount >= 20) {
      return 'Ala-kategorioiden maksimimäärä saavutettu (20)';
    }
    return null;
  }
}