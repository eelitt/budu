import 'dart:convert';

import 'package:budu/features/update/models/update_info.dart';
import 'package:budu/features/update/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestUpdateService extends UpdateService {
  _TestUpdateService(http.Client client) : super(client: client);

  @override
  Future<String> getAppVersion() async => '1.0.0';
}

void main() {
  test('UpdateInfo distinguishes a newer release without an APK', () {
    const info = UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      hasNewerVersion: true,
    );

    expect(info.hasNewerVersion, isTrue);
    expect(info.isUpdateAvailable, isFalse);
  });

  test('UpdateInfo reports a downloadable update', () {
    const info = UpdateInfo(
      currentVersion: '1.0.0',
      latestVersion: '1.1.0',
      hasNewerVersion: true,
      apkUrl: 'https://example.com/budu.apk',
    );

    expect(info.isUpdateAvailable, isTrue);
  });

  test('version comparison treats missing components as zero', () {
    expect(UpdateService.isNewerVersionString('1.1', '1.0.9'), isTrue);
    expect(UpdateService.isNewerVersionString('1.1.0', '1.1'), isFalse);
    expect(UpdateService.isNewerVersionString('1.0.9', '1.1'), isFalse);
  });

  test('malformed version text is treated as no update', () async {
    final service = _TestUpdateService(
      MockClient((request) async => http.Response('not-a-version', 200)),
    );

    final info = await service.checkForUpdate();

    expect(info.hasNewerVersion, isFalse);
    expect(info.isUpdateAvailable, isFalse);
  });

  test('newer release without an APK is not downloadable', () async {
    final service = _TestUpdateService(
      MockClient((request) async {
        if (request.url.path.endsWith('version.txt')) {
          return http.Response('1.1.0', 200);
        }
        return http.Response(jsonEncode({'assets': []}), 200);
      }),
    );

    final info = await service.checkForUpdate();

    expect(info.hasNewerVersion, isTrue);
    expect(info.isUpdateAvailable, isFalse);
  });

  test('selects the public APK browser download URL', () async {
    final service = _TestUpdateService(
      MockClient((request) async {
        if (request.url.path.endsWith('version.txt')) {
          return http.Response('1.1.0', 200);
        }
        return http.Response(
          jsonEncode({
            'assets': [
              {'name': 'checksums.txt'},
              {
                'name': 'budu-release.APK',
                'browser_download_url': 'https://example.com/budu.apk',
              },
            ],
          }),
          200,
        );
      }),
    );

    final info = await service.checkForUpdate();

    expect(info.apkUrl, 'https://example.com/budu.apk');
    expect(info.isUpdateAvailable, isTrue);
  });
}