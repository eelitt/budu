import 'package:budu/core/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/update/dialogs/update_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../update/providers/update_provider.dart';
import '../../update/services/update_service.dart'; 
import 'package:package_info_plus/package_info_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    _checkForAppUpdate(); // Tarkistetaan päivitykset käynnistyksessä
  }

  Future<void> _checkForAppUpdate() async {
    final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
    await updateProvider.checkForUpdate(context);

    if (updateProvider.isUpdateAvailable && updateProvider.apkUrl != null) {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Näytetään päivitysdialogi, jos päivitys on saatavilla
      showDialog(
        context: context,
        barrierDismissible: false, // Käyttäjä ei voi sulkea dialogia
        builder: (context) {
          return UpdateDialog(
            updateService: UpdateService(),
            currentVersion: currentVersion,
            latestVersion: updateProvider.latestVersion!,
            apkUrl: updateProvider.apkUrl!,
            scaffoldContext: context,
          );
        },
      );
    }
  }

  Future<void> _navigateAfterLogin() async {
    print('_navigateAfterLogin: Aloitetaan');
    try {
      final authProvider = context.read<AuthProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      if (authProvider.user != null) {
        await Future.delayed(const Duration(seconds: 2));
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
      appBar: AppBar(
        automaticallyImplyLeading: false, // Poistetaan nuoli
        title: const SizedBox.shrink(), // Poistetaan "Kirjaudu"-teksti
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sovelluksen nimi "Budu" suuremmalla fontilla
              const Text(
                'Budu',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              // "Sisäänkirjautuminen" pienemmällä fontilla
              const Text(
                'Sisäänkirjautuminen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              // "Kirjaudu Googlella" -painike keskitettynä
              SizedBox(
                width: 250, // Rajoitetaan painikkeen leveys
                child: ElevatedButton.icon(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}