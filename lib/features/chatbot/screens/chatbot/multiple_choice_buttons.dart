import 'package:flutter/material.dart';
import '../../providers/chatbot_provider.dart';

class MultipleChoiceButtons extends StatelessWidget {
  final ChatbotProvider chatbotProvider;

  const MultipleChoiceButtons({
    super.key,
    required this.chatbotProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        children: chatbotProvider.currentOptions.map((option) {
          return ElevatedButton(
            onPressed: () {
              print('ChatbotScreen: Valittiin monivalinta: $option');
              chatbotProvider.handleUserResponse(option);
            },
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }
}