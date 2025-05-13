import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BudgetScreenController {
  final BuildContext context;
  final VoidCallback onStateChanged;

  BudgetScreenController({
    required this.context,
    required this.onStateChanged,
  });

  Future<void> loadBudget({
    required String userId,
    required int year,
    required int month,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    try {
      await budgetProvider.loadBudget(userId, year, month);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, int>>> loadAvailableMonths({
    required String userId,
    required ValueNotifier<Map<String, int>?> selectedMonth,
    required ValueNotifier<int> currentYear,
    required ValueNotifier<int> currentMonth,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    final months = await budgetProvider.getAvailableBudgetMonths(userId);
    final availableMonths = months.toSet().toList();
    if (availableMonths.isNotEmpty) {
      selectedMonth.value = availableMonths.first;
      currentYear.value = selectedMonth.value!['year']!;
      currentMonth.value = selectedMonth.value!['month']!;
    } else {
      selectedMonth.value = null;
    }
    return availableMonths;
  }

  Future<void> resetBudgetExpenses({
    required String userId,
    required int year,
    required int month,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    await budgetProvider.resetBudgetExpenses(userId, year, month);
  }

  Future<List<Map<String, int>>> deleteBudget({
    required String userId,
    required int year,
    required int month,
    required List<Map<String, int>> availableMonths,
    required ValueNotifier<Map<String, int>?> selectedMonth,
    required ValueNotifier<int> currentYear,
    required ValueNotifier<int> currentMonth,
  }) async {
    final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
    await budgetProvider.deleteBudget(userId, year, month);
    // Päivitetään saatavilla olevat budjettikuukaudet poiston jälkeen
    final updatedMonths = await loadAvailableMonths(
      userId: userId,
      selectedMonth: selectedMonth,
      currentYear: currentYear,
      currentMonth: currentMonth,
    );
    return updatedMonths;
  }

  void dispose() {
    // Tässä ei ole resursseja, jotka vaatisivat vapauttamista, mutta metodi on lisätty yhteensopivuuden vuoksi
  }
}