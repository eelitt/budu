import 'package:flutter/material.dart';

void showErrorSnackBar(BuildContext context, String message) {
  if (context.mounted) {
    print('$message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

String formatCurrency(double amount) {
  return '${amount.toStringAsFixed(2)} €'; // Yksinkertainen valuuttamuotoilu
}