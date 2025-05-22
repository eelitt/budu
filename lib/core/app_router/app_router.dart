import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/screens/create_budget/create_budget_screen.dart';
import 'package:budu/features/budget/screens/summary/summary_screen.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:budu/features/chatbot/screens/chatbot/chatbot_screen.dart';
import 'package:budu/features/history/history_screen.dart';
import 'package:budu/features/mainscreen/mainScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/screens/login_screen/login_screen.dart';
import '../../features/budget/screens/budget/budget_screen.dart';

// AppRouter.dart
class AppRouter {
  static const String loginRoute = '/login';
  static const String mainRoute = '/main';
  static const String budgetRoute = '/budget';
  static const String summaryRoute = '/summary';
  static const String historyRoute = '/history';
  static const String chatbotRoute = '/chatbot';
  static const String createBudgetRoute = '/create-budget';

  // Mukautettu siirtymäanimaatio FadeTransition
  static PageRouteBuilder _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 800), // Animaation kesto
      reverseTransitionDuration: const Duration(milliseconds: 600), // Paluuanimaation kesto
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginRoute:
        print('AppRouter: Generoidaan reitti: $loginRoute');
        return _createFadeRoute(LoginScreen());
      case mainRoute:
        print('AppRouter: Generoidaan reitti: $mainRoute');
        final args = settings.arguments as Map<String, dynamic>?;
        final initialIndex = args?['index'] as int? ?? 0;
        return _createFadeRoute(MainScreen(initialIndex: initialIndex));
      case budgetRoute:
        print('AppRouter: Generoidaan reitti: $budgetRoute');
        return _createFadeRoute(const BudgetScreen());
      case summaryRoute:
        print('AppRouter: Generoidaan reitti: $summaryRoute');
        return _createFadeRoute(const SummaryScreen());
      case historyRoute:
        print('AppRouter: Generoidaan reitti: $historyRoute');
        return _createFadeRoute(const HistoryScreen());
      case chatbotRoute:
        print('AppRouter: Generoidaan reitti: $chatbotRoute');
        return _createFadeRoute(
          ChangeNotifierProvider(
            create: (_) => ChatbotProvider(),
            child: const ChatbotScreen(),
          ),
        );
      case createBudgetRoute:
        print('AppRouter: Generoidaan reitti: $createBudgetRoute');
        final now = DateTime.now();
        return _createFadeRoute(
          CreateBudgetScreen(
            sourceBudget: BudgetModel(
              income: 0.0,
              expenses: {},
              createdAt: now,
              year: now.year,
              month: now.month,
            ),
            newYear: now.year,
            newMonth: now.month,
          ),
        );
      default:
        print('AppRouter: Tuntematon reitti: ${settings.name}, ohjataan login-sivulle');
        // Ohjaa käyttäjä takaisin login-sivulle, jos reitti on tuntematon
        return _createFadeRoute(LoginScreen());
    }
  }
}