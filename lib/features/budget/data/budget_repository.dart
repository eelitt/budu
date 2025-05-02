import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';

class BudgetRepository {
  final CollectionReference _budgetsCollection = FirebaseFirestore.instance.collection('budgets');

  Future<void> saveBudget(String userId, BudgetModel budget) async {
    try {
      // Tallennetaan budjetti polkuun budgets/{userId}/{year}_{month}
      await _budgetsCollection
          .doc(userId)
          .collection('monthly_budgets')
          .doc('${budget.year}_${budget.month}')
          .set(budget.toMap());
    } catch (e) {
      rethrow;
    }
  }

 Future<BudgetModel?> getBudget(String userId, int year, int month) async {
  try {
    final docRef = _budgetsCollection
        .doc(userId)
        .collection('monthly_budgets')
        .doc('${year}_${month}');
    
    DocumentSnapshot doc = await docRef.get(const GetOptions(source: Source.server));
    if (!doc.exists) {
      doc = await docRef.get(const GetOptions(source: Source.serverAndCache));
      if (!doc.exists) return null;
    }
    
    return BudgetModel.fromMap(doc.data() as Map<String, dynamic>);
  } catch (e) {
    print('Virhe budjetin haussa: $e'); // Lokitus kehitysvaiheessa
    throw Exception('Budjetin haku epäonnistui: $e');
  }
}
Stream<BudgetModel?> getBudgetStream(String userId, int year, int month) {
  return _budgetsCollection
      .doc(userId)
      .collection('monthly_budgets')
      .doc('${year}_${month}')
      .snapshots()
      .map((doc) => doc.exists ? BudgetModel.fromMap(doc.data() as Map<String, dynamic>) : null);
}
}