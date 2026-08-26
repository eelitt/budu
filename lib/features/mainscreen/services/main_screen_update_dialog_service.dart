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
    if (debugVersion == null) return;

    try {
      // Debug-tila: Simuloi päivitysdialogi
      final currentVersion = await _updateService.getAppVersion();
      final latestVersion = debugVersion;

      if (context.mounted) {
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