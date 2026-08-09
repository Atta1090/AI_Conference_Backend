/// ConvoBridge Flutter app configuration.
///
/// Physical phones cannot use `127.0.0.1` — that is the phone itself, not your
/// PC. Default is this machine's LAN IP so a plain `flutter run` works.
///
/// Override when the PC IP changes:
/// ```
/// flutter run --dart-define=AI_SERVER_BASE_URL=http://192.168.x.x:8000
/// ```
///
/// Backend must listen on `0.0.0.0:8000` (`python run_dev.py`).
class AppConfig {
  /// Real FastAPI backend base URL (no trailing slash).
  ///
  /// Keep this in sync with your PC Wi‑Fi IPv4 (`ipconfig`).
  static const String aiServerBaseUrl = String.fromEnvironment(
    'AI_SERVER_BASE_URL',
    defaultValue: 'http://192.168.133.198:8000',
  );

  /// Agora App ID.
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: 'da5575f97c4a42d4950b20abafb8f439',
  );

  static bool get isNgrok => aiServerBaseUrl.contains('ngrok');
}
