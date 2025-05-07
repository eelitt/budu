import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chatbot_provider.dart';

class TextFieldWithNumberKeyboard extends StatefulWidget {
  const TextFieldWithNumberKeyboard({super.key});

  @override
  State<TextFieldWithNumberKeyboard> createState() => _TextFieldWithNumberKeyboardState();
}

class _TextFieldWithNumberKeyboardState extends State<TextFieldWithNumberKeyboard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatbotProvider = Provider.of<ChatbotProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Syötä summa...',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey,
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            chatbotProvider.handleUserResponse(value);
            _controller.clear();
          }
        },
      ),
    );
  }
}