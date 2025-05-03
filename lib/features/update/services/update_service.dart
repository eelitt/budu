import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class UpdateService {
  // Haetaan sovelluksen versio dynaamisesti package_info_plus-paketilla
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version; // Palauttaa version pubspec.yaml-tiedostosta
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Sovelluksen version haku epäonnistui',
      );
      return '0.0.0'; // Oletusarvo, jos haku epäonnistuu
    }
  }

  // Tarkastetaan GitHubista, onko uutta versiota saatavilla
  Future<Map<String, dynamic>> checkForUpdate(BuildContext context) async {
    final currentVersion = await _getAppVersion();
    final versionUrl = dotenv.env['VERSION_URL'] ?? '';
    final apiToken = dotenv.env['GITHUB_API_TOKEN'] ?? '';

    final response = await http.get(
      Uri.parse(versionUrl),
      headers: {
        if (apiToken.isNotEmpty) 'Authorization': 'token $apiToken',
        'Accept': 'application/vnd.github.v3.raw',
      },
    );

    if (response.statusCode != 200) {
      FirebaseCrashlytics.instance.recordError(
        Exception('HTTP-virhe: ${response.statusCode}'),
        StackTrace.current,
        reason: 'GitHub-version tarkistus epäonnistui',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Päivitystarkistus epäonnistui: HTTP ${response.statusCode}')),
      );
      return {'isUpdateAvailable': false};
    }

    final latestVersion = response.body.trim();
    final isUpdateAvailable = _isNewerVersion(latestVersion, currentVersion);
    String? apkUrl;

    if (isUpdateAvailable) {
      apkUrl = await _fetchApkUrl(latestVersion, context);
    }

    return {
      'isUpdateAvailable': isUpdateAvailable,
      'latestVersion': latestVersion,
      'apkUrl': apkUrl,
    };
  }

  // Tarkastetaan, onko uudempi versio
  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Versioiden vertailu epäonnistui',
      );
      return false; // Oletetaan, että ei ole uutta versiota, jos vertailu epäonnistuu
    }
  }

  // Haetaan APK-tiedoston URL GitHub Releases -osiosta
  Future<String?> _fetchApkUrl(String latestVersion, BuildContext context) async {
    final repoOwner = dotenv.env['GITHUB_OWNER'] ?? '';
    final repoName = dotenv.env['GITHUB_REPO'] ?? '';
    final apiToken = dotenv.env['GITHUB_PAT'] ?? '';

    final releasesUrl = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
    final releaseResponse = await http.get(
      releasesUrl,
      headers: {
        if (apiToken.isNotEmpty) 'Authorization': 'token $apiToken',
        'Accept': 'application/vnd.github+json',
      },
    );

    if (releaseResponse.statusCode != 200) {
      FirebaseCrashlytics.instance.recordError(
        Exception('HTTP-virhe: ${releaseResponse.statusCode}'),
        StackTrace.current,
        reason: 'Päivitystiedon haku epäonnistui',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Päivitystiedon haku epäonnistui: HTTP ${releaseResponse.statusCode}')),
      );
      return null;
    }

    final releaseData = jsonDecode(releaseResponse.body) as Map<String, dynamic>;
    final assets = releaseData['assets'] as List<dynamic>?;

    if (assets == null || assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Päivityksessä ei ole tiedostoja")),
      );
      return null;
    }

    final apkAsset = assets
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (asset) => (asset['name'] as String).endsWith('.apk'),
          orElse: () => <String, dynamic>{},
        );

    if (apkAsset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Päivityksessä ei ole APK-tiedostoa")),
      );
      return null;
    }

    return apkAsset['url'] as String;
  }

  // Ladataan ja avataan APK-tiedosto
  Future<void> downloadAndOpenApk(BuildContext context, String apkUrl, String latestVersion) async {
    final apiToken = dotenv.env['GITHUB_API_TOKEN'] ?? '';

    // Näytetään latausdialogi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Ladataan päivitystä...", style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.black87,
      ),
    );

    try {
      final apkResponse = await http.get(
        Uri.parse(apkUrl),
        headers: {
          if (apiToken.isNotEmpty) 'Authorization': 'token $apiToken',
          'Accept': 'application/octet-stream',
        },
      );

      if (apkResponse.statusCode != 200) {
        Navigator.pop(context); // Sulje latausdialogi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Päivityksen lataaminen epäonnistui: HTTP ${apkResponse.statusCode}')),
        );
        FirebaseCrashlytics.instance.recordError(
          Exception('HTTP-virhe: ${apkResponse.statusCode}'),
          StackTrace.current,
          reason: 'APK:n lataaminen epäonnistui',
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/budu_v$latestVersion.apk');
      await apkFile.writeAsBytes(apkResponse.bodyBytes);

      Navigator.pop(context); // Sulje latausdialogi

      // Yritä avata APK
      final result = await OpenFile.open(apkFile.path);
      if (result.type != ResultType.done) {
        if (result.message.contains("REQUEST_INSTALL_PACKAGES")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Salli asennus tuntemattomista lähteistä"),
              action: SnackBarAction(
                label: 'Avaa asetukset',
                onPressed: () async {
                  try {
                    // Android-asetusten avaaminen ei aina toimi samalla tavalla kaikissa laitteissa,
                    // joten tämä on yksinkertaistettu versio
                    final retryResult = await OpenFile.open(apkFile.path);
                    if (retryResult.type != ResultType.done) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('APK:n avaaminen epäonnistui uudelleen: ${retryResult.message}')),
                      );
                      FirebaseCrashlytics.instance.recordError(
                        Exception(retryResult.message),
                        StackTrace.current,
                        reason: 'APK:n avaaminen epäonnistui asetusten jälkeen',
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Asetusten avaaminen epäonnistui: $e")),
                    );
                    FirebaseCrashlytics.instance.recordError(
                      e,
                      StackTrace.current,
                      reason: 'Asetusten avaaminen epäonnistui',
                    );
                  }
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('APK:n avaaminen epäonnistui: ${result.message}')),
          );
          FirebaseCrashlytics.instance.recordError(
            Exception(result.message),
            StackTrace.current,
            reason: 'APK:n avaaminen epäonnistui',
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Varmista, että latausdialogi sulkeutuu
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Virhe päivityksen lataamisessa: $e')),
      );
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Päivityksen lataaminen epäonnistui',
      );
    }
  }
}