import 'dart:io';

import 'package:budu/features/update/services/update_service.dart';
import 'package:budu/firebase_options.dart';
import 'package:budu/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android updater can read the installed version and public metadata',
    (tester) async {
      if (!Platform.isAndroid) {
        fail('This integration test requires an Android device.');
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 2));

      final updateService = UpdateService();
      final currentVersion = await updateService.getAppVersion();
      final updateInfo = await updateService.checkForUpdate();

      expect(currentVersion, isNotEmpty);
      expect(updateInfo.currentVersion, currentVersion);
      expect(updateInfo.latestVersion, isNotEmpty);
      expect(
        updateInfo.isUpdateAvailable,
        updateInfo.hasNewerVersion && updateInfo.apkUrl != null,
      );
    },
  );
}
