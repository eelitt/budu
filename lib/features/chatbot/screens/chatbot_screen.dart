import 'package:budu/core/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';

import '../providers/chatbot_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  bool _hasNavigated = false;
  ChatbotProvider? _chatbotProvider; // Tallennetaan viite provideriin

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tallennetaan viite ChatbotProvideriin
    _chatbotProvider = Provider.of<ChatbotProvider>(context, listen: false);
    // Lisätään kuuntelija vain, jos sitä ei ole jo lisätty
    if (!_hasNavigated) {
      _chatbotProvider!.addListener(_onChatbotCompleted);
    }
  }

  void _onChatbotCompleted() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_chatbotProvider!.isCompleted && !_hasNavigated) {
      _hasNavigated = true;
      print('ChatbotScreen: Chatbot valmis, tallennetaan budjetti');
      _chatbotProvider!.saveBudget(context, authProvider.user!.uid).then((_) {
        print('ChatbotScreen: Budjetti tallennettu, navigoidaan MainScreeniin (SummaryScreen)');
        // Viivästytetään navigointia, jotta MainScreen ehtii latautua
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacementNamed(
            context,
            AppRouter.mainRoute,
            arguments: {'index': 1}, // 1 = SummaryScreen
          );
        });
      }).catchError((e) {
        print('ChatbotScreen: Virhe budjetin tallennuksessa: $e');
        _hasNavigated = false; // Sallitaan uusi yritys, jos tallennus epäonnistuu
      });
    }
  }

  @override
  void dispose() {
    // Poistetaan kuuntelija turvallisesti
    _chatbotProvider?.removeListener(_onChatbotCompleted);
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
                    ? Padding(
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
                      )
                    : Material(
                        color: Colors.grey[200],
                        child: TextFieldWithNumberKeyboard(
                          key: ValueKey(chatbotProvider.step),
                        ),
                      ),
              ),
            ),
            if (!chatbotProvider.isCompleted)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  onPressed: () {
                    print('ChatbotScreen: Ohitetaan chatbot');
                    Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
                  },
                  child: const Text('Ohita ja luo budjetti manuaalisesti'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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