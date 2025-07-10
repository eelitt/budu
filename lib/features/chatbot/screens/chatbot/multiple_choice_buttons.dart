import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../providers/chatbot_provider.dart';

class MultipleChoiceButtons extends StatelessWidget {
  final ChatbotProvider chatbotProvider;
  final Function(String) onOptionSelected; // Callback valitulle vaihtoehdolle

  const MultipleChoiceButtons({
    super.key,
    required this.chatbotProvider,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: chatbotProvider.currentOptions.map((option) {
          return ElevatedButton(
            onPressed: () {
              print('MultipleChoiceButtons: Valittiin monivalinta: $option');
              FirebaseCrashlytics.instance.log('MultipleChoiceButtons: Valittiin monivalinta: $option');
              onOptionSelected(option);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }
}