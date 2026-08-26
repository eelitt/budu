class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasNewerVersion;
  final String? apkUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasNewerVersion,
    this.apkUrl,
  });

  bool get isUpdateAvailable => hasNewerVersion && apkUrl != null;
}
