import 'package:flutter/material.dart';

// Muokataan funktiota tukemaan Map<String, Map<String, double>> -rakennetta
Map<String, double> combineSmallCategories(Map<String, Map<String, double>> expenses, double totalBudget) {
  const double thresholdPercentage = 5.0;
  final Map<String, double> combined = {};
  double otherTotal = 0.0;

  // Lasketaan pääkategorioiden summat
  expenses.forEach((category, subcategories) {
    final categoryTotal = subcategories.values.fold(0.0, (sum, value) => sum + value);
    final percentage = totalBudget > 0 ? (categoryTotal / totalBudget) * 100 : 0.0;

    if (percentage < thresholdPercentage) {
      otherTotal += categoryTotal;
    } else {
      combined[category] = categoryTotal;
    }
  });

  if (otherTotal > 0) {
    combined['Muut'] = otherTotal;
  }

  return combined;
}

// Muokataan funktiota tukemaan Map<String, Map<String, double>> -rakennetta
Map<String, double> getOtherCategoryDetails(Map<String, Map<String, double>> expenses, double totalBudget) {
  const double thresholdPercentage = 5.0;
  final Map<String, double> otherCategories = {};

  expenses.forEach((category, subcategories) {
    final categoryTotal = subcategories.values.fold(0.0, (sum, value) => sum + value);
    final percentage = totalBudget > 0 ? (categoryTotal / totalBudget) * 100 : 0.0;

    if (percentage < thresholdPercentage) {
      otherCategories[category] = categoryTotal;
    }
  });

  return otherCategories;
}

Color getColorForCategory(String category, List<String> categories) {
  final List<Color> colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
  ];

  final index = categories.indexOf(category);
  return colors[index % colors.length];
}