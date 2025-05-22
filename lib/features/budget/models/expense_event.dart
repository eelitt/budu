import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Määrittelee tapahtuman tyypin: tulo tai meno.
enum EventType { income, expense }

/// Edustaa yksittäistä meno- tai tulotapahtumaa budjetissa.
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
  /// Tapahtuman vuosi.
  final int year;
  /// Tapahtuman kuukausi (1-12).
  final int month;
  /// Tapahtuman kuvaus, valinnainen.
  final String? description;

  ExpenseEvent({
    required this.id,
    required this.category,
    this.subcategory,
    required this.amount,
    required this.createdAt,
    required this.type,
    required this.year,
    required this.month,
    this.description,
  });

  /// Luo ExpenseEvent-instanssin Map-oliosta, esimerkiksi haettaessa dataa tallennuksesta.
  factory ExpenseEvent.fromMap(Map<String, dynamic> map) {
    try {
      return ExpenseEvent(
        id: map['id'] as String? ?? 'unknown', // Oletusarvo, jos id puuttuu
        category: map['category'] as String? ?? 'Ei kategoriaa', // Oletusarvo, jos kategoria puuttuu
        subcategory: map['subcategory'] as String?, // Voi olla null
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0, // Oletusarvo 0.0, jos summa puuttuu
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(), // Oletusarvo nykyinen aika
        type: (map['type'] as String?) == 'income' ? EventType.income : EventType.expense, // Oletusarvo meno
        year: map['year'] as int? ?? DateTime.now().year, // Oletusarvo nykyinen vuosi
        month: map['month'] as int? ?? DateTime.now().month, // Oletusarvo nykyinen kuukausi
        description: map['description'] as String?, // Voi olla null
      );
    } catch (e, stackTrace) {
      // Raportoi kriittinen virhe Crashlyticsiin
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Virhe tapahtumadatan parsimisessa',
      );
      // Heitä hallittu virhe kutsujalle
      throw FormatException('Virheellinen tapahtumadata: $e');
    }
  }

  /// Muuntaa tapahtuman Map-olioksi tallennusta tai serialisointia varten.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'subcategory': subcategory,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'type': type == EventType.income ? 'income' : 'expense',
      'year': year,
      'month': month,
      'description': description,
    };
  }
}