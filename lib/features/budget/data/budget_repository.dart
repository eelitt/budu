import 'package:budu/features/budget/data/event_repository.dart';
import 'package:budu/features/budget/domain/money.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/budget_model.dart';
import 'package:uuid/uuid.dart';

/// Repositorio budjettitietojen tallentamiseen ja hakemiseen Firestoresta.
/// Kaikki operaatiot keskitetty tänne modulaarisuuden vuoksi.
/// Tukee vanhaa rakennetta taaksepäin yhteensopivuuden vuoksi.
/// Optimointi: Lisätty stream reaaliaikaan, batch-valmius massatoimintoihin.
class BudgetRepository {
  BudgetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _events = EventRepository(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final FirebaseFirestore _firestore;
  final EventRepository _events;

  CollectionReference<Map<String, dynamic>> get _budgetsCollection =>
      _firestore.collection('budgets');

  /// Tallentaa budjetin Firestoreen käyttäjän ID:n ja budjetin ID:n perusteella.
  /// Jos budjetilla ei ole ID:tä, generoidaan uusi UUID.
  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      final budgetId = budget.id ?? const Uuid().v4();
      final docRef = _budgetsCollection.doc(userId).collection('budgets').doc(budgetId);
      await docRef.set(budget.toMap());
    } catch (e) {
      // Raportoidaan virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to save budget to Firestore',
      );
      // Heitetään virhe uudelleen kutsujalle
      throw Exception('Budjetin tallennus epäonnistui: $e');
    }
  }

  /// Hakee budjetin Firestoresta käyttäjän ID:n ja budjetin ID:n perusteella.
  /// Palauttaa null, jos budjettia ei löydy. Tukee vanhaa year_month-muotoa taaksepäin yhteensopivuuden vuoksi.
  Future<BudgetModel?> getBudget(String userId, String budgetId) async {
    try {
      // Yritä ensin uusi budgets-kokoelma
      final docRef = _budgetsCollection.doc(userId).collection('budgets').doc(budgetId);
      DocumentSnapshot doc = await docRef.get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        doc = await docRef.get(const GetOptions(source: Source.serverAndCache));
        if (!doc.exists) {
          // Tuki vanhalle monthly_budgets-rakenteelle
          final parts = budgetId.split('_');
          if (parts.length == 2) {
            final year = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            if (year != null && month != null) {
              final oldDocRef = _budgetsCollection
                  .doc(userId)
                  .collection('monthly_budgets')
                  .doc(budgetId);
              final oldDoc = await oldDocRef.get(const GetOptions(source: Source.serverAndCache));
              if (oldDoc.exists) {
                return BudgetModel.fromMap(oldDoc.data() as Map<String, dynamic>,budgetId);
              }
            }
          }
          return null;
        }
      }
      return BudgetModel.fromMap(doc.data() as Map<String, dynamic>,budgetId);
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
  /// Tukee vanhaa year_month-muotoa taaksepäin yhteensopivuuden vuoksi.
  Stream<BudgetModel?> getBudgetStream(String userId, String budgetId) {
    return _budgetsCollection
        .doc(userId)
        .collection('budgets')
        .doc(budgetId)
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists) {
        return BudgetModel.fromMap(doc.data() as Map<String, dynamic>, budgetId);
      } else {
        // Tuki vanhalle monthly_budgets-rakenteelle
        final parts = budgetId.split('_');
        if (parts.length == 2) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          if (year != null && month != null) {
            final oldDoc = await _budgetsCollection
                .doc(userId)
                .collection('monthly_budgets')
                .doc(budgetId)
                .get();
            if (oldDoc.exists) {
              return BudgetModel.fromMap(oldDoc.data() as Map<String, dynamic>, budgetId);
            }
          }
        }
        return null;
      }
    }).handleError((e) {
      // Raportoidaan virhe Crashlyticsiin
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to stream budget from Firestore',
      );
      throw Exception('Budjetin stream epäonnistui: $e');
    });
  }

  /// Hakee saatavilla olevat budjetit Firestoresta (optimoitu where-ehdoilla).
  Future<List<BudgetModel>> getAvailableBudgets(String userId) async {
    try {
      final snapshot = await _budgetsCollection
          .doc(userId)
          .collection('budgets')
          .where('isPlaceholder', isEqualTo: false) // Optimointi: Suodata placeholderit pois
          .orderBy('startDate', descending: true) // Järjestä uusimmasta vanhimpaan
          .get();

      final List<BudgetModel> budgets = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('income') && data.containsKey('expenses')) {
          budgets.add(BudgetModel.fromMap(data, doc.id));
        }
      }
      return budgets;
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to fetch available budgets',
      );
      print('Error fetching budgets: $e');
      throw Exception('Budjettien haku epäonnistui: $e');
    }
  }

  Future<void> updateIncome({
    required String userId,
    required String budgetId,
    required double income,
  }) async {
    try {
      await _budgetsCollection
          .doc(userId)
          .collection('budgets')
          .doc(budgetId)
          .update({'income': income});
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to update income for $budgetId',
      );
      throw Exception('Tulojen päivitys epäonnistui: $e');
    }
  }

  /// Load, add or subtract [amount], write. Missing plan throws.
  Future<double> adjustIncome({
    required String userId,
    required String budgetId,
    required double amount,
    required bool add,
  }) async {
    final budget = await getBudget(userId, budgetId);
    if (budget == null) {
      throw Exception('Budjettia ei löydy');
    }
    final updated = add
        ? incomeAfterAdd(budget.income, amount)
        : incomeAfterSubtract(budget.income, amount);
    await updateIncome(userId: userId, budgetId: budgetId, income: updated);
    return updated;
  }

  /// Deletes the plan and all events (including legacy expenses) in batches.
  Future<void> deleteBudget(String userId, String budgetId) async {
    try {
      await _events.deleteEventsForBudget(userId: userId, budgetId: budgetId);
      await _budgetsCollection
          .doc(userId)
          .collection('budgets')
          .doc(budgetId)
          .delete();
    } catch (e) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to delete budget $budgetId for user $userId',
      );
      throw Exception('Budjetin poisto epäonnistui: $e');
    }
  }
}