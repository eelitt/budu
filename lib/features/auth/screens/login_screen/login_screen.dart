import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/screens/login_screen/login_button.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/update/update_manager.dart'; // Korvattu UpdateHandler-import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Kirjautumisnäkymä, joka näyttää sovelluksen logon ja Google-kirjautumispainikkeen.
/// Käsittelee autentikointitilan muutokset ja navigoi käyttäjän oikealle sivulle.
/// Delegoi päivitystarkistuksen ja latauksen UpdateManager-luokalle.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final UpdateManager _updateManager; // Päivitysten hallinta
  bool _isLoggingIn = false; // Näyttääkö kirjautumisindikaattorin
  AuthState? _lastAuthState; // Seuraa edellistä autentikointitilaa
  bool _hasNavigated = false; // Lippu ennenaikaisen navigoinnin estämiseksi
  bool _isInitializing = false; // Lippu estämään useat initialize-kutsut
  bool _hasInitialized = false; // Lippu estämään useat _initializeAuth-kutsut

  @override
  void initState() {
    super.initState();
  
   
   _updateManager = UpdateManager();
     
    _initializeAuth();
  }

  /// Alustaa autentikoinnin ja tarkistaa käyttäjän tilan.
  Future<void> _initializeAuth() async {
    if (_isInitializing || _hasInitialized) {
      print('LoginScreen: Auth-alustus jo käynnissä tai suoritettu, ohitetaan');
      return;
    }
    _isInitializing = true;
    try {
      // Suoritetaan päivitystarkistus ja odotetaan sen valmistumista
      print('LoginScreen: initState - Aloitetaan päivitystarkistus');
      await _updateManager.checkAndHandleUpdate(context);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();
      if (authProvider.authState == AuthState.authenticated && authProvider.user != null && !_hasNavigated) {
        print('LoginScreen: Automaattikirjautuminen onnistui, UID: ${authProvider.user!.uid}');
        await _navigateAfterLogin(authProvider.user!.uid);
      } else {
        print('LoginScreen: Automaattikirjautumista ei suoritettu, authState: ${authProvider.authState}');
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. autentikoinnin epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Autentikoinnin alustus epäonnistui LoginScreen:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Kirjautumisen alustus epäonnistui: $e');
      }
    } finally {
      _isInitializing = false;
      _hasInitialized = true; // Merkitään alustus suoritetuksi
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Tarkista authState-muutokset vain, jos alustus on valmis
    if (authProvider.isInitialized && _lastAuthState != authProvider.authState && !_hasNavigated) {
      _lastAuthState = authProvider.authState;

      if (authProvider.authState == AuthState.unauthenticated) {
        if (context.mounted) {
          userProvider.clearUserData();
          print('LoginScreen: Käyttäjätiedot tyhjennetty, authState: unauthenticated');
        }
      }
    }
  }

  /// Navigoi käyttäjän oikealle sivulle autentikoinnin jälkeen.
  /// Ohjaa joko pääsivulle (mainRoute) tai chatbot-sivulle (chatbotRoute) budjetin olemassaolon perusteella.
  Future<void> _navigateAfterLogin(String userId) async {
    if (_hasNavigated) {
      print('LoginScreen: Navigointi estetty, _hasNavigated on true');
      return; // Estä uudelleennavigointi
    }
    _hasNavigated = true;
    print('_navigateAfterLogin: Aloitetaan, UID: $userId');

    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);

      final now = DateTime.now();
      await budgetProvider.loadBudget(userId, now.year, now.month);
      print('LoginScreen: Budjetti ladattu, budget == null: ${budgetProvider.budget == null}');

      if (context.mounted) {
        if (budgetProvider.budget == null) {
          print('LoginScreen: Budjetti on null, tarkistetaan Firestore');
          final budgetsSnapshot = await FirebaseFirestore.instance
              .collection('budgets')
              .doc(userId)
              .collection('monthly_budgets')
              .limit(1)
              .get();
          print('LoginScreen: Budjettidokumenttien määrä: ${budgetsSnapshot.docs.length}');

          if (budgetsSnapshot.docs.isEmpty) {
            print('LoginScreen: Ei budjetteja, ohjataan chatbot-sivulle');
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.chatbotRoute,
              (route) => false,
            );
          } else {
            print('LoginScreen: Budjetti löytyy, haetaan tapahtumat ja ohjataan pääsivulle');
            await expenseProvider.loadAllExpenses(userId);
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.mainRoute,
              (route) => false,
            );
          }
        } else {
          print('LoginScreen: Nykyinen budjetti löytyy, haetaan tapahtumat ja ohjataan pääsivulle');
          await expenseProvider.loadAllExpenses(userId);
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.mainRoute,
            (route) => false,
          );
        }
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. Firestore-operaation epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Navigointi epäonnistui LoginScreen:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Navigointi epäonnistui: $e');
      }

      // Palauta _hasNavigated-tila, jotta navigointi voidaan yrittää uudelleen
      _hasNavigated = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sovelluksen logo pyöristetyillä reunoilla
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'lib/assets/images/budgetLogo2.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              // Sovelluksen nimi
              Text(
                'Budu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
              const SizedBox(height: 8),
              // "Sisäänkirjautuminen"-teksti
              Text(
                'Sisäänkirjautuminen',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 32),
              LoginButton(
                isLoggingIn: _isLoggingIn,
                isUpdateRequired: _updateManager.isUpdateRequired,
                isDownloading: _updateManager.isDownloading,
                onLoginStart: () {
                  if (mounted) {
                    setState(() {
                      _isLoggingIn = true;
                    });
                  }
                },
                onLoginEnd: () {
                  if (mounted) {
                    setState(() {
                      _isLoggingIn = false;
                    });
                  }
                },
                onError: (context, error) {
                  showErrorSnackBar(context, error);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}