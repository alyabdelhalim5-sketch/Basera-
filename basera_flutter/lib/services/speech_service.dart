import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef OnResultCallback = void Function(String text);
typedef OnStatusCallback = void Function(bool isListening);

enum VoiceAction {
  describe,
  switchToGlasses,
  switchToPhone,
  repeatAudio,
  none,
}

/// Microphone / speech-recognition service.
/// Parses voice commands in Arabic and English for visually impaired accessibility.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _language;

  // Trigger keywords
  static const List<String> _describeTriggers = [
    'صف', 'وصف', 'ما هذا', 'اصف', 'ماذا ترى', 'انظر', 'شوف', 'احكي',
    'describe', 'what is this', 'scan', 'look', 'what do you see',
  ];

  static const List<String> _glassesTriggers = [
    'نظارة', 'النظارة', 'نظاره', 'النظاره', 'glasses', 'switch to glasses',
  ];

  static const List<String> _phoneTriggers = [
    'هاتف', 'موبايل', 'كاميرا الهاتف', 'كاميرا الموبايل', 'جوال',
    'phone', 'phone camera', 'mobile',
  ];

  static const List<String> _repeatTriggers = [
    'كرر', 'اعد', 'اعادة', 'اسمع', 'مرة اخرى',
    'repeat', 'again', 'replay',
  ];

  SpeechService({String language = 'ar'}) : _language = language;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (_) {
          _isListening = false;
        },
      );
      return _isAvailable;
    } catch (_) {
      _isAvailable = false;
      return false;
    }
  }

  void updateLanguage(String language) {
    _language = language;
  }

  String get _localeId => _language == 'ar' ? 'ar_SA' : 'en_US';

  /// Listen for one utterance and call [onResult] with the transcript.
  Future<void> listenOnce({
    required OnResultCallback onResult,
    OnStatusCallback? onStatus,
  }) async {
    if (!_isAvailable || _isListening) return;

    _isListening = true;
    onStatus?.call(true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _isListening = false;
            onStatus?.call(false);
            onResult(result.recognizedWords.toLowerCase());
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: false,
        ),
        localeId: _localeId,
      );
    } catch (_) {
      _isListening = false;
      onStatus?.call(false);
    }
  }

  Future<void> stop() async {
    await _speech.stop();
    _isListening = false;
  }

  /// Parse spoken text into an actionable command.
  VoiceAction parseCommand(String text) {
    final lower = text.toLowerCase();

    for (final kw in _glassesTriggers) {
      if (lower.contains(kw)) return VoiceAction.switchToGlasses;
    }

    for (final kw in _phoneTriggers) {
      if (lower.contains(kw)) return VoiceAction.switchToPhone;
    }

    for (final kw in _repeatTriggers) {
      if (lower.contains(kw)) return VoiceAction.repeatAudio;
    }

    for (final kw in _describeTriggers) {
      if (lower.contains(kw)) return VoiceAction.describe;
    }

    return VoiceAction.describe; // Default intent if spoken during listen
  }

  bool isTrigger(String text) {
    return parseCommand(text) != VoiceAction.none;
  }
}
