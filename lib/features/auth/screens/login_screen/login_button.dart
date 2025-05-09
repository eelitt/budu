import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginButton extends StatelessWidget {
  final bool isLoggingIn;
  final bool isUpdateRequired;
  final bool isDownloading;
  final VoidCallback onLoginStart;
  final VoidCallback onLoginEnd;
  final Function(BuildContext, String) onError;

  const LoginButton({
    super.key,
    required this.isLoggingIn,
    required this.isUpdateRequired,
    required this.isDownloading,
    required this.onLoginStart,
    required this.onLoginEnd,
    required this.onError,
  });

  Future<void> _navigateAfterLogin(BuildContext context) async {
    print('_navigateAfterLogin: Aloitetaan');
    try {
      final authProvider = context.read<AuthProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      if (authProvider.user != null) {
        await Future.delayed(const Duration(seconds: 2));
        print('_navigateAfterLogin: Käyttäjä löytyy: ${authProvider.user!.uid}');
        // Haetaan budjettidata vain tässä vaiheessa
        final now = DateTime.now();
        await budgetProvider.loadBudget(authProvider.user!.uid, now.year, now.month);
        print('_navigateAfterLogin: Budjetti ladattu, budget == null: ${budgetProvider.budget == null}');
        if (context.mounted) {
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
              print('_navigateAfterLogin: Budjetti löytyy, haetaan tapahtumat ja ohjataan pääsivulle');
              await expenseProvider.loadAllExpenses(authProvider.user!.uid);
              Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
            }
          } else {
            print('_navigateAfterLogin: Nykyinen budjetti löytyy, haetaan tapahtumat ja ohjataan pääsivulle');
            await expenseProvider.loadAllExpenses(authProvider.user!.uid);
            Navigator.pushReplacementNamed(context, AppRouter.mainRoute);
          }
        }
      }
    } catch (e) {
      print('_navigateAfterLogin: Virhe navigoinnissa: $e');
      onError(context, 'Navigointi epäonnistui: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoggingIn
        ? Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor, // Teeman primaryColor (Colors.blueGrey[800])
            ),
          )
        : ElevatedButton.icon(
            onPressed: isUpdateRequired || isDownloading
                ? null
                : () async {
                    onLoginStart();
                    try {
                      print('Aloitetaan Google-kirjautuminen');
                      await context.read<AuthProvider>().signInWithGoogle();
                      print('Google-kirjautuminen onnistui, kutsutaan _navigateAfterLogin');
                      await _navigateAfterLogin(context);
                    } catch (e) {
                      print('Google-kirjautumisvirhe: $e');
                      onError(context, 'Google-kirjautuminen epäonnistui: $e');
                    } finally {
                      onLoginEnd();
                    }
                  },
            icon: Icon(
              Icons.g_mobiledata,
              size: 24, // Säädetty ikonin kokoa hieman suuremmaksi
              color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}), // Teeman foregroundColor (valkoinen)
            ),
            label: Text(
              'Kirjaudu Googlella',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}),
                  ),
            ),
            style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                  minimumSize: WidgetStateProperty.all(const Size(250, 48)), // Asetetaan minimi leveys ja korkeus
                ),
          );
  }
}