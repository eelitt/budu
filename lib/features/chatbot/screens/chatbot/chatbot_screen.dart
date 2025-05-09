import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:budu/features/chatbot/screens/chatbot/multiple_choice_buttons.dart';
import 'package:budu/features/chatbot/screens/chatbot/skip_button.dart';
import 'package:budu/features/chatbot/screens/chatbot/text_field_with_number_keyboard.dart';
import 'package:budu/features/chatbot/screens/chatbot/chatbot_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late ChatbotNavigator _navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = ChatbotNavigator(context);
  }

  @override
  void dispose() {
    _navigator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatbotProvider = Provider.of<ChatbotProvider>(context);

    return Scaffold(
        appBar: AppBar(title: const Text('Budu - Chatbot')),
        body: Material(
          child: Column(
            children: [
              Expanded(
                child: chat_ui.Chat(
                  messages: chatbotProvider.messages.reversed.map((msg) {
                    return types.TextMessage(
                      author: types.User(id: msg.isUser ? 'user' : 'bot'),
                      id: UniqueKey().toString(),
                      text: msg.text,
                      createdAt: msg.createdAt.millisecondsSinceEpoch,
                    );
                  }).toList(),
                  onSendPressed: (types.PartialText partialText) {
                    print('ChatbotScreen: Käyttäjä vastasi: ${partialText.text}');
                    chatbotProvider.handleUserResponse(partialText.text);
                  },
                  user: const types.User(id: 'user'),
                  theme: const chat_ui.DefaultChatTheme(
                    inputBackgroundColor: Colors.grey,
                    primaryColor: Colors.blueGrey,
                  ),
                  customBottomWidget: chatbotProvider.isMultipleChoice
                      ? MultipleChoiceButtons(chatbotProvider: chatbotProvider)
                      : Material(
                          color: Colors.grey[200],
                          child: TextFieldWithNumberKeyboard(
                            key: ValueKey(chatbotProvider.step),
                          ),
                        ),
                ),
              ),
              SkipButton(isCompleted: chatbotProvider.isCompleted),
            ],
          ),
        ),
      );
  }
}