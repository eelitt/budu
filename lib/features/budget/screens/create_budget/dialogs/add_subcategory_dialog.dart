import 'package:budu/core/constants.dart';
import 'package:flutter/material.dart';

/// Returns the chosen subcategory name, or null if cancelled / at max.
Future<String?> showAddSubcategoryDialog({
  required BuildContext context,
  required String category,
  required Set<String> existingSubcategories,
}) {
  if (existingSubcategories.length >= Constants.maxSubcategories) {
    return Future.value(null);
  }

  final availableSubcategories =
      Constants.categoryMapping.containsKey(category)
          ? Constants.categoryMapping[category]!
              .where((sub) => !existingSubcategories.contains(sub))
              .toList()
          : <String>[];

  return showDialog<String>(
    context: context,
    builder: (context) => _AddSubcategoryDialog(
      category: category,
      availableSubcategories: availableSubcategories,
      existingSubcategories: existingSubcategories,
    ),
  );
}

String? _validateSubcategoryName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Syötä alakategorian nimi';
  }
  if (value.length > Constants.maxCategoryNameLength) {
    return 'Nimi voi olla enintään ${Constants.maxCategoryNameLength} merkkiä';
  }
  return null;
}

class _AddSubcategoryDialog extends StatefulWidget {
  final String category;
  final List<String> availableSubcategories;
  final Set<String> existingSubcategories;

  const _AddSubcategoryDialog({
    required this.category,
    required this.availableSubcategories,
    required this.existingSubcategories,
  });

  @override
  State<_AddSubcategoryDialog> createState() => _AddSubcategoryDialogState();
}

class _AddSubcategoryDialogState extends State<_AddSubcategoryDialog> {
  final _customController = TextEditingController();
  String? _selectedSubcategory;
  String? _errorText;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submit() {
    final subcategory =
        _selectedSubcategory ?? _customController.text.trim();
    final validationError = _validateSubcategoryName(subcategory);
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    if (widget.existingSubcategories.contains(subcategory)) {
      setState(() => _errorText = 'Alakategoria on jo olemassa');
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.pop(context, subcategory);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lisää alakategoria',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kategoria: ${widget.category}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
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
                  value: _selectedSubcategory,
                  hint: const Text('Valitse alakategoria'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Muu (syötä oma)'),
                    ),
                    ...widget.availableSubcategories.map((subcategory) {
                      return DropdownMenuItem<String>(
                        value: subcategory,
                        child: Text(subcategory),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSubcategory = value;
                      _errorText = null;
                    });
                  },
                  menuMaxHeight: 300,
                ),
              ),
            ),
            if (_selectedSubcategory == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customController,
                decoration: InputDecoration(
                  labelText: 'Oma alakategoria',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                  errorMaxLines: 2,
                ),
                maxLength: Constants.maxCategoryNameLength,
                onChanged: (value) {
                  final error = _validateSubcategoryName(value);
                  if (error != null) {
                    setState(() => _errorText = error);
                  } else if (widget.existingSubcategories
                      .contains(value.trim())) {
                    setState(
                      () => _errorText = 'Alakategoria on jo olemassa',
                    );
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
