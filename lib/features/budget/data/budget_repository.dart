import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../models/budget_model.dart';
import 'package:uuid/uuid.dart';

/// Repositorio budjettitietojen tallentamiseen ja hakemiseen Firestoresta.
/// Kaikki operaatiot keskitetty tänne modulaarisuuden vuoksi.
/// Tukee vanhaa rakennetta taaksepäin yhteensopivuuden vuoksi.
/// Optimointi: Lisätty stream reaaliaikaan, batch-valmius massatoimintoihin.
class BudgetRepository {
  final CollectionReference _budgetsCollection = FirebaseFirestore.instance.collection('budgets');

  /// Tallentaa budjetin Firestoreen käyttäjän ID:n ja budjetin ID:n perusteella.
  /// Jos budjetilla ei ole ID:tä, generoidaan uusi UUID.
  /// Tukee optional batch-write:a kuluja vähentäen (jos annettu, ei committaa tässä).
  Future<void> saveBudget(String userId, BudgetModel budget, {WriteBatch? batch}) async {
    try {
      final budgetId = budget.id ?? const Uuid().v4();
      final docRef = _budgetsCollection.doc(userId).collection('budgets').doc(budgetId);
      if (batch != null) {
        batch.set(docRef, budget.toMap());
      } else {
        await docRef.set(budget.toMap());
      }
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
      final snapshot = await FirebaseFirestore.instance
          .collection('budgets')
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

  /// Palauttaa streamin saatavilla olevista budjeteista reaaliaikaista kuuntelua varten (optimoitu limit + where).
  Stream<List<BudgetModel>> getAvailableBudgetsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('budgets')
        .where('isPlaceholder', isEqualTo: false)
        .orderBy('startDate', descending: true)
        .limit(50) // Optimointi: Limittaa tulokset kuluja vähentäen
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BudgetModel.fromMap(doc.data(), doc.id)).toList())
        .handleError((e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Failed to stream available budgets',
      );
      throw Exception('Saatavilla olevien budjettien stream epäonnistui: $e');
    });
  }
}