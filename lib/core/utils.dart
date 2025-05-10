import 'package:flutter/material.dart';

void showSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
  Color? backgroundColor,
}) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
        ),
        duration: duration,
        action: action != null
            ? SnackBarAction(
                label: action.label,
                textColor: Colors.white,
                onPressed: action.onPressed,
              )
            : null,
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

void showErrorSnackBar(BuildContext context, String message) {
  if (context.mounted) {
    print('$message');
    showSnackBar(
      context,
      message,
      backgroundColor: Colors.redAccent,
    );
  }
}

String formatCurrency(double amount) {
  return '${amount.toStringAsFixed(2)} €';
}