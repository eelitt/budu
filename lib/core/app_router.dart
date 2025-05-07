import 'package:budu/features/budget/screens/summary/summary_screen.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:budu/features/chatbot/screens/chatbot/chatbot_screen.dart';
import 'package:budu/features/mainscreen/mainScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/screens/login_screen/login_screen.dart';
import '../features/budget/screens/budget/budget_screen.dart';

class AppRouter {
  static const String loginRoute = '/login';
  static const String mainRoute = '/main';
  static const String budgetRoute = '/budget';
  static const String summaryRoute = '/summary';
  static const String chatbotRoute = '/chatbot';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginRoute:
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case mainRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        final initialIndex = args?['index'] as int? ?? 0;
        return MaterialPageRoute(
          builder: (_) => MainScreen(initialIndex: initialIndex),
        );
      case budgetRoute:
        return MaterialPageRoute(builder: (_) => const BudgetScreen());
      case summaryRoute:
        return MaterialPageRoute(builder: (_) => const SummaryScreen());
      case chatbotRoute:
        return MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => ChatbotProvider(),
            child: const ChatbotScreen(),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Sivua ei löydy')),
          ),
        );
    }
  }

  static Map<String, WidgetBuilder> get routes => {
        loginRoute: (context) => const LoginScreen(),
        mainRoute: (context) => const MainScreen(),
        budgetRoute: (context) => const BudgetScreen(),
        summaryRoute: (context) => const SummaryScreen(),
        chatbotRoute: (context) => ChangeNotifierProvider(
              create: (_) => ChatbotProvider(),
              child: const ChatbotScreen(),
            ),
      };
}