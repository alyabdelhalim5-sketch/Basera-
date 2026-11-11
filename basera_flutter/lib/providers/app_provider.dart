import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/settings_service.dart';
import '../services/glasses_service.dart';
import '../models/ai_response.dart';
import '../widgets/status_bar.dart';

/// Central app state — connects all services and notifies the UI.
class AppProvider extends ChangeNotifier {
  final AiService aiService;
  final TtsService ttsService;
  final SpeechService speechService;
  final SettingsService settingsService;
  final GlassesService glassesService;

  AppState _state = AppState.idle;
  String _description = '';
  String _statusDetail = '';
  bool _backendConnected = false;
  bool _isListening = false;
  String _activeSource = 'phone'; // 'phone' | 'glasses'

  AppProvider({
    required this.aiService,
    required this.ttsService,
    required this.speechService,
    required this.settingsService,
    required this.glassesService,
  }) {
    _activeSource = settingsService.activeSource;
  }

  AppState get state => _state;
  String get description => _description;
  String get statusDetail => _statusDetail;
  bool get backendConnected => _backendConnected;
  bool get isListening => _isListening;
  String get language => settingsService.language;
  String get activeSource => _activeSource;
  bool get isOfflineMode => settingsService.isOfflineMode;

  Future<void> init() async {
    await ttsService.init();
    await speechService.init();
    await checkBackend();
  }

  Future<void> checkBackend() async {
    if (isOfflineMode) {
      _backendConnected = true;
      _state = AppState.idle;
    } else {
      final ok = await aiService.checkHealth();
      _backendConnected = ok;
      _state = ok ? AppState.idle : AppState.noConnection;
    }
    notifyListeners();
  }

  // ── Source Switching ──────────────────────────────────────────────────────
  Future<void> setSource(String source) async {
    _activeSource = source;
    await settingsService.saveActiveSource(source);
    notifyListeners();

    final msg = source == 'glasses'
        ? (language == 'ar' ? 'تم التبديل إلى نظارة بصيرة' : 'Switched to Basera glasses')
        : (language == 'ar' ? 'تم التبديل إلى كاميرا الهاتف' : 'Switched to phone camera');
    await ttsService.speak(msg);
  }

  void toggleSource() {
    setSource(_activeSource == 'phone' ? 'glasses' : 'phone');
  }

  // ── Capture & Describe ────────────────────────────────────────────────────
  Future<void> describeFile(File imageFile, {bool force = false}) async {
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
      await ttsService.speak(
        language == 'ar' ? 'تعذر تحليل المشهد' : 'Failed to analyze scene',
      );
    }
  }

  Future<void> captureFromGlasses({bool force = false}) async {
    if (_state == AppState.processing || _state == AppState.capturing) return;

    _state = AppState.capturing;
    _statusDetail = language == 'ar' ? 'جاري التقاط صورة من النظارة…' : 'Capturing from glasses…';
    notifyListeners();

    try {
      final file = await glassesService.captureFrame();
      await describeFile(file, force: force);
    } catch (e) {
      _state = AppState.error;
      _statusDetail = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      await ttsService.speak(
        language == 'ar'
            ? 'تعذر الاتصال بالنظارة. تأكد من تشغيلها واتصال الهاتف بها'
            : 'Cannot reach glasses. Please verify Wi-Fi connection',
      );
    }
  }

  // ── Voice Commands ────────────────────────────────────────────────────────
  Future<void> handleVoiceCommand(String text, {required VoidCallback onTriggerCamera}) async {
    final action = speechService.parseCommand(text);

    switch (action) {
      case VoiceAction.switchToGlasses:
        await setSource('glasses');
        break;
      case VoiceAction.switchToPhone:
        await setSource('phone');
        break;
      case VoiceAction.repeatAudio:
        if (_description.isNotEmpty) {
          await ttsService.speak(_description);
        }
        break;
      case VoiceAction.describe:
        if (_activeSource == 'glasses') {
          await captureFromGlasses();
        } else {
          onTriggerCamera();
        }
        break;
      case VoiceAction.none:
        break;
    }
  }

  Future<void> toggleVoiceListen({required VoidCallback onTriggerCamera}) async {
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
        handleVoiceCommand(text, onTriggerCamera: onTriggerCamera);
      },
      onStatus: (listening) {
        _isListening = listening;
        notifyListeners();
      },
    );
  }

  Future<void> repeatDescription() async {
    if (_description.isNotEmpty) {
      await ttsService.speak(_description);
    }
  }

  Future<void> resetScene() async {
    await aiService.resetScene();
    _description = '';
    _statusDetail = language == 'ar' ? 'تم تصفير الذاكرة' : 'Scene reset';
    notifyListeners();
  }
}
