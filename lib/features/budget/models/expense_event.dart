enum EventType { income, expense }

class ExpenseEvent {
  final String id;
  final String category;
  final String? subcategory; // Lisätään subcategory-kenttä
  final double amount;
  final DateTime createdAt;
  final EventType type;
  final int year;
  final int month;
  final String? description;

  ExpenseEvent({
    required this.id,
    required this.category,
    this.subcategory, // Alakategoria on valinnainen
    required this.amount,
    required this.createdAt,
    required this.type,
    required this.year,
    required this.month,
    this.description,
  });

  factory ExpenseEvent.fromMap(Map<String, dynamic> map) {
    return ExpenseEvent(
      id: map['id'] as String,
      category: map['category'] as String,
      subcategory: map['subcategory'] as String?, // Haetaan subcategory
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      type: map['type'] == 'income' ? EventType.income : EventType.expense,
      year: map['year'] as int,
      month: map['month'] as int,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'subcategory': subcategory, // Tallennetaan subcategory
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'type': type == EventType.income ? 'income' : 'expense',
      'year': year,
      'month': month,
      'description': description,
    };
  }
}