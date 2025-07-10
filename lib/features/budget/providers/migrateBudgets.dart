import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Migroi vanhat kuukausipohjaiset budjetit ja niiden tapahtumat uuteen aikavälipohjaiseen rakenteeseen.
/// Säilyttää vanhan datan (monthly_budgets ja expenses) erillään ja estää duplikaattien luomisen.
Future<void> migrateBudgets(String userId) async {
  try {
    // Hae vanhat budjetit monthly_budgets-kokoelmasta
    final oldBudgetsSnapshot = await FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('monthly_budgets')
        .get();

    // Hae olemassa olevat budjetit uudesta budgets-kokoelmasta duplikaattien tarkistamiseksi
    final existingBudgetsSnapshot = await FirebaseFirestore.instance
        .collection('budgets')
        .doc(userId)
        .collection('budgets')
        .get();
    final existingBudgetIds = existingBudgetsSnapshot.docs.map((doc) => doc.id).toSet();

    for (var doc in oldBudgetsSnapshot.docs) {
      final oldBudgetId = doc.id;

      // Ohita, jos budjetti on jo migroitu
      if (existingBudgetIds.contains(oldBudgetId)) {
        print('Migraatio: Budjetti $oldBudgetId on jo olemassa uudessa kokoelmassa, ohitetaan');
        continue;
      }

      final data = doc.data();
      final parts = doc.id.split('_');
      final year = int.tryParse(parts[0]) ?? DateTime.now().year;
      final month = int.tryParse(parts[1]) ?? DateTime.now().month;
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);

      // Parsek createdAt, tukee sekä Timestamp että String (ISO 8601)
      final createdAt = _parseDate(data['createdAt']) ?? DateTime.now();

      // Luo uusi budjetti
      final newBudget = {
        'income': data['income'] ?? 0.0,
        'expenses': data['expenses'] ?? {},
        'createdAt': createdAt.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'type': 'monthly',
        'isPlaceholder': data['isPlaceholder'] ?? false,
      };

      // Tallenna budjetti uuteen budgets-kokoelmaan
      await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('budgets')
          .doc(oldBudgetId)
          .set(newBudget);
      print('Migraatio: Budjetti $oldBudgetId siirretty uuteen rakenteeseen');

      // Siirrä tapahtumat expenses-alakokoelmasta events-kokoelmaan
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('monthly_budgets')
          .doc(oldBudgetId)
          .collection('expenses')
          .get();

      final existingEventIds = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(userId)
          .collection('events')
          .where('budgetId', isEqualTo: oldBudgetId)
          .get()
          .then((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

      for (var expenseDoc in expensesSnapshot.docs) {
        final expenseId = expenseDoc.id;

        // Ohita, jos tapahtuma on jo migroitu
        if (existingEventIds.contains(expenseId)) {
          print('Migraatio: Tapahtuma $expenseId on jo migroitu budjetille $oldBudgetId, ohitetaan');
          continue;
        }

        final expenseData = expenseDoc.data();
        // Käytä set-operaatiota SetOptions.merge():llä FieldValue.delete():n tueksi
        await FirebaseFirestore.instance
            .collection('budgets')
            .doc(userId)
            .collection('events')
            .doc(expenseId)
            .set(
          {
            ...expenseData,
            'budgetId': oldBudgetId,
            'year': FieldValue.delete(), // Poista vanha year-kenttä
            'month': FieldValue.delete(), // Poista vanha month-kenttä
            'id': FieldValue.delete(), // Poista redundantti id-kenttä
          },
          SetOptions(merge: true),
        );
        print('Migraatio: Tapahtuma $expenseId siirretty budjetille $oldBudgetId');
      }

      // Laita lokitus Crashlyticsiin migraation onnistumisesta
      await FirebaseCrashlytics.instance.log('Migraatio: Budjetti $oldBudgetId ja sen ${expensesSnapshot.docs.length} tapahtumaa siirretty onnistuneesti');
    }

    // Valinnaisesti: Poista vanha monthly_budgets-kokoelma migraation jälkeen
    // for (var doc in oldBudgetsSnapshot.docs) {
    //   await doc.reference.delete();
    //   print('Migraatio: Poistettu vanha budjetti ${doc.id} monthly_budgets-kokoelmasta');
    // }
  } catch (e, stackTrace) {
    // Raportoi virhe Crashlyticsiin
    await FirebaseCrashlytics.instance.recordError(
      e,
      stackTrace,
      reason: 'Budjettien migraatio epäonnistui käyttäjälle $userId',
    );
    print('Migraatio epäonnistui: $e');
    throw e;
  }
}

/// Apumetodi päivämäärän parsimiseen, tukee Timestamp ja String (ISO 8601) -formaatteja.
DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  } else if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}