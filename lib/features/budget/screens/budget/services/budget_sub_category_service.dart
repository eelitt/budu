import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Palvelu budjettikategorioiden ja alakategorioiden käsittelyyn.
/// Käsittelee alakategorioiden lisäämistä, päivittämistä ja poistamista Firestoreen.
/// Tukee sekä henkilökohtaisia (BudgetProvider) että yhteistalousbudjetteja (SharedBudgetProvider).
class BudgetSubCategoryService {
  /// Lisää alakategorian budjettiin Firestoreen.
  Future<void> addSubcategory({
    required BuildContext context,
    required String userId,
    required String budgetId,
    required String categoryName,
    required String subcategory,
    required double amount,
    bool isSharedBudget = false,
    BudgetModel? sharedBudget,
  }) async {
    try {
      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti: Päivitä shared_budgets-kokoelma
        final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        if (!updatedExpenses.containsKey(categoryName)) {
          updatedExpenses[categoryName] = {};
        }
        updatedExpenses[categoryName]![subcategory] = amount;
        await sharedBudgetProvider.updateSharedBudget(
          sharedBudgetId: sharedBudget.id!,
          income: sharedBudget.income,
          expenses: updatedExpenses,
          startDate: sharedBudget.startDate,
          endDate: sharedBudget.endDate,
          type: sharedBudget.type,
          isPlaceholder: sharedBudget.isPlaceholder,
        );
      } else {
        // Henkilökohtainen budjetti: Päivitä budgets-kokoelma
        final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
        await budgetProvider.addSubcategory(
          userId,
          budgetId,
          categoryName,
          subcategory,
          amount,
        );
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to add subcategory in BudgetSubCategoryService, isSharedBudget: $isSharedBudget',
      );
      rethrow;
    }
  }

  /// Päivittää alakategorian Firestoreen poistamalla vanhan ja lisäämällä uuden.
  Future<void> updateSubcategory({
    required BuildContext context,
    required String userId,
    required String budgetId,
    required String categoryName,
    required String oldSubcategory,
    required String newSubcategory,
    required double amount,
    bool isSharedBudget = false,
    BudgetModel? sharedBudget,
  }) async {
    try {
      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti: Päivitä shared_budgets-kokoelma
        final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        if (updatedExpenses.containsKey(categoryName)) {
          final subcategories = Map<String, double>.from(updatedExpenses[categoryName]!);
          subcategories.remove(oldSubcategory);
          subcategories[newSubcategory] = amount;
          updatedExpenses[categoryName] = subcategories;
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: sharedBudget.income,
            expenses: updatedExpenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        }
      } else {
        // Henkilökohtainen budjetti: Poista vanha ja lisää uusi alakategoria
        final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
        await budgetProvider.removeSubcategory(
          userId,
          budgetId,
          categoryName,
          oldSubcategory,
        );
        await budgetProvider.addSubcategory(
          userId,
          budgetId,
          categoryName,
          newSubcategory,
          amount,
        );
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update subcategory in BudgetSubCategoryService, isSharedBudget: $isSharedBudget',
      );
      rethrow;
    }
  }

  /// Poistaa alakategorian budjetista Firestoresta ja siihen liittyvät tapahtumat.
  Future<void> deleteSubcategory({
    required BuildContext context,
    required String userId,
    required String budgetId,
    required String categoryName,
    required String subcategory,
    required bool deleteEvents,
    bool isSharedBudget = false,
    BudgetModel? sharedBudget,
  }) async {
    try {
      if (isSharedBudget && sharedBudget != null) {
        // Yhteistalousbudjetti: Päivitä shared_budgets-kokoelma ja poista tapahtumat
        final sharedBudgetProvider = Provider.of<SharedBudgetProvider>(context, listen: false);
        final updatedExpenses = Map<String, Map<String, double>>.from(sharedBudget.expenses);
        if (updatedExpenses.containsKey(categoryName)) {
          final subcategories = Map<String, double>.from(updatedExpenses[categoryName]!);
          subcategories.remove(subcategory);
          updatedExpenses[categoryName] = subcategories;
          if (subcategories.isEmpty) {
            updatedExpenses.remove(categoryName);
          }
          await sharedBudgetProvider.updateSharedBudget(
            sharedBudgetId: sharedBudget.id!,
            income: sharedBudget.income,
            expenses: updatedExpenses,
            startDate: sharedBudget.startDate,
            endDate: sharedBudget.endDate,
            type: sharedBudget.type,
            isPlaceholder: sharedBudget.isPlaceholder,
          );
        }
        if (deleteEvents) {
          await deleteSharedSubcategoryEvents(
            userId: userId,
            sharedBudgetId: sharedBudget.id!,
            category: categoryName,
            subcategory: subcategory,
          );
        }
      } else {
        // Henkilökohtainen budjetti: Poista alakategoria ja tapahtumat
        final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
        final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

        if (deleteEvents) {
          await expenseProvider.deleteSubcategoryEvents(
            userId: userId,
            budgetId: budgetId,
            category: categoryName,
            subcategory: subcategory,
            isSharedBudget: isSharedBudget,
          );
        }

        await budgetProvider.removeSubcategory(
          userId,
          budgetId,
          categoryName,
          subcategory,
        );
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete subcategory in BudgetSubCategoryService, isSharedBudget: $isSharedBudget',
      );
      rethrow;
    }
  }

  /// Poistaa yhteistalousbudjettiin liittyvät alakategorian tapahtumat Firestoresta.
  Future<void> deleteSharedSubcategoryEvents({
    required String userId,
    required String sharedBudgetId,
    required String category,
    required String subcategory,
  }) async {
    try {
      // Hae tapahtumat Firestoresta shared_budgets-kokoelmasta
      final query = FirebaseFirestore.instance
          .collection('shared_budgets')
          .doc(sharedBudgetId)
          .collection('events')
          .where('category', isEqualTo: category)
          .where('subcategory', isEqualTo: subcategory);
      final snapshot = await query.get();
      // Poista kaikki vastaavat tapahtumat
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      await FirebaseCrashlytics.instance.log(
        'BudgetSubCategoryService: Poistettu alakategorian tapahtumat, sharedBudgetId: $sharedBudgetId, category: $category, subcategory: $subcategory',
      );
    } catch (e, stackTrace) {
      // Raportoi kriittinen virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to delete shared subcategory events for sharedBudgetId $sharedBudgetId, category: $category, subcategory: $subcategory',
      );
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