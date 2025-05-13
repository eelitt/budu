// lib/features/budget/screens/budget/widgets/edit_subcategory_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditSubcategoryForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const EditSubcategoryForm({
    super.key,
    required this.nameController,
    required this.amountController,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: nameController,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            maxLength: 30,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green, size: 20),
          onPressed: onSave,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red, size: 20),
          onPressed: onCancel,
        ),
      ],
    );
  }
}