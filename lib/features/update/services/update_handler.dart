import 'package:budu/core/utils.dart'; // Lisätty showErrorSnackBar-import
import 'package:budu/features/update/dialogs/update_dialog.dart';
import 'package:budu/features/update/providers/update_provider.dart';
import 'package:budu/features/update/services/update_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Lisätty Crashlytics-import

/// Käsittelee sovelluksen päivitykset, mukaan lukien tarkistus, lataus ja asennusoikeudet.
class UpdateHandler with ChangeNotifier {
  final UpdateService _updateService = UpdateService(); // Päivityspalvelu
  bool _isUpdateRequired = false; // Onko päivitys pakollinen
  String? _apkUrl; // APK-tiedoston lataus-URL
  String? _latestVersion; // Uusin versio
  double _downloadProgress = 0.0; // Latausprogressi (0-100)
  bool _isDownloading = false; // Onko lataus käynnissä
  String? _currentVersion; // Sovelluksen nykyinen versio

  // Getterit tilamuuttujille
  bool get isUpdateRequired => _isUpdateRequired;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get apkUrl => _apkUrl;
  String? get latestVersion => _latestVersion;
  String? get currentVersion => _currentVersion;

  /// Tarkistaa, onko sovellukselle saatavilla päivitys, ja näyttää päivitysdialogin.
  Future<void> checkForAppUpdate(BuildContext context, UpdateProvider updateProvider) async {
    try {
      await updateProvider.checkForUpdate(context);

      if (updateProvider.isUpdateAvailable && updateProvider.apkUrl != null) {
        _isUpdateRequired = true;
        _apkUrl = updateProvider.apkUrl;
        _latestVersion = updateProvider.latestVersion;

        final packageInfo = await PackageInfo.fromPlatform();
        _currentVersion = packageInfo.version;

        final hasInstallPermission = await _checkInstallPermission();
        if (!hasInstallPermission) {
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Asennusoikeudet vaaditaan'),
                  content: const Text('Sinun on sallittava asennus tuntemattomista lähteistä päivityksen asentamiseksi.'),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await openAppSettings();
                        final newStatus = await _checkInstallPermission();
                        if (newStatus) {
                          await _showUpdateDialog(context, _currentVersion!);
                        }
                      },
                      child: const Text('Avaa asetukset'),
                    ),
                  ],
                );
              },
            );
          }
          return;
        }

        final hasConnectivity = await _checkConnectivity();
        if (!hasConnectivity) {
          if (context.mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Ei verkkoyhteyttä'),
                  content: const Text('Päivityksen lataaminen vaatii internet-yhteyden. Tarkista yhteys ja yritä uudelleen.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        checkForAppUpdate(context, updateProvider);
                      },
                      child: const Text('Yritä uudelleen'),
                    ),
                  ],
                );
              },
            );
          }
          return;
        }

        await _showUpdateDialog(context, _currentVersion!);
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. päivitystarkistuksen epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Päivitystarkistus epäonnistui UpdateHandler:ssä',
      );

      // Näytä ystävällinen virheilmoitus käyttäjälle
      if (context.mounted) {
        showErrorSnackBar(context, 'Päivitystarkistus epäonnistui: $e');
      }
    }
  }

  /// Tarkistaa, onko sovelluksella oikeus asentaa tuntemattomista lähteistä.
  Future<bool> _checkInstallPermission() async {
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      return result.isGranted;
    }
    return true;
  }

  /// Tarkistaa, onko laitteella internet-yhteys.
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Näyttää päivitysdialogin, joka kysyy käyttäjältä, haluaako hän ladata päivityksen.
  Future<bool> _showUpdateDialog(BuildContext context, String currentVersion) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UpdateDialog(
          currentVersion: currentVersion,
          latestVersion: _latestVersion!,
          apkUrl: _apkUrl!,
          onUpdate: (apkUrl, latestVersion) {
            Navigator.pop(context, true);
          },
        );
      },
    );

    return result ?? false;
  }

  /// Aloittaa APK-tiedoston lataamisen ja raportoi latausprogressin streamin kautta.
  Stream<Map<String, dynamic>> startDownload(String apkUrl, String latestVersion) async* {
    try {
      // Yhdistä tilanpäivitykset: aseta _isDownloading ja _downloadProgress yhdessä
      _isDownloading = true;
      _downloadProgress = 0.0;

        notifyListeners();


      await for (var event in _updateService.downloadAndOpenApk(apkUrl, latestVersion)) {
        if (event.containsKey('progress')) {
          _downloadProgress = event['progress'] as double;

            notifyListeners();

          yield event;
        } else if (event.containsKey('result')) {
          final result = event['result'] as OpenResult;
          if (result.type != ResultType.done) {
            yield event;
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isUpdated', true);
            await prefs.setString('updatedVersion', latestVersion);
            _isUpdateRequired = false;
            _isDownloading = false; // Yhdistetty finally-lohkon kanssa

              notifyListeners();

            yield event;
          }
        } else if (event.containsKey('error')) {
          throw Exception(event['error'] as String);
        }
      }
    } catch (e) {
      // Raportoi kriittinen virhe Crashlyticsiin (esim. APK-latauksen epäonnistuminen)
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'APK-lataus epäonnistui UpdateHandler:ssä',
      );
      yield {'error': e.toString()};
    } finally {
      _isDownloading = false;

        notifyListeners();

    }
  }

  /// Pyytää asennusoikeudet ja ohjaa käyttäjän asetuksiin, jos oikeuksia ei ole.
  Future<void> requestInstallPermission(BuildContext context, String apkUrl, String latestVersion) async {
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Asennusoikeudet vaaditaan'),
            content: const Text('Sinun on sallittava asennus tuntemattomista lähteistä jatkaaksesi.'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                  if (context.mounted) {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Yritä uudelleen'),
                          content: const Text('Haluatko yrittää asennusta uudelleen?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Kyllä'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                final updateProvider = Provider.of<UpdateProvider>(context, listen: false);
                                checkForAppUpdate(context, updateProvider);
                              },
                              child: const Text('Ei'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                child: const Text('Avaa asetukset'),
              ),
            ],
          );
        },
      );
    }
  }
}