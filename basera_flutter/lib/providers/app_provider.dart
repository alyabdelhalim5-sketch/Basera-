import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/settings_service.dart';
import '../models/ai_response.dart';
import '../widgets/status_bar.dart';

/// Central app state — connects all services and notifies the UI.
class AppProvider extends ChangeNotifier {
  final AiService aiService;
  final TtsService ttsService;
  final SpeechService speechService;
  final SettingsService settingsService;

  AppState _state = AppState.idle;
  String _description = '';
  String _statusDetail = '';
  bool _backendConnected = false;
  bool _isListening = false;

  AppProvider({
    required this.aiService,
    required this.ttsService,
    required this.speechService,
    required this.settingsService,
  });

  AppState get state => _state;
  String get description => _description;
  String get statusDetail => _statusDetail;
  bool get backendConnected => _backendConnected;
  bool get isListening => _isListening;
  String get language => settingsService.language;

  Future<void> init() async {
    await ttsService.init();
    await speechService.init();
    await checkBackend();
  }

  Future<void> checkBackend() async {
    final ok = await aiService.checkHealth();
    _backendConnected = ok;
    _state = ok ? AppState.idle : AppState.noConnection;
    notifyListeners();
  }

  Future<void> captureAndDescribe(File imageFile, {bool force = false}) async {
    if (_state == AppState.processing || _state == AppState.capturing) return;

    _state = AppState.processing;
    _statusDetail = '';
    notifyListeners();

    try {
      final AiResponse resp = await aiService.describeImage(imageFile, force: force);

      if (resp.skipped) {
        _state = AppState.idle;
        _statusDetail = language == 'ar' ? 'المشهد لم يتغير' : 'Scene unchanged';
        notifyListeners();
        return;
      }

      _description = resp.description;
      _statusDetail = resp.latencySeconds;
      _state = AppState.speaking;
      notifyListeners();

      await ttsService.speak(resp.description);
      _state = AppState.idle;
      notifyListeners();
    } catch (e) {
      _state = AppState.error;
      _statusDetail = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> toggleVoiceListen() async {
    if (_isListening) {
      await speechService.stop();
      _isListening = false;
      notifyListeners();
      return;
    }
    _isListening = true;
    notifyListeners();

    await speechService.listenOnce(
      onResult: (text) {
        _isListening = false;
        notifyListeners();
        // Voice trigger handling is done by home_screen via callback
      },
      onStatus: (listening) {
        _isListening = listening;
        notifyListeners();
      },
    );
  }

  Future<void> stopSpeaking() async {
    await ttsService.stop();
    _state = AppState.idle;
    notifyListeners();
  }

  void updateSettings() {
    aiService.updateSettings(
      backendIp: settingsService.backendIp,
      port: settingsService.backendPort,
      language: settingsService.language,
      maxTokens: settingsService.maxTokens,
    );
    ttsService.updateLanguage(settingsService.language);
    speechService.updateLanguage(settingsService.language);
    notifyListeners();
  }
}
