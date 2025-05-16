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
    // Varmistetaan, että .env-arvot ovat saatavilla
    final versionUrl = dotenv.env['VERSION_URL'];
    final apiToken = dotenv.env['GITHUB_API_TOKEN'];

    if (versionUrl == null || versionUrl.isEmpty) {
      FirebaseCrashlytics.instance.recordError(
        Exception('VERSION_URL puuttuu .env-tiedostosta'),
        StackTrace.current,
        reason: 'Päivitystarkistus epäonnistui',
      );
      return {'isUpdateAvailable': false};
    }

    final currentVersion = await _getAppVersion();

    final response = await http.get(
      Uri.parse(versionUrl),
      headers: {
        if (apiToken != null && apiToken.isNotEmpty) 'Authorization': 'token $apiToken',
        'Accept': 'application/vnd.github.v3.raw',
      },
    );

    if (response.statusCode != 200) {
      FirebaseCrashlytics.instance.recordError(
        Exception('HTTP-virhe: ${response.statusCode}'),
        StackTrace.current,
        reason: 'GitHub-version tarkistus epäonnistui',
      );
      return {'isUpdateAvailable': false};
    }

    final latestVersion = response.body.trim();
    final isUpdateAvailable = _isNewerVersion(latestVersion, currentVersion);
    String? apkUrl;

    if (isUpdateAvailable) {
      apkUrl = await _fetchApkUrl(latestVersion);
    }

    return {
      'isUpdateAvailable': isUpdateAvailable,
      'latestVersion': latestVersion,
      'apkUrl': apkUrl,
      'currentVersion': currentVersion,
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
  Future<String?> _fetchApkUrl(String latestVersion) async {
    final repoOwner = dotenv.env['GITHUB_OWNER'];
    final repoName = dotenv.env['GITHUB_REPO'];
    final apiToken = dotenv.env['GITHUB_API_TOKEN'];

    if (repoOwner == null || repoOwner.isEmpty || repoName == null || repoName.isEmpty) {
      FirebaseCrashlytics.instance.recordError(
        Exception('GITHUB_OWNER tai GITHUB_REPO puuttuu .env-tiedostosta'),
        StackTrace.current,
        reason: 'Päivitystiedon haku epäonnistui',
      );
      return null;
    }

    final releasesUrl = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
    final releaseResponse = await http.get(
      releasesUrl,
      headers: {
        if (apiToken != null && apiToken.isNotEmpty) 'Authorization': 'token $apiToken',
        'Accept': 'application/vnd.github+json',
      },
    );

    if (releaseResponse.statusCode != 200) {
      FirebaseCrashlytics.instance.recordError(
        Exception('HTTP-virhe: ${releaseResponse.statusCode}'),
        StackTrace.current,
        reason: 'Päivitystiedon haku epäonnistui',
      );
      return null;
    }

    final releaseData = jsonDecode(releaseResponse.body) as Map<String, dynamic>;
    final assets = releaseData['assets'] as List<dynamic>?;

    if (assets == null || assets.isEmpty) {
      return null;
    }

    final apkAsset = assets
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (asset) => (asset['name'] as String).endsWith('.apk'),
          orElse: () => <String, dynamic>{},
        );

    if (apkAsset.isEmpty) {
      return null;
    }

    return apkAsset['url'] as String;
  }

  // Ladataan ja avataan APK-tiedosto, palautetaan tulos ja päivitysprogression
  Stream<Map<String, dynamic>> downloadAndOpenApk(
    String apkUrl,
    String latestVersion,
  ) async* {
    final apiToken = dotenv.env['GITHUB_API_TOKEN'];

    try {
      // Valmistellaan latauspyyntö
      final request = http.Request('GET', Uri.parse(apkUrl));
      if (apiToken != null && apiToken.isNotEmpty) {
        request.headers['Authorization'] = 'token $apiToken';
      }
      request.headers['Accept'] = 'application/octet-stream';

      // Suoritetaan lataus Stream-muodossa
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Päivityksen lataaminen epäonnistui: HTTP ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/budu_v$latestVersion.apk');
      final sink = apkFile.openWrite();

      // Kuunnellaan latausstreamia ja päivitetään progress
      await for (var chunk in streamedResponse.stream) {
        receivedBytes += chunk.length;
        sink.add(chunk);

        // Lasketaan latausprosentti ja lähetetään se streamiin
        if (contentLength > 0) {
          final progress = (receivedBytes / contentLength * 100).clamp(0, 100).toDouble();
          yield {'progress': progress};
        }
      }

      await sink.close();

      // Yritä avata APK
      final result = await OpenFile.open(apkFile.path);
      yield {'result': result};
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Päivityksen lataaminen epäonnistui',
      );
      yield {'error': e.toString()};
    }
  }
}