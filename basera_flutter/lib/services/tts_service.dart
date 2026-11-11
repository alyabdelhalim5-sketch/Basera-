import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service using the device's built-in TTS engine.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  String _language;

  TtsService({String language = 'ar'}) : _language = language;

  Future<void> init() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    await _setLanguage(_language);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
  }

  Future<void> _setLanguage(String lang) async {
    // Try exact locale, then fallback to language code
    final localeMap = {
      'ar': 'ar-SA',
      'en': 'en-US',
    };
    final locale = localeMap[lang] ?? 'en-US';
    await _tts.setLanguage(locale);
  }

  void updateLanguage(String language) {
    _language = language;
    _setLanguage(language);
  }

  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await stop(); // stop any ongoing speech
    await _setLanguage(_language);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
