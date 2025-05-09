import 'package:budu/core/app_router/app_router.dart';
import 'package:flutter/material.dart';

class SkipButton extends StatelessWidget {
  final bool isCompleted;

  const SkipButton({
    super.key,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextButton(
        onPressed: () {
          print('ChatbotScreen: Ohitetaan chatbot');
          Navigator.pushReplacementNamed(context, AppRouter.createBudgetRoute);
        },
        child: const Text('Ohita ja luo budjetti manuaalisesti'),
      ),
    );
  }
}