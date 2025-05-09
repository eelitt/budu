import 'package:budu/core/constants.dart';
import 'package:flutter/material.dart';

class CategoryManager {
  final Map<String, Map<String, TextEditingController>> expenseControllers;
  final VoidCallback onUpdate;

  CategoryManager({
    required this.expenseControllers,
    required this.onUpdate,
  });

  bool get canAddCategory {
    return categoryMapping.keys.any((category) => !expenseControllers.containsKey(category));
  }

  void removeCategory(String category) {
    expenseControllers.remove(category);
    onUpdate();
  }

  void addCategory(BuildContext context) {
    final availableCategories = categoryMapping.keys
        .where((category) => !expenseControllers.containsKey(category))
        .toList();

    if (availableCategories.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        title: Text(
          'Lisää kategoria',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableCategories.map((category) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      expenseControllers[category] = {};
                      Navigator.pop(context);
                      onUpdate();
                    },
                    splashColor: Colors.grey[300],
                    highlightColor: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Peruuta',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}