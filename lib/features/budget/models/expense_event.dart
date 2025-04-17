enum EventType { income, expense }

class ExpenseEvent {
  final String id;
  final String category;
  final double amount;
  final DateTime createdAt;
  final EventType type;
  final int year;
  final int month;
  final String? description;

  ExpenseEvent({
    required this.id,
    required this.category,
    required this.amount,
    required this.createdAt,
    required this.type,
    required this.year,
    required this.month,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString(),
      'year': year,
      'month': month,
      'description': description,
    };
  }

  factory ExpenseEvent.fromMap(Map<String, dynamic> map) {
    return ExpenseEvent(
      id: map['id'],
      category: map['category'],
      amount: map['amount'],
      createdAt: DateTime.parse(map['createdAt']),
      type: map['type'] == EventType.income.toString() ? EventType.income : EventType.expense,
      year: map['year'],
      month: map['month'],
      description: map['description'],
    );
  }
}