import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../budget/models/budget_model.dart';
import '../../budget/providers/budget_provider.dart';

class ChatbotBudgetSaver {
  final bool isCompleted;
  final double income;
  final Map<String, Map<String, double>> expenses;
  final String budgetType; // monthly, biweekly
  final DateTime startDate;
  final DateTime endDate;

  ChatbotBudgetSaver({
    required this.isCompleted,
    required this.income,
    required this.expenses,
    required this.budgetType,
    required this.startDate,
    required this.endDate,
  });

  Future<void> saveBudget(BuildContext context, String userId) async {
    if (isCompleted) {
      try {
        final budgetId = Uuid().v4();
        final budget = BudgetModel(
          id: budgetId,
          income: income,
          expenses: expenses,
          createdAt: DateTime.now(),
          startDate: startDate,
          endDate: endDate,
          type: budgetType,
        );
        await Provider.of<BudgetProvider>(context, listen: false).saveBudget(userId, budget);
        await FirebaseCrashlytics.instance.log('Chatbot: Budjetti tallennettu onnistuneesti, ID: $budgetId, Tyyppi: $budgetType');
      } catch (e, stackTrace) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Chatbot: Budjetin tallennus epäonnistui käyttäjälle $userId',
        );
        throw Exception('Budjetin tallennus epäonnistui: $e');
      }
    } else {
      await FirebaseCrashlytics.instance.log('Chatbot: Budjetin tallennus peruutettu, ei valmis');
    }
  }
}