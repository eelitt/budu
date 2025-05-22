import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Edustaa budjettia tietylle vuodelle ja kuukaudelle, sisältäen tulot, menot ja muut tiedot.
class BudgetModel {
  /// Budjetin kokonaistulot.
  double income;
  /// Map-rakenne, joka sisältää pääkategoriat ja niiden alakategoriat menoille.
  Map<String, Map<String, double>> expenses;
  /// Budjetin luontiaika.
  final DateTime createdAt;
  /// Budjetin vuosi.
  final int year;
  /// Budjetin kuukausi (1-12).
  final int month;
  /// Merkintä siitä, onko budjetti paikkamerkki (esim. tuleville kuukausille).
  final bool isPlaceholder;

  BudgetModel({
    required this.income,
    required this.expenses,
    required this.createdAt,
    required this.year,
    required this.month,
    this.isPlaceholder = false,
  });

  /// Muuntaa budjetin Map-olioksi tallennusta tai serialisointia varten.
  Map<String, dynamic> toMap() {
    return {
      'income': income,
      'expenses': expenses,
      'createdAt': createdAt.toIso8601String(),
      'year': year,
      'month': month,
      'isPlaceholder': isPlaceholder,
    };
  }

  /// Luo BudgetModel-instanssin Map-oliosta, esimerkiksi haettaessa dataa tallennuksesta.
  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    try {
      return BudgetModel(
        income: (map['income'] as num?)?.toDouble() ?? 0.0,
        expenses: _parseExpenses(map['expenses']),
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        year: map['year'] as int? ?? DateTime.now().year,
        month: map['month'] as int? ?? DateTime.now().month,
        isPlaceholder: map['isPlaceholder'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      // Raportoi kriittinen virhe Crashlyticsiin
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Virhe budjettidatan parsimisessa',
      );
      // Heitä hallittu virhe kutsujalle
      throw FormatException('Virheellinen budjettidata: $e');
    }
  }

  /// Apumetodi menojen parsimiseen tallennetusta datasta, palauttaa tyhjän mapin, jos data on virheellistä.
  static Map<String, Map<String, double>> _parseExpenses(dynamic expensesData) {
    if (expensesData is Map<String, dynamic>) {
      return expensesData.map((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(
            key,
            value.map((subKey, subValue) =>
                MapEntry(subKey, (subValue as num?)?.toDouble() ?? 0.0)),
          );
        }
        return MapEntry(key, <String, double>{});
      });
    }
    return {};
  }

  /// Laskee kaikkien menojen summan pääkategorioista ja niiden alakategorioista.
  double get totalExpenses {
    return expenses.values.fold(0.0, (sum, subcategories) {
      return sum + subcategories.values.fold(0.0, (subSum, value) => subSum + value);
    });
  }

  /// Laskee jäljellä olevan budjetin tulojen ja menojen erotuksena.
  double get remaining => income - totalExpenses;

  /// Luo syvän kopion BudgetModel-oliosta, säilyttäen alkuperäisen rakenteen.
  BudgetModel copy() {
    return BudgetModel(
      income: income,
      expenses: expenses.map((category, subcategories) => MapEntry(
        category,
        Map<String, double>.from(subcategories),
      )),
      createdAt: createdAt,
      year: year,
      month: month,
      isPlaceholder: isPlaceholder,
    );
  }

  @override
  String toString() {
    return 'BudgetModel(income: $income, expenses: $expenses, createdAt: $createdAt, year: $year, month: $month, isPlaceholder: $isPlaceholder)';
  }
}