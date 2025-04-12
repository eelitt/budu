import 'package:budu/core/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/chatbot/providers/chatbot_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../chatbot/screens/chatbot_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _navigateAfterLogin() async {
  print('_navigateAfterLogin: Aloitetaan');
  try {
    final authProvider = context.read<AuthProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    if (authProvider.user != null) {
      print('_navigateAfterLogin: Käyttäjä löytyy: ${authProvider.user!.uid}');
      await budgetProvider.loadBudget(authProvider.user!.uid, DateTime.now().year, DateTime.now().month);
      print('_navigateAfterLogin: Budjetti ladattu, budget == null: ${budgetProvider.budget == null}');
      if (mounted) {
        if (budgetProvider.budget == null) {
          print('_navigateAfterLogin: Budjetti on null, tarkistetaan Firestore');
          final budgetsSnapshot = await FirebaseFirestore.instance
              .collection('budgets')
              .doc(authProvider.user!.uid)
              .collection('monthly_budgets')
              .limit(1)
              .get();
          print('_navigateAfterLogin: Budjettidokumenttien määrä: ${budgetsSnapshot.docs.length}');
          if (budgetsSnapshot.docs.isEmpty) {
            print('_navigateAfterLogin: Ei budjetteja, ohjataan chatbot-sivulle');
            Navigator.pushReplacementNamed(context, AppRouter.chatbotRoute);
          } else {
            print('_navigateAfterLogin: Budjetti löytyy, ohjataan pääsivulle');
            Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
          }
        } else {
          print('_navigateAfterLogin: Nykyinen budjetti löytyy, ohjataan pääsivulle');
          Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
        }
      }
    }
  } catch (e) {
    print('_navigateAfterLogin: Virhe navigoinnissa: $e');
  }
}

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirjaudu')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ... muut widgetit ...
            ElevatedButton(
              onPressed: () async {
                try {
                  print('Aloitetaan sähköpostikirjautuminen');
                  await context.read<AuthProvider>().signIn(
                        _emailController.text,
                        _passwordController.text,
                      );
                  print('Kirjautuminen onnistui, kutsutaan _navigateAfterLogin');
                  await _navigateAfterLogin();
                } catch (e) {
                  if (mounted) {
                    print('Kirjautumisvirhe: $e');
                    showErrorSnackBar(context, 'Kirjautuminen epäonnistui: $e');
                  }
                }
              },
              child: const Text('Kirjaudu'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  print('Aloitetaan Google-kirjautuminen');
                  await context.read<AuthProvider>().signInWithGoogle();
                  print('Google-kirjautuminen onnistui, kutsutaan _navigateAfterLogin');
                  await _navigateAfterLogin();
                } catch (e) {
                  if (mounted) {
                    print('Google-kirjautumisvirhe: $e');
                    showErrorSnackBar(context, 'Google-kirjautuminen epäonnistui: $e');
                  }
                }
              },
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Kirjaudu Googlella'),
            ),
          ],
        ),
      ),
    );
  }
}