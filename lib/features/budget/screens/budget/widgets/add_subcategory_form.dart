// lib/features/budget/screens/budget/widgets/add_subcategory_form.dart
import 'package:flutter/material.dart';

class AddSubcategoryForm extends StatelessWidget {
  final TextEditingController controller;
  final String? errorMessage;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const AddSubcategoryForm({
    super.key,
    required this.controller,
    required this.errorMessage,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Uusi alakategoria',
              border: const OutlineInputBorder(),
              errorText: errorMessage,
            ),
            maxLength: 30,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: onAdd,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: onCancel,
        ),
      ],
    );
  }
}