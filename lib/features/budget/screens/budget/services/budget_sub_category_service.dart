import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetSubCategoryService {
  // Lisää alakategoria
  Future<void> addSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String subcategory,
    required double amount,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    await budgetProvider.addSubcategory(
      userId,
      year,
      month,
      categoryName,
      subcategory,
      amount,
    );
  }

  // Päivitä alakategoria (poista vanha ja lisää uusi)
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
  }

  // Poista alakategoria ja siihen liittyvät tapahtumat
  Future<void> deleteSubcategory({
    required BuildContext context,
    required String userId,
    required int year,
    required int month,
    required String categoryName,
    required String subcategory,
    required bool deleteEvents,
  }) async {
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

    await expenseProvider.loadExpenses(
      userId,
      year,
      month,
    );
  }

  // Validoi alakategorian nimi
  String? validateSubcategoryName(
    String subcategory,
    Map<String, double> expenses,
    String? editingSubcategory,
  ) {
    if (subcategory.isEmpty) {
      return 'Syötä alakategorian nimi';
    }
    if (subcategory.length > 30) {
      return 'Nimi voi olla enintään 30 merkkiä pitkä';
    }
    if (subcategory != editingSubcategory && expenses.containsKey(subcategory)) {
      return 'Tämä alakategorian nimi on jo käytössä';
    }
    return null;
  }

  // Validoi euromäärä
  String? validateAmount(String amountText) {
    final amount = double.tryParse(amountText);
    if (amount == null || amount < 0) {
      return 'Syötä positiivinen numero';
    }
    if (amount > 1000000) {
      return 'Euromäärä voi olla enintään 1 000 000 €';
    }
    final decimalPlaces = amountText.contains('.') ? amountText.split('.')[1].length : 0;
    if (decimalPlaces > 2) {
      return 'Euromäärä voi sisältää enintään 2 desimaalia';
    }
    return null;
  }

  // Tarkista alakategorioiden maksimimäärä
  String? checkSubcategoryLimit(Map<String, double> expenses) {
    final subcategoryCount = expenses.length;
    if (subcategoryCount >= 6) {
      return 'Ilmaisversiossa voit lisätä enintään 6 alakategoriaa per yläkategoria.';
    }
    return null;
  }
}