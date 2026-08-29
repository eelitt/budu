import 'package:budu/core/constants.dart';
import 'package:flutter/material.dart';

/// Returns the chosen main-category name, or null if cancelled / at max.
Future<String?> showAddCategoryDialog({
  required BuildContext context,
  required Set<String> existingCategories,
}) {
  if (existingCategories.length >= Constants.maxCategories) {
    return Future.value(null);
  }

  final availableCategories = Constants.categoryMapping.keys
      .where((category) => !existingCategories.contains(category))
      .toList();

  return showDialog<String>(
    context: context,
    builder: (context) => _AddCategoryDialog(
      availableCategories: availableCategories,
      existingCategories: existingCategories,
    ),
  );
}

class _AddCategoryDialog extends StatefulWidget {
  final List<String> availableCategories;
  final Set<String> existingCategories;

  const _AddCategoryDialog({
    required this.availableCategories,
    required this.existingCategories,
  });

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _customController = TextEditingController();
  String? _selectedCategory;
  String? _errorText;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submit() {
    final newCategory = _selectedCategory ?? _customController.text.trim();
    if (newCategory.isEmpty) {
      setState(() => _errorText = 'Syötä kategorian nimi');
      return;
    }
    if (widget.existingCategories.contains(newCategory)) {
      setState(() => _errorText = 'Kategoria on jo olemassa');
      return;
    }
    Navigator.pop(context, newCategory);
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.white,
                dropdownMenuTheme: DropdownMenuThemeData(
                  menuStyle: MenuStyle(
                    backgroundColor:
                        const WidgetStatePropertyAll(Colors.white),
                    surfaceTintColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  hint: const Text('Valitse kategoria'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Oma kategoria'),
                    ),
                    ...widget.availableCategories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _errorText = null;
                    });
                  },
                  menuMaxHeight: 300,
                ),
              ),
            ),
            if (_selectedCategory == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customController,
                decoration: InputDecoration(
                  labelText: 'Oma kategoria',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                  errorMaxLines: 2,
                ),
                maxLength: Constants.maxCategoryNameLength,
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() => _errorText = 'Syötä kategorian nimi');
                  } else if (value.length > Constants.maxCategoryNameLength) {
                    setState(
                      () => _errorText =
                          'Nimi voi olla enintään ${Constants.maxCategoryNameLength} merkkiä',
                    );
                  } else if (widget.existingCategories
                      .contains(value.trim())) {
                    setState(() => _errorText = 'Kategoria on jo olemassa');
                  } else {
                    setState(() => _errorText = null);
                  }
                },
              ),
            ],
          ],
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
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context)
                .elevatedButtonTheme
                .style
                ?.backgroundColor
                ?.resolve({}),
            foregroundColor: Theme.of(context)
                .elevatedButtonTheme
                .style
                ?.foregroundColor
                ?.resolve({}),
          ),
          child: Text(
            'Lisää',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .elevatedButtonTheme
                      .style
                      ?.foregroundColor
                      ?.resolve({}),
                ),
          ),
        ),
      ],
    );
  }
}
