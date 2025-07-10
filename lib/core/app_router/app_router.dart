import 'package:budu/features/budget/models/budget_model.dart';
import 'package:budu/features/budget/screens/create_budget/create_budget_screen.dart';
import 'package:budu/features/budget/screens/create_budget/shared_budget/shared_create_budget_screen.dart';
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
/// Päivitetty: Lisätty optional 'isNew'-tuki sharedCreateBudgetRoute:lle (ei riko vanhaa, parantaa uuden budjetin luontia).
class AppRouter {
  static const String loginRoute = '/login';
  static const String mainRoute = '/main';
  static const String budgetRoute = '/budget';
  static const String summaryRoute = '/summary';
  static const String historyRoute = '/history';
  static const String chatbotRoute = '/chatbot';
  static const String createBudgetRoute = '/create-budget';
  static const String sharedCreateBudgetRoute = '/shared-create-budget';

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
          print('AppRouter: Generoidaan reitti: $budgetRoute');
          final args = settings.arguments as BudgetScreen?;
          return _createFadeRoute(args ?? const BudgetScreen());
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
          final startDate = DateTime(now.year, now.month, 1);
          final endDate = DateTime(now.year, now.month + 1, 0);
          return _createFadeRoute(
            CreateBudgetScreen(
              sourceBudget: BudgetModel(
                income: 0.0,
                expenses: {},
                createdAt: now,
                startDate: startDate,
                endDate: endDate,
                type: 'monthly',
              ),
            ),
          );
        case sharedCreateBudgetRoute:
          print('AppRouter: Generoidaan reitti: $sharedCreateBudgetRoute');
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null ||
              args['sharedBudgetId'] == null ||
              args['user1Id'] == null ||
              args['budgetName'] == null) {
            print('AppRouter: Virheelliset argumentit sharedCreateBudgetRoute:lle: $args');
            FirebaseCrashlytics.instance.log('AppRouter: Virheelliset argumentit sharedCreateBudgetRoute:lle: $args');
            return _createFadeRoute(const LoginScreen());
          }
          return _createFadeRoute(
            SharedCreateBudgetScreen(
              sharedBudgetId: args['sharedBudgetId'] as String,
              user1Id: args['user1Id'] as String,
              user2Id: args['user2Id'] as String?,
              budgetName: args['budgetName'] as String,
              inviteeEmail: args['inviteeEmail'] as String?, // Lisätty: Välitetään inviteeEmail, jos annettu
              isNew: args['isNew'] as bool? ?? false, // Lisätty: Välitetään isNew optionalina (default false)
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