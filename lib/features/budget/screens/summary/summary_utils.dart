import 'package:flutter/material.dart';

Map<String, double> combineSmallCategories(Map<String, double> expenses, double totalBudget) {
  const double threshold = 5.0;
  Map<String, double> combinedExpenses = {};
  double otherTotal = 0.0;

  expenses.forEach((category, amount) {
    final percentage = (amount / totalBudget) * 100;
    if (percentage < threshold) {
      otherTotal += amount;
    } else {
      combinedExpenses[category] = amount;
    }
  });

  if (otherTotal > 0) {
    combinedExpenses['Muut'] = otherTotal;
  }

  return combinedExpenses;
}

List<MapEntry<String, double>> getOtherCategoryDetails(Map<String, double> expenses, double totalBudget) {
  const double threshold = 5.0;
  List<MapEntry<String, double>> otherCategories = [];

  expenses.forEach((category, amount) {
    final percentage = (amount / totalBudget) * 100;
    if (percentage < threshold) {
      otherCategories.add(MapEntry(category, amount));
    }
  });

  return otherCategories;
}

Color getColorForCategory(String category, List<String> categories) {
  final colors = [
    const Color(0xFF4CAF50),
    const Color(0xFF2196F3),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
    const Color(0xFFFF5722),
    const Color(0xFF795548),
    const Color(0xFFCDDC39),
    const Color(0xFF673AB7),
    const Color(0xFF009688),
    const Color(0xFFFFC107),
  ];
  final index = categories.indexOf(category);
  return colors[index % colors.length];
}