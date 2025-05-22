import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/budget_model.dart';

/// Repositorio budjettitietojen tallentamiseen ja hakemiseen Firestoresta.
class BudgetRepository {
  final CollectionReference _budgetsCollection = FirebaseFirestore.instance.collection('budgets');

  /// Tallentaa budjetin Firestoreen käyttäjän ID:n, vuoden ja kuukauden perusteella.
  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      await _budgetsCollection
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${budget.year}_${budget.month}')
          .set(budget.toMap());
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to save budget to Firestore',
      );
      // Heitetään virhe uudelleen kutsujalle
      rethrow;
    }
  }

  /// Hakee budjetin Firestoresta käyttäjän ID:n, vuoden ja kuukauden perusteella.
  /// Palauttaa null, jos budjettia ei löydy.
  Future<BudgetModel?> getBudget(String userId, int year, int month) async {
    try {
      final docRef = _budgetsCollection
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${year}_$month');
      
      DocumentSnapshot doc = await docRef.get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        doc = await docRef.get(const GetOptions(source: Source.serverAndCache));
        if (!doc.exists) return null;
      }
      
      return BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to get budget from Firestore',
      );
      // Heitetään virhe uudelleen kutsujalle
      throw Exception('Budjetin haku epäonnistui: $e');
    }
  }

  /// Palauttaa budjetin streamin Firestoresta reaaliaikaista kuuntelua varten.
  /// Virheenkäsittely suoritetaan streamin kuuntelijoissa (esim. BudgetProvider).
  Stream<BudgetModel?> getBudgetStream(String userId, int year, int month) {
    return _budgetsCollection
        .doc(userId)
        .collection('monthly_budgets')
        .doc('${year}_$month')
        .snapshots()
        .map((doc) => doc.exists ? BudgetModel.fromMap(doc.data() as Map<String, dynamic>) : null);
  }
}