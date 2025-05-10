import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/constants.dart';
import 'package:budu/core/utils.dart';
import 'package:flutter/material.dart';

Future<String?> showAddCategoryDialog({
  required BuildContext context,
  required Map<String, Map<String, double>> currentExpenses,
}) async {
  final availableCategories = categoryMapping.keys
      .where((category) => !currentExpenses.containsKey(category))
      .toList();

  if (availableCategories.isEmpty) {
    showSnackBar(
      context,
      'Ilmaisversiossa on 11 kategoriaa - Investoi tulevaisuuteesi täällä!',
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'investoi nyt',
        onPressed: () {
         // Navigator.pushNamed(context, AppRouter.upgradeRoute);
        },
      ),
    );
    return null;
  }

  String? selectedCategory;

  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
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
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.75),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                        itemBuilder: (BuildContext context) {
                          return availableCategories.map((category) {
                            return PopupMenuItem<String>(
                              value: category,
                              child: Text(
                                category,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.black87,
                                    ),
                              ),
                            );
                          }).toList();
                        },
                        color: Colors.white,
                        position: PopupMenuPosition.under,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedCategory ?? 'Valitse kategoria',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.black87,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
          ElevatedButton(
            onPressed: () {
              if (selectedCategory != null) {
                Navigator.pop(context, selectedCategory);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
              foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Lisää',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                  ),
            ),
          ),
        ],
      );
    },
  );

  // Näytetään Snackbar, jos kategoria lisättiin
  if (result != null) {
    showSnackBar(
      context,
      'Kategoria "$result" lisätty!',
      duration: const Duration(seconds: 2),
    );
  }

  return result;
} 