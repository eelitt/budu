import 'package:flutter/material.dart';

class SaveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SaveButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).elevatedButtonTheme.style?.backgroundColor?.resolve({}),
          foregroundColor: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: Text(
          'Tallenna budjetti',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
              ),
        ),
      ),
    );
  }
}