import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Edustaa budjettia tietylle aikavälille, sisältäen tulot, menot ja muut tiedot.
/// Tukee sekä henkilökohtaisia että yhteistalousbudjetteja optional-kentillä (users, createdBy, name).
/// Tämä yhdistää aiemmat BudgetModel ja SharedBudget modulaarisuuden parantamiseksi ilman duplikaatiota.
class BudgetModel {
  /// Budjetin kokonaistulot.
  double income;
  /// Map-rakenne, joka sisältää pääkategoriat ja niiden alakategoriat menoille.
  Map<String, Map<String, double>> expenses;
  /// Budjetin luontiaika.
  final DateTime createdAt;
  /// Budjetin alkamispäivä.
  final DateTime startDate;
  /// Budjetin päättymispäivä.
  final DateTime endDate;
  /// Budjetin tyyppi (esim. monthly, biweekly, custom).
  final String type;
  /// Merkintä siitä, onko budjetti paikkamerkki (esim. tuleville budjeteille).
  final bool isPlaceholder;
  /// Budjetin yksilöllinen tunniste (valinnainen, käytetään Firestore-dokumentin ID:nä).
  final String? id;
  /// Yhteistalousbudjetin tunniste (valinnainen, linkittää shared_budgets-kokoelmaan).
  final String? sharedBudgetId;
  /// Käyttäjien UID-lista (optional, käytössä yhteistalousbudjeteissa).
  final List<String>? users;
  /// Budjetin luojan UID (optional, käytössä yhteistalousbudjeteissa).
  final String? createdBy;
  /// Budjetin nimi (optional, käytössä yhteistalousbudjeteissa).
  final String? name;

  BudgetModel({
    required this.income,
    required this.expenses,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.isPlaceholder = false,
    this.id,
    this.sharedBudgetId,
    this.users,
    this.createdBy,
    this.name,
  });

  /// Muuntaa budjetin Map-olioksi tallennusta tai serialisointia varten.
  /// Sisältää optional-kentät vain jos ne ovat asetettu, optimoimaan Firestore-kirjoituksia.
  Map<String, dynamic> toMap() {
    final map = {
      'income': income,
      'expenses': expenses,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'type': type,
      'isPlaceholder': isPlaceholder,
      'sharedBudgetId': sharedBudgetId,
    };
    if (users != null) map['users'] = users;
    if (createdBy != null) map['createdBy'] = createdBy;
    if (name != null) map['name'] = name;
    return map;
  }

  /// Luo BudgetModel-instanssin Map-oliosta, esimerkiksi haettaessa dataa tallennuksesta.
  /// Käsittelee optional-kentät null-checkeillä, säilyttäen yhteensopivuuden vanhaan dataan.
  factory BudgetModel.fromMap(Map<String, dynamic> map, String? id) {
    try {
      DateTime startDate;
      DateTime endDate;
      String type = map['type'] is String ? map['type'] : 'custom';

      if (map.containsKey('year') && map.containsKey('month')) {
        final year = map['year'] as int? ?? DateTime.now().year;
        final month = map['month'] as int? ?? DateTime.now().month;
        startDate = DateTime(year, month, 1);
        endDate = DateTime(year, month + 1, 0);
        type = 'monthly';
      } else {
        startDate = parseDate(map['startDate']) ?? DateTime.now();
        endDate = parseDate(map['endDate']) ?? DateTime.now();
      }

      return BudgetModel(
        income: (map['income'] as num?)?.toDouble() ?? 0.0,
        expenses: _parseExpenses(map['expenses']),
        createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
        startDate: startDate,
        endDate: endDate,
        type: type,
        isPlaceholder: map['isPlaceholder'] as bool? ?? false,
        id: id,
        sharedBudgetId: map['sharedBudgetId'] as String?,
        users: map['users'] != null ? List<String>.from(map['users']) : null,
        createdBy: map['createdBy'] as String?,
        name: map['name'] as String?,
      );
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Virhe budjettidatan parsimisessa',
      );
      throw FormatException('Virheellinen budjettidata: $e');
    }
  }

  /// Apumetodi päivämäärän parsimiseen, tukee Timestamp ja String (ISO 8601) -formaatteja.
  static DateTime? parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Apumetodi menojen parsimiseen tallennetusta datasta.
  /// Optimoitu käsittelemään null-arvoja ilman crasheja.
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
  /// Sisältää optional-kentät kopiossa.
  BudgetModel copy() {
    return BudgetModel(
      income: income,
      expenses: expenses.map((category, subcategories) => MapEntry(
        category,
        Map<String, double>.from(subcategories),
      )),
      createdAt: createdAt,
      startDate: startDate,
      endDate: endDate,
      type: type,
      isPlaceholder: isPlaceholder,
      id: id,
      sharedBudgetId: sharedBudgetId,
      users: users != null ? List<String>.from(users!) : null,
      createdBy: createdBy,
      name: name,
    );
  }

  /// Apu-getter: Palauttaa true, jos kyseessä on yhteistalousbudjetti (perustuu users-kenttään).
  bool get isShared => users != null && users!.length > 1;

  @override
  String toString() {
    return 'BudgetModel(income: $income, expenses: $expenses, createdAt: $createdAt, startDate: $startDate, endDate: $endDate, type: $type, isPlaceholder: $isPlaceholder, id: $id, sharedBudgetId: $sharedBudgetId, users: $users, createdBy: $createdBy, name: $name)';
  }
}