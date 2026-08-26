import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/update_info.dart';
import 'dart:io';

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _requestTimeout = Duration(seconds: 10);
  static final _versionUrl = Uri.parse(
    'https://raw.githubusercontent.com/eelitt/budu/main/version.txt',
  );
  static final _releasesUrl = Uri.parse(
    'https://api.github.com/repos/eelitt/budu/releases/latest',
  );

  // Haetaan sovelluksen versio dynaamisesti package_info_plus-paketilla
  Future<String> getAppVersion() async {
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
  Future<UpdateInfo> checkForUpdate() async {
    final currentVersion = await getAppVersion();

    final response = await _client.get(
      _versionUrl,
      headers: {
        'Accept': 'application/vnd.github.v3.raw',
        'User-Agent': 'Budu',
      },
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      FirebaseCrashlytics.instance.recordError(
        Exception('HTTP-virhe: ${response.statusCode}'),
        StackTrace.current,
        reason: 'GitHub-version tarkistus epäonnistui',
      );
      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasNewerVersion: false,
      );
    }

    final latestVersion = response.body.trim();
    if (!_isValidVersion(latestVersion)) {
      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        hasNewerVersion: false,
      );
    }
    final isNewerVersion = isNewerVersionString(latestVersion, currentVersion);
    String? apkUrl;

    if (isNewerVersion) {
      apkUrl = await _fetchApkUrl();
    }

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
        hasNewerVersion: isNewerVersion,
      apkUrl: apkUrl,
    );
  }

  bool _isValidVersion(String version) {
    return RegExp(r'^\d+(\.\d+)*$').hasMatch(version);
  }

  // Tarkastetaan, onko uudempi versio
  static bool isNewerVersionString(String latest, String current) {
    try {
      final latestParts = latest.trim().split('.').map(int.parse).toList();
      final currentParts = current.trim().split('.').map(int.parse).toList();
      final componentCount = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;
      for (int i = 0; i < componentCount; i++) {
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
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
  Future<String?> _fetchApkUrl() async {
    final releaseResponse = await _client.get(
      _releasesUrl,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Budu',
      },
    ).timeout(_requestTimeout);

    if (releaseResponse.statusCode != 200) {
      FirebaseCrashlytics.instance.recordError(
        Exception('HTTP-virhe: ${releaseResponse.statusCode}'),
        StackTrace.current,
        reason: 'Päivitystiedon haku epäonnistui',
      );
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(releaseResponse.body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final releaseData = decoded;
    final assets = releaseData['assets'] as List<dynamic>?;

    if (assets == null || assets.isEmpty) {
      return null;
    }

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'];
        final downloadUrl = asset['browser_download_url'];
        if (name is String &&
            downloadUrl is String &&
            name.toLowerCase().endsWith('.apk') &&
            downloadUrl.isNotEmpty) {
          return downloadUrl;
        }
      }
    }

    return null;
  }

  // Ladataan ja avataan APK-tiedosto, palautetaan tulos ja päivitysprogression
  Stream<Map<String, dynamic>> downloadAndOpenApk(
    String apkUrl,
    String latestVersion,
  ) async* {
    try {
      // Valmistellaan latauspyyntö
      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['Accept'] = 'application/octet-stream';
      request.headers['User-Agent'] = 'Budu';

      // Suoritetaan lataus Stream-muodossa
      final streamedResponse =
          await _client.send(request).timeout(_requestTimeout);

      if (streamedResponse.statusCode != 200) {
        throw Exception('Päivityksen lataaminen epäonnistui: HTTP ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/budu_v$latestVersion.apk');
      final sink = apkFile.openWrite();

      // Kuunnellaan latausstreamia ja päivitetään progress
      await for (var chunk in streamedResponse.stream.timeout(_requestTimeout)) {
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