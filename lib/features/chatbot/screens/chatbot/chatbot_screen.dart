import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:budu/features/chatbot/screens/chatbot/chatbot_navigator.dart';
import 'package:budu/features/chatbot/screens/chatbot/chatbot_question_view.dart';
import 'package:budu/features/chatbot/screens/chatbot/welcome_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  late ChatbotNavigator _navigator;
  bool _hasNavigated = false;
  bool _showWelcome = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Animaatioiden alustus (vain slide-animaatio tarvitaan WelcomeView:lle)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Käynnistetään animaatiot
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = ChatbotNavigator(context);
  }

  @override
  void dispose() {
    _navigator.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleNavigation(ChatbotProvider chatbotProvider) {
    if (chatbotProvider.isCompleted && !_hasNavigated) {
      _hasNavigated = true;
      print('ChatbotScreen: Chatbot on valmis, tallennetaan budjetti ja navigoidaan');
      _navigator.saveBudget().then((_) {
        print('ChatbotScreen: Budjetti tallennettu, navigoidaan MainScreeniin (SummaryScreen, index: 1)');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              AppRouter.mainRoute,
              arguments: {'index': 1},
            );
          } else {
            print('ChatbotScreen: Widget ei ole enää mounted, ei navigoida');
          }
        });
      }).catchError((e) {
        print('ChatbotScreen: Virhe budjetin tallennuksessa: $e');
        _hasNavigated = false;
      });
    }
  }

  void _proceedToQuestions() {
    setState(() {
      _showWelcome = false;
    });
  }

  void _skipToManualBudget() {
    print('ChatbotScreen: Ohitetaan chatbot, navigoidaan budjetin luontisivulle');
    Navigator.pushReplacementNamed(context, AppRouter.createBudgetRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatbotProvider>(
      builder: (context, chatbotProvider, child) {
        // Käsitellään navigointi, kun chatbot on valmis
        if (!_showWelcome) {
          _handleNavigation(chatbotProvider);
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Budu - Budjetin muodostus'),
          ),
          body: _showWelcome
              ? WelcomeView(
                  onProceed: _proceedToQuestions,
                  onSkip: _skipToManualBudget,
                  slideAnimation: _slideAnimation,
                )
              : ChatbotQuestionView(chatbotProvider: chatbotProvider),
        );
      },
    );
  }
}