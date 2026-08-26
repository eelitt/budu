import 'package:budu/features/update/services/update_handler.dart';
import 'package:budu/features/update/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingUpdateService extends UpdateService {
  int downloadCalls = 0;

  @override
  Stream<Map<String, dynamic>> downloadAndOpenApk(
    String apkUrl,
    String latestVersion,
  ) async* {
    downloadCalls++;
    yield {'progress': 100.0};
  }
}

void main() {
  test('one download attempt invokes the service once', () async {
    final service = _CountingUpdateService();
    final handler = UpdateHandler(updateService: service);

    await handler.startDownload('https://example.com/budu.apk', '1.1.0').toList();

    expect(service.downloadCalls, 1);
  });
}