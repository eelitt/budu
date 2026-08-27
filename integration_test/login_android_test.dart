import 'dart:io';

import 'package:budu/features/auth/data/user_profile_repository.dart';
import 'package:budu/features/auth/providers/auth_provider.dart';
import 'package:budu/firebase_options.dart';
import 'package:budu/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

/// Android smoke coverage for login session readiness.
///
/// Interactive Google account picker flows (success, cancel, first-time profile)
/// still need manual device verification with configured Firebase/Google Sign-In.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android login reaches auth readiness and shows login or restores session',
    (tester) async {
      if (!Platform.isAndroid) {
        fail('This integration test requires an Android device.');
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await tester.pumpWidget(const MyApp());

      final auth = Provider.of<AuthProvider>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      final ready = await _waitUntil(
        tester,
        () => auth.isInitialized,
        timeout: const Duration(seconds: 30),
      );
      expect(ready, isTrue, reason: 'AuthProvider should finish initialize()');
      expect(
        auth.authState,
        anyOf(AuthState.authenticated, AuthState.unauthenticated),
      );

      if (auth.authState == AuthState.unauthenticated) {
        expect(find.text('Budu'), findsWidgets);
        expect(find.text('Kirjaudu Googlella'), findsOneWidget);
        return;
      }

      final uid = auth.user?.uid;
      expect(uid, isNotNull);
      expect(auth.user?.email, isNotEmpty);

      final profile = await UserProfileRepository().getProfile(uid!);
      expect(
        profile,
        isNotNull,
        reason: 'Restored session should have users/{uid}',
      );
      expect(profile!.email, isNotEmpty);
    },
  );
}

Future<bool> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 200));
  }
  return condition();
}
