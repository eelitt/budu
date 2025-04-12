enum EventType { income, expense }

class ExpenseEvent {
  final String id;
  final String category;
  final double amount;
  final DateTime createdAt;
  final EventType type; // Uusi kenttä: tulo vai meno
  final int year; // Uusi kenttä: vuosi
  final int month; // Uusi kenttä: kuukausi

  ExpenseEvent({
    required this.id,
    required this.category,
    required this.amount,
    required this.createdAt,
    required this.type,
    required this.year,
    required this.month,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString().split('.').last, // Tallennetaan enum merkkijonona
      'year': year,
      'month': month,
    };
  }

  factory ExpenseEvent.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseEvent(
      id: id,
      category: map['category'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt']),
      type: map['type'] == 'income' ? EventType.income : EventType.expense,
      year: map['year'] ?? DateTime.now().year,
      month: map['month'] ?? DateTime.now().month,
    );
  }
  factory ExpenseEvent.create({
    required String category,
    required double amount,
    required EventType type,
    required int year,
    required int month,
  }) {
    return ExpenseEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Väliaikainen ID
      category: category,
      amount: amount,
      createdAt: DateTime.now(),
      type: type,
      year: year,
      month: month,
    );
  }
}

