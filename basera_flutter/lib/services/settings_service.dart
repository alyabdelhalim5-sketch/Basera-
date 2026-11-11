import 'package:shared_preferences/shared_preferences.dart';

/// Persists user settings across app restarts.
class SettingsService {
  static const _keyIp = 'backend_ip';
  static const _keyPort = 'backend_port';
  static const _keyLanguage = 'language';
  static const _keyMaxTokens = 'max_tokens';
  static const _keyIsOffline = 'is_offline_mode';
  static const _keyActiveSource = 'active_source';
  static const _keyGlassesIp = 'glasses_ip';
  static const _keyGlassesPort = 'glasses_port';
  static const _keyAutoScan = 'auto_scan';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  String get backendIp => _prefs.getString(_keyIp) ?? '10.0.0.109';
  int get backendPort => _prefs.getInt(_keyPort) ?? 8000;
  String get language => _prefs.getString(_keyLanguage) ?? 'ar';
  int get maxTokens => _prefs.getInt(_keyMaxTokens) ?? 120;

  // Defaults to TRUE: 100% Offline AI by default
  bool get isOfflineMode => _prefs.getBool(_keyIsOffline) ?? true;
  String get activeSource => _prefs.getString(_keyActiveSource) ?? 'phone'; // 'phone' | 'glasses'
  String get glassesIp => _prefs.getString(_keyGlassesIp) ?? '192.168.4.1';
  int get glassesPort => _prefs.getInt(_keyGlassesPort) ?? 80;
  bool get autoScan => _prefs.getBool(_keyAutoScan) ?? false;

  // ── Setters ───────────────────────────────────────────────────────────────
  Future<void> saveBackendIp(String ip) => _prefs.setString(_keyIp, ip);
  Future<void> saveBackendPort(int port) => _prefs.setInt(_keyPort, port);
  Future<void> saveLanguage(String lang) => _prefs.setString(_keyLanguage, lang);
  Future<void> saveMaxTokens(int tokens) => _prefs.setInt(_keyMaxTokens, tokens);
  Future<void> saveIsOfflineMode(bool offline) => _prefs.setBool(_keyIsOffline, offline);
  Future<void> saveActiveSource(String source) => _prefs.setString(_keyActiveSource, source);
  Future<void> saveGlassesIp(String ip) => _prefs.setString(_keyGlassesIp, ip);
  Future<void> saveGlassesPort(int port) => _prefs.setInt(_keyGlassesPort, port);
  Future<void> saveAutoScan(bool auto) => _prefs.setBool(_keyAutoScan, auto);
}
