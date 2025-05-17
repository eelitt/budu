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

class UpdateHandler with ChangeNotifier {
  final UpdateService _updateService = UpdateService();
  bool _isUpdateRequired = false;
  String? _apkUrl;
  String? _latestVersion;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String? _currentVersion;

  bool get isUpdateRequired => _isUpdateRequired;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get apkUrl => _apkUrl;
  String? get latestVersion => _latestVersion;
  String? get currentVersion => _currentVersion;

  Future<void> checkForAppUpdate(BuildContext context, UpdateProvider updateProvider) async {
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
  }

  Future<bool> _checkInstallPermission() async {
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      return result.isGranted;
    }
    return true;
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

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

  Stream<Map<String, dynamic>> startDownload(String apkUrl, String latestVersion) async* {
    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
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
            notifyListeners();
            yield event;
          }
        } else if (event.containsKey('error')) {
          throw Exception(event['error'] as String);
        }
      }
    } catch (e) {
      yield {'error': e.toString()};
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

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