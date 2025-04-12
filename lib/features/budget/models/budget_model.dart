class BudgetModel {
  final double income;
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
      income: map['income']?.toDouble() ?? 0.0,
      expenses: Map<String, double>.from(map['expenses'] ?? {}),
      createdAt: DateTime.parse(map['createdAt']),
      year: map['year'] ?? DateTime.now().year,
      month: map['month'] ?? DateTime.now().month,
    );
  }

  double get totalExpenses => expenses.values.fold(0.0, (sum, value) => sum + value);
  double get remaining => income - totalExpenses;
}