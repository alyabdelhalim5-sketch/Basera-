import 'package:shared_preferences/shared_preferences.dart';

/// Persists user settings across app restarts.
class SettingsService {
  static const _keyIp = 'backend_ip';
  static const _keyPort = 'backend_port';
  static const _keyLanguage = 'language';
  static const _keyMaxTokens = 'max_tokens';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get backendIp => _prefs.getString(_keyIp) ?? '192.168.1.100';
  int get backendPort => _prefs.getInt(_keyPort) ?? 8000;
  String get language => _prefs.getString(_keyLanguage) ?? 'ar';
  int get maxTokens => _prefs.getInt(_keyMaxTokens) ?? 120;

  Future<void> saveBackendIp(String ip) => _prefs.setString(_keyIp, ip);
  Future<void> saveBackendPort(int port) => _prefs.setInt(_keyPort, port);
  Future<void> saveLanguage(String lang) => _prefs.setString(_keyLanguage, lang);
  Future<void> saveMaxTokens(int tokens) => _prefs.setInt(_keyMaxTokens, tokens);
}
