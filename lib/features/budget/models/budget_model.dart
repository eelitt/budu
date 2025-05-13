class BudgetModel {
  double income;
   Map<String, Map<String, double>> expenses; // Pääkategoriat ja niiden alakategoriat
  final DateTime createdAt;
  final int year;
  final int month;
  final bool isPlaceholder;

  BudgetModel({
    required this.income,
    required this.expenses,
    required this.createdAt,
    required this.year,
    required this.month,
    this.isPlaceholder = false, 
  });

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

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      income: (map['income'] as num).toDouble(),
      expenses: (map['expenses'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (subKey, subValue) => MapEntry(subKey, (subValue as num).toDouble()),
          ),
        ),
      ),
      createdAt: DateTime.parse(map['createdAt']),
      year: map['year'] as int,
      month: map['month'] as int,
      isPlaceholder: map['isPlaceholder'] as bool? ?? false,
    );
  }

  // Lasketaan kaikkien alakategorioiden summat pääkategorioista
  double get totalExpenses {
    return expenses.values.fold(0.0, (sum, subcategories) {
      return sum + subcategories.values.fold(0.0, (subSum, value) => subSum + value);
    });
  }

  double get remaining => income - totalExpenses;
  // Luodaan syvä kopio BudgetModel-oliosta
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

