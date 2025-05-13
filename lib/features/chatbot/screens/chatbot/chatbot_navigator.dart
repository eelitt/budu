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
  }

  Future<void> saveBudget() async {
    if (_chatbotProvider!.isCompleted && !_hasNavigated) {
      _hasNavigated = true;
      final authProvider = Provider.of<AuthProvider>(_context, listen: false);
      print('ChatbotScreen: Chatbot valmis, tallennetaan budjetti');
      await _chatbotProvider!.saveBudget(_context, authProvider.user!.uid).catchError((e) {
        print('ChatbotScreen: Virhe budjetin tallennuksessa: $e');
        _hasNavigated = false;
        throw e; // Heitetään virhe eteenpäin, jotta ChatbotScreen voi käsitellä sen
      });
    }
  }

  void dispose() {
    // Ei enää kuuntelijaa, joten ei tarvetta poistaa
  }
}