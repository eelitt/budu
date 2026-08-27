import 'package:budu/core/app_router/app_router.dart';
import 'package:budu/core/utils.dart';
import 'package:budu/features/auth/domain/auth_errors.dart';
import 'package:budu/features/auth/domain/login_destination.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/features/auth/providers/user_provider.dart';
import 'package:budu/features/auth/screens/login_screen/login_button.dart';
import 'package:budu/features/auth/services/login_startup_coordinator.dart';
import 'package:budu/features/auth/services/session_bootstrap_service.dart';
import 'package:budu/features/budget/providers/budget_provider.dart';
import 'package:budu/features/budget/providers/expense_provider.dart';
import 'package:budu/features/budget/providers/shared_budget_provider.dart';
import 'package:budu/features/update/update_manager.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _StartupStatus { idle, running, done }

/// Kirjautumisnäkymä: logo, Google-kirjautuminen, session restore ja navigointi.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final UpdateManager _updateManager;
  final LoginStartupCoordinator _startupCoordinator =
      const LoginStartupCoordinator();
  bool _isLoggingIn = false;
  AuthState? _lastAuthState;
  bool _hasNavigated = false;
  _StartupStatus _startup = _StartupStatus.idle;

  @override
  void initState() {
    super.initState();
    _updateManager = UpdateManager();
    _initializeStartup();
  }

  SessionBootstrapService _bootstrapService() {
    return SessionBootstrapService(
      budgetProvider: context.read<BudgetProvider>(),
      expenseProvider: context.read<ExpenseProvider>(),
      sharedBudgetProvider: context.read<SharedBudgetProvider>(),
    );
  }

  bool get _isUpdateBlocking =>
      _updateManager.isUpdateRequired || _updateManager.isDownloading;

  Future<void> _reportFailure({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
    required String userMessage,
  }) async {
    if (error is AuthFailure && error.code != null) {
      await FirebaseCrashlytics.instance.setCustomKey('error_code', error.code!);
    }
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
    );
    if (mounted) {
      showErrorSnackBar(context, userMessage);
    }
  }

  /// Auth init runs without waiting for the update check first.
  /// Navigation stays gated until the update flow settles.
  Future<void> _initializeStartup() async {
    if (_startup != _StartupStatus.idle) {
      return;
    }
    _startup = _StartupStatus.running;
    try {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final outcome = await _startupCoordinator.run(
        initializeAuth: authProvider.initialize,
        checkUpdate: () async {
          if (!mounted) return;
          await _updateManager.checkAndHandleUpdate(context);
        },
        isUpdateBlocking: () => _isUpdateBlocking,
      );

      if (!mounted) return;
      setState(() {});

      if (outcome == LoginStartupOutcome.blockedByUpdate) {
        return;
      }

      if (authProvider.authState == AuthState.authenticated &&
          authProvider.user != null &&
          !_hasNavigated) {
        await _bootstrapAndNavigate(authProvider.user!.uid);
      }
    } catch (e, stackTrace) {
      await _reportFailure(
        error: e,
        stackTrace: stackTrace,
        reason: 'Autentikoinnin alustus epäonnistui LoginScreen:ssä',
        userMessage: 'Kirjautumisen alustus epäonnistui: $e',
      );
    } finally {
      _startup = _StartupStatus.done;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _onLoginRequested() async {
    if (_isLoggingIn || _hasNavigated || _isUpdateBlocking) return;

    setState(() {
      _isLoggingIn = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInWithGoogle();
      if (!mounted) return;

      final user = authProvider.user;
      if (user == null) {
        return;
      }

      if (_isUpdateBlocking) return;

      await _bootstrapAndNavigate(user.uid);
    } catch (e, stackTrace) {
      await _reportFailure(
        error: e,
        stackTrace: stackTrace,
        reason: 'Google Sign-In failed in LoginScreen',
        userMessage: 'Google-kirjautuminen epäonnistui: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  Future<void> _bootstrapAndNavigate(String userId) async {
    if (_hasNavigated) return;

    try {
      final result = await _bootstrapService().bootstrap(userId);
      if (!mounted) return;

      if (!result.isSuccess) {
        await _reportFailure(
          error: result.error ?? StateError('Unknown bootstrap failure'),
          stackTrace: StackTrace.current,
          reason: 'Session bootstrap failed in LoginScreen',
          userMessage: 'Navigointi epäonnistui: ${result.error}',
        );
        return;
      }

      _hasNavigated = true;
      final route = switch (result.destination!) {
        LoginDestination.chatbot => AppRouter.chatbotRoute,
        LoginDestination.mainPersonal ||
        LoginDestination.mainShared =>
          AppRouter.mainRoute,
      };

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => false,
      );
    } catch (e, stackTrace) {
      await _reportFailure(
        error: e,
        stackTrace: stackTrace,
        reason: 'Navigointi epäonnistui LoginScreen:ssä',
        userMessage: 'Navigointi epäonnistui: $e',
      );
      _hasNavigated = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (authProvider.isInitialized &&
        _lastAuthState != authProvider.authState &&
        !_hasNavigated) {
      _lastAuthState = authProvider.authState;

      if (authProvider.authState == AuthState.unauthenticated && mounted) {
        userProvider.clearUserData();
      }
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
              Text(
                'Budu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
              const SizedBox(height: 8),
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
                onLoginRequested: _onLoginRequested,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
