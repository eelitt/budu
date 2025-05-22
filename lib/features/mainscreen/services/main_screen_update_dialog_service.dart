import 'package:budu/core/utils.dart';
import 'package:budu/features/update/services/update_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

/// Palvelu päivitysdialogin näyttämiseen pääsivulla.
/// Tukee myös debug-tilaa päivityksen testaamiseksi.
class MainScreenUpdateDialogService {
  final UpdateService _updateService = UpdateService();

  /// Näyttää päivitysdialogin debug-tilassa tai kun päivitys on saatavilla.
  Future<void> checkForUpdateDialog(
    BuildContext context, {
    String? debugVersion,
  }) async {
    try {
      String currentVersion;
      String latestVersion;
      String? apkUrl;

      if (debugVersion != null) {
        // Debug-tila: Simuloi päivitysdialogi
        currentVersion = await _updateService.getAppVersion();
        latestVersion = debugVersion;
        apkUrl = 'https://example.com/test.apk'; // Simuloitu APK-URL
      } else {
        // Normaali päivitystarkistus
        final updateInfo = await _updateService.checkForUpdate(context);
        if (!(updateInfo['isUpdateAvailable'] ?? false)) {
          return; // Ei päivitystä, ei näytetä dialogia
        }
        currentVersion = updateInfo['currentVersion'] as String;
        latestVersion = updateInfo['latestVersion'] as String;
        apkUrl = updateInfo['apkUrl'] as String?;
      }

      if (context.mounted && apkUrl != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text(
                'Sovellus päivitetty versioon $latestVersion',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Uusi versio on saatavilla!\nNykyinen versio: $currentVersion\nUusi versio: $latestVersion',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Päivitysdialogin näyttäminen epäonnistui MainScreenUpdateDialogService:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Päivitysdialogin näyttäminen epäonnistui: $e');
      }
    }
  }
}