import 'package:budu/core/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatbotNavigator {
  bool _hasNavigated = false;
  ChatbotProvider? _chatbotProvider;
  BuildContext _context;

  ChatbotNavigator(this._context) {
    _chatbotProvider = Provider.of<ChatbotProvider>(_context, listen: false);
    _chatbotProvider!.addListener(_onChatbotCompleted);
  }

  void _onChatbotCompleted() {
    final authProvider = Provider.of<AuthProvider>(_context, listen: false);

    if (_chatbotProvider!.isCompleted && !_hasNavigated) {
      _hasNavigated = true;
      print('ChatbotScreen: Chatbot valmis, tallennetaan budjetti');
      _chatbotProvider!.saveBudget(_context, authProvider.user!.uid).then((_) {
        print('ChatbotScreen: Budjetti tallennettu, navigoidaan MainScreeniin (SummaryScreen)');
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacementNamed(
            _context,
            AppRouter.mainRoute,
            arguments: {'index': 1},
          );
        });
      }).catchError((e) {
        print('ChatbotScreen: Virhe budjetin tallennuksessa: $e');
        _hasNavigated = false;
      });
    }
  }

  void dispose() {
    _chatbotProvider?.removeListener(_onChatbotCompleted);
  }
}