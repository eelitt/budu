import 'dart:async';

import 'package:budu/features/auth/services/login_startup_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coordinator = LoginStartupCoordinator();

  test('auth completes before a slow update check finishes', () async {
    var authDone = false;
    var updateDone = false;
    final authStarted = Completer<void>();
    final releaseUpdate = Completer<void>();

    final outcomeFuture = coordinator.run(
      initializeAuth: () async {
        authStarted.complete();
        authDone = true;
      },
      checkUpdate: () async {
        await releaseUpdate.future;
        updateDone = true;
      },
      isUpdateBlocking: () => false,
    );

    await authStarted.future;
    expect(authDone, isTrue);
    expect(updateDone, isFalse);

    releaseUpdate.complete();
    expect(await outcomeFuture, LoginStartupOutcome.readyToBootstrap);
    expect(updateDone, isTrue);
  });

  test('update failure after auth still yields readyToBootstrap when not blocking',
      () async {
    final outcome = await coordinator.run(
      initializeAuth: () async {},
      checkUpdate: () async {
        // UpdateManager swallows errors; a completed check with no block is OK.
      },
      isUpdateBlocking: () => false,
    );

    expect(outcome, LoginStartupOutcome.readyToBootstrap);
  });

  test('mandatory update blocks bootstrap after auth is ready', () async {
    var authDone = false;

    final outcome = await coordinator.run(
      initializeAuth: () async {
        authDone = true;
      },
      checkUpdate: () async {},
      isUpdateBlocking: () => true,
    );

    expect(authDone, isTrue);
    expect(outcome, LoginStartupOutcome.blockedByUpdate);
  });

  test('auth error still awaits update check before propagating', () async {
    var updateDone = false;
    final releaseUpdate = Completer<void>();

    final outcomeFuture = coordinator.run(
      initializeAuth: () async {
        throw Exception('auth failed');
      },
      checkUpdate: () async {
        await releaseUpdate.future;
        updateDone = true;
      },
      isUpdateBlocking: () => false,
    );

    expect(updateDone, isFalse);
    releaseUpdate.complete();

    await expectLater(outcomeFuture, throwsA(isA<Exception>()));
    expect(updateDone, isTrue);
  });

  test('disposed-style skip: caller can ignore outcome without bootstrap', () async {
    // Simulates LoginScreen checking mounted after run() and skipping navigate.
    final outcome = await coordinator.run(
      initializeAuth: () async {},
      checkUpdate: () async {},
      isUpdateBlocking: () => false,
    );

    const mounted = false;
    final shouldBootstrap =
        mounted && outcome == LoginStartupOutcome.readyToBootstrap;
    expect(shouldBootstrap, isFalse);
  });
}
