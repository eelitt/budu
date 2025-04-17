class BudgetModel {
  double income;
  final Map<String, double> expenses;
  final DateTime createdAt;
  final int year;
  final int month;

  BudgetModel({
    required this.income,
    required this.expenses,
    required this.createdAt,
    required this.year,
    required this.month,
  });

  Map<String, dynamic> toMap() {
    return {
      'income': income,
      'expenses': expenses,
      'createdAt': createdAt.toIso8601String(),
      'year': year,
      'month': month,
    };
  }

 factory BudgetModel.fromMap(Map<String, dynamic> map) {
  return BudgetModel(
    income: double.tryParse(map['income']?.toString() ?? '0.0') ?? 0.0,
    expenses: (map['expenses'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, double.tryParse(value?.toString() ?? '0.0') ?? 0.0),
        ) ?? {},
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    year: map['year'] as int? ?? DateTime.now().year,
    month: map['month'] as int? ?? DateTime.now().month,
  );
}

  double get totalExpenses => expenses.values.fold(0.0, (sum, value) => sum + value);
  double get remaining => income - totalExpenses;
}