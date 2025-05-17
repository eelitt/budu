import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/theme.dart';
import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/update/providers/update_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/budget/providers/budget_provider.dart';
import 'features/notification/providers/notification_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    await dotenv.load(fileName: ".env");
    print('Loaded .env file successfully');
  } catch (e) {
    print('Failed to load .env file: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      StackTrace.current,
      reason: 'Failed to load .env file',
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: MaterialApp(
        title: 'Budu',
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.loginRoute,
        onGenerateRoute: AppRouter.generateRoute,
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('404 - Sivua ei löydy')),
          ),
        ),
        navigatorObservers: [
          AppRouter.routeObserver,
        ],
      ),
    );
  }
}