import 'package:budu/features/budget/domain/periods.dart';
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
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// AppRouter.dart
/// Hallinnoi sovelluksen reittejä ja siirtymiä.
/// Käyttää fade-animaatiota kaikissa reiteissä yhtenäisyyden vuoksi.
/// Optimointi: Virheenkäsittely Crashlytics-loggauksella, tyypitys arguments:ille.
/// Household create uses [CreateBudgetScreen] with `isShared: true`, not a separate route.
class AppRouter {
  static const String loginRoute = '/login';
  static const String mainRoute = '/main';
  static const String budgetRoute = '/budget';
  static const String summaryRoute = '/summary';
  static const String historyRoute = '/history';
  static const String chatbotRoute = '/chatbot';
  static const String createBudgetRoute = '/create-budget';

  // Mukautettu siirtymäanimaatio FadeTransition (yhtenäinen kaikille reiteille)
  static PageRouteBuilder _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 800),
      reverseTransitionDuration: const Duration(milliseconds: 600),
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
    try {
      switch (settings.name) {
        case loginRoute:
          print('AppRouter: Generoidaan reitti: $loginRoute');
          return _createFadeRoute(const LoginScreen());
        case mainRoute:
          print('AppRouter: Generoidaan reitti: $mainRoute');
          final args = settings.arguments as Map<String, dynamic>?;
          final initialIndex = args?['index'] as int? ?? 0;
          return _createFadeRoute(MainScreen(initialIndex: initialIndex));
        case budgetRoute:
          // Tabs normally live in MainScreen's IndexedStack; these routes remain
          // for named navigation / deep links without shell callbacks.
          print('AppRouter: Generoidaan reitti: $budgetRoute');
          return _createFadeRoute(const BudgetScreen());
        case summaryRoute:
          print('AppRouter: Generoidaan reitti: $summaryRoute');
          return _createFadeRoute(const SummaryScreen());
        case historyRoute:
          print('AppRouter: Generoidaan reitti: $historyRoute');
          // Deep-link / named route outside the main shell — load immediately.
          return _createFadeRoute(const HistoryScreen(isActive: true));
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
          final range = monthRange(DateTime.now());
          return _createFadeRoute(
            CreateBudgetScreen(
              initialStart: range.start,
              initialEnd: range.end,
              initialType: 'monthly',
            ),
          );
        default:
          print('AppRouter: Tuntematon reitti: ${settings.name}, ohjataan login-sivulle');
          FirebaseCrashlytics.instance.log('AppRouter: Tuntematon reitti: ${settings.name}');
          return _createFadeRoute(const LoginScreen());
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'Failed to generate route: ${settings.name}',
      );
      print('AppRouter: Virhe reitin generoinnissa: $e');
      return _createFadeRoute(const LoginScreen());
    }
  }
}