import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/screens/login_screen/login_button.dart';
import 'package:budu/features/auth/screens/login_screen/update_dialog_wrapper.dart';
import 'package:budu/features/auth/screens/login_screen/update_handler.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final UpdateHandler _updateHandler = UpdateHandler();
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _checkForAppUpdate();
  }

  void _checkForAppUpdate() {
    final updateDialogWrapper = UpdateDialogWrapper(
      updateHandler: _updateHandler,
      currentVersion: '1.0.0',
    );
    updateDialogWrapper.show(context);
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
                borderRadius: BorderRadius.circular(16), // Pyöristyssäde (voit säätää arvoa)
                child: Image.asset(
                  'lib/assets/images/budgetLogo2.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover, // Varmistetaan, että kuva täyttää tilan
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
                isUpdateRequired: _updateHandler.isUpdateRequired,
                isDownloading: _updateHandler.isDownloading,
                onLoginStart: () {
                  setState(() {
                    _isLoggingIn = true;
                  });
                },
                onLoginEnd: () {
                  setState(() {
                    _isLoggingIn = false;
                  });
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