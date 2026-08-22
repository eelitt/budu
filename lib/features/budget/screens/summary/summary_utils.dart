import 'package:flutter/material.dart';

export 'package:budu/features/budget/domain/tracking.dart'
    show combineSmallCategories, getOtherCategoryDetails;

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