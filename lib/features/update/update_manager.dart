import 'package:budu/core/utils.dart';
import 'package:budu/features/update/dialogs/update_dialog_wrapper.dart';
import 'package:budu/features/update/services/update_handler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Kapseloi sovelluksen päivitystarkistuksen ja latauslogiikan keskitetysti.
/// Vastaa päivityksen tarkistamisesta, dialogin näyttämisestä ja APK-tiedoston lataamisesta.
class UpdateManager {
  final UpdateHandler _updateHandler;

  UpdateManager() : _updateHandler = UpdateHandler();

  /// Tarkistaa, onko sovellukselle saatavilla päivitys, ja hoitaa päivityksen lataamisen.
  Future<void> checkAndHandleUpdate(BuildContext context) async {
    print('UpdateManager: checkAndHandleUpdate - Aloitetaan päivitystarkistus');
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('UpdateManager: checkAndHandleUpdate - Nykyinen versio: $currentVersion');

      final updateDialogWrapper = UpdateDialogWrapper(
        updateHandler: _updateHandler,
        currentVersion: currentVersion,
      );
      final shouldUpdate = await updateDialogWrapper.show(context);
      print('UpdateManager: checkAndHandleUpdate - Päivitys tarpeellinen: $shouldUpdate');

      if (shouldUpdate && _updateHandler.apkUrl != null && _updateHandler.latestVersion != null) {
        print('UpdateManager: checkAndHandleUpdate - Aloitetaan päivityksen lataus');
        await _startDownload(context, _updateHandler.apkUrl!, _updateHandler.latestVersion!);
      } else {
        print('UpdateManager: checkAndHandleUpdate - Ei päivitystä saatavilla tai APK-URL puuttuu');
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. päivitystarkistuksen epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Päivitystarkistus epäonnistui UpdateManager:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Päivitystarkistus epäonnistui: $e');
      }
    }
  }

  /// Aloittaa APK-tiedoston lataamisen ja näyttää latausdialogin.
  /// Käsittelee latausprogressin ja virheet.
  Future<void> _startDownload(BuildContext context, String apkUrl, String latestVersion) async {
    print('UpdateManager: _startDownload - Ladataan APK: $apkUrl (versio: $latestVersion)');
    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return StreamBuilder<Map<String, dynamic>>(
              stream: _updateHandler.startDownload(apkUrl, latestVersion),
              builder: (context, snapshot) {
                double progress = _updateHandler.downloadProgress;
                if (snapshot.hasData && snapshot.data!.containsKey('progress')) {
                  progress = snapshot.data!['progress'] as double;
                }

                return AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Ladataan päivitystä...", style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress / 100),
                      const SizedBox(height: 8),
                      Text('${progress.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  backgroundColor: Colors.black87,
                );
              },
            );
          },
        );
      }

      await for (var event in _updateHandler.startDownload(apkUrl, latestVersion)) {
        if (event.containsKey('result')) {
          final result = event['result'] as OpenResult;
          print('UpdateManager: _startDownload - Lataus valmis, tulos: ${result.type}');
          if (result.type != ResultType.done && result.message.contains("REQUEST_INSTALL_PACKAGES")) {
            print('UpdateManager: _startDownload - Pyydetään asennusoikeudet');
            await _updateHandler.requestInstallPermission(context, apkUrl, latestVersion);
            await _startDownload(context, apkUrl, latestVersion);
          }
        } else if (event.containsKey('error')) {
          print('UpdateManager: _startDownload - Virhe latauksessa: ${event['error']}');
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Päivityksen lataaminen epäonnistui'),
                  content: Text('Virhe: ${event['error']}\nHaluatko yrittää uudelleen?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startDownload(context, apkUrl, latestVersion);
                      },
                      child: const Text('Kyllä'),
                    ),
                  ],
                );
              },
            );
          }
        }
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. APK-latauksen epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Päivityksen lataaminen epäonnistui UpdateManager:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Päivityksen lataaminen epäonnistui: $e');
      }
    } finally {
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Getterit, joita käytetään LoginButton-widgetissä
  bool get isUpdateRequired => _updateHandler.isUpdateRequired;
  bool get isDownloading => _updateHandler.isDownloading;
}