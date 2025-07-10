import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:budu/features/budget/models/budget_model.dart';

/// Määrittelee tapahtuman tyypin: tulo tai meno.
enum EventType { income, expense }

/// Edustaa yksittäistä meno- tai tulotapahtumaa budjetissa.
/// Päivitetty: Lisätty optional userId (shared-tapauksessa), käytetty BudgetModel:in _parseDate.
class ExpenseEvent {
  /// Tapahtuman yksilöllinen tunniste.
  final String id;
  /// Tapahtuman kategoria (esim. "Ruoka").
  final String category;
  /// Tapahtuman alakategoria (esim. "Aamiainen"), valinnainen.
  final String? subcategory;
  /// Tapahtuman summa euroissa.
  final double amount;
  /// Tapahtuman luontiaika.
  final DateTime createdAt;
  /// Tapahtuman tyyppi: tulo tai meno.
  final EventType type;
  /// Budjetin tunniste, johon tapahtuma liittyy.
  final String budgetId;
  /// Tapahtuman kuvaus, valinnainen.
  final String? description;
  /// Käyttäjän UID, valinnainen (käytössä shared-budjeteissa).
  final String? userId;

  ExpenseEvent({
    required this.id,
    required this.category,
    this.subcategory,
    required this.amount,
    required this.createdAt,
    required this.type,
    required this.budgetId,
    this.description,
    this.userId,
  });

  /// Luo ExpenseEvent-instanssin Map-oliosta, esimerkiksi haettaessa dataa tallennuksesta.
  factory ExpenseEvent.fromMap(Map<String, dynamic> map) {
    try {
      // Tuki vanhalle year/month-datamuodolle
      String budgetId;
      if (map.containsKey('year') && map.containsKey('month')) {
        budgetId = '${map['year']}_${map['month']}';
      } else {
        budgetId = map['budgetId'] as String? ?? 'unknown';
      }

      return ExpenseEvent(
        id: map['id'] as String? ?? 'unknown',
        category: map['category'] as String? ?? 'Ei kategoriaa',
        subcategory: map['subcategory'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        createdAt: BudgetModel.parseDate(map['createdAt']) ?? DateTime.now(), // Käytä BudgetModel:in parsingia duplikaation välttämiseksi
        type: (map['type'] as String?) == 'income' ? EventType.income : EventType.expense,
        budgetId: budgetId,
        description: map['description'] as String?,
        userId: map['userId'] as String?,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Virhe tapahtumadatan parsimisessa',
      );
      throw FormatException('Virheellinen tapahtumadata: $e');
    }
  }

  /// Muuntaa tapahtuman Map-olioksi tallennusta tai serialisointia varten.
  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'category': category,
      'subcategory': subcategory,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'type': type == EventType.income ? 'income' : 'expense',
      'budgetId': budgetId,
      'description': description,
    };
    if (userId != null) map['userId'] = userId;
    return map;
  }
}