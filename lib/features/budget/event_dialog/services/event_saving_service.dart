import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/budget/event_dialog/event_validator.dart';
import 'package:budu/features/budget/models/expense_event.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../managers/add_event_dialog_state_manager.dart';

/// Palveluluokka tapahtumien tallentamiseen AddEventDialogissa.
/// Vastaa tapahtuman luomisesta, validoinnista ja tallentamisesta Firestoreen.
/// Nyt tukee sekä henkilökohtaista että yhteistalousbudjettia:
/// - Lisätty valinnainen isSharedBudget-parametri saveEvent-metodiin.
/// - Välittää isSharedBudget ExpenseProvider.addExpense:lle.
/// - Kaikki muu toiminnallisuus (validointi, error handling, success/failure callbacks)
///   säilytetty ennallaan – vain lisätty tuki yhteistalousbudjetille.
class EventSavingService {
  final BuildContext context;

  EventSavingService(this.context);

  /// Tallentaa tapahtuman Firestoreen ja päivittää budjetin, jos kyseessä on tulo
  Future<void> saveEvent({
    required AddEventDialogStateManager stateManager,
    required EventValidator validator,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
    bool isSharedBudget = false, // Lisätty: Määrittää, onko yhteistalousbudjetti
  }) async {
    // Nollaa aiemmat virheet
    stateManager.clearErrors();

    // Validoidaan syötteet
    final validationResult = validator.validateEvent(
      isExpense: stateManager.isExpense,
      amountText: stateManager.amountController.text,
      description: stateManager.descriptionController.text,
      selectedCategory: stateManager.selectedCategory,
      selectedSubcategory: stateManager.selectedSubcategory,
      authProvider: Provider.of<AuthProvider>(context, listen: false),
      budgetProvider: Provider.of<BudgetProvider>(context, listen: false),
    );

    if (validationResult != null) {
      // Näytetään validointivirheet asianomaisissa kentissä
      if (validationResult.contains('Syötä positiivinen numero') || validationResult.contains('Summa voi olla enintään 99999')) {
        stateManager.updateAmountError(validationResult);
      } else if (validationResult.contains('Kuvaus voi olla enintään 75 merkkiä')) {
        stateManager.updateDescriptionError(validationResult);
      } else if (validationResult.contains('Valitse kategoria')) {
        stateManager.updateCategoryError(validationResult);
      } else if (validationResult.contains('Valitse alakategoria')) {
        stateManager.updateSubcategoryError(validationResult);
      } else if (validationResult.contains('Käyttäjä ei ole kirjautunut')) {
        showSnackBar(
          context,
          validationResult,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blueGrey[700],
        );
        onFailure();
      }
      return;
    }

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null || stateManager.selectedBudgetId == null) {
      showSnackBar(
        context,
        'Käyttäjä ei ole kirjautunut tai budjettia ei ole valittu',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.redAccent,
      );
      onFailure();
      return;
    }

    try {
      // Muunnetaan summa double-tyypiksi
      final amount = double.parse(stateManager.amountController.text);
      // Luodaan uusi ExpenseEvent-olio valitulle budjetille
      final event = ExpenseEvent(
        id: const Uuid().v4(),
        category: stateManager.isExpense ? stateManager.selectedCategory! : 'Tulo',
        subcategory: stateManager.isExpense ? stateManager.selectedSubcategory : null,
        amount: amount,
        createdAt: stateManager.selectedDate,
        type: stateManager.isExpense ? EventType.expense : EventType.income,
        budgetId: stateManager.selectedBudgetId!,
        description: stateManager.descriptionController.text.isNotEmpty ? stateManager.descriptionController.text : null,
      );
      // Tallennetaan tapahtuma Firestoreen – välittää isSharedBudget
      await expenseProvider.addExpense(
        context,
        authProvider.user!.uid,
        event,
        isSharedBudget: isSharedBudget,
      );
      // Päivitetään ExpenseProvider.expenses lataamalla uudelleen
      await expenseProvider.loadExpenses(authProvider.user!.uid, stateManager.selectedBudgetId!, isSharedBudget: isSharedBudget);
      // Kutsutaan onnistumiskäsittelijä
      onSuccess();
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current, reason: 'Tapahtuman tallennus epäonnistui');
      // Näytetään virheilmoitus käyttäjälle
      showSnackBar(
        context,
        'Virhe tallennettaessa tapahtumaa: ${e.toString()}',
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.redAccent,
      );
      // Kutsutaan epäonnistumiskäsittelijä
      onFailure();
    }
  }
}