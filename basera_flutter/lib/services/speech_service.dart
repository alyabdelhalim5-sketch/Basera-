import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef OnResultCallback = void Function(String text);
typedef OnStatusCallback = void Function(bool isListening);

/// Microphone / speech-recognition service.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _language;

  // Trigger keywords — when user says these we capture + describe
  static const List<String> _arabicTriggers = ['صف', 'وصف', 'ما هذا', 'اصف'];
  static const List<String> _englishTriggers = ['describe', 'what is this', 'scan'];

  SpeechService({String language = 'ar'}) : _language = language;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  Future<bool> init() async {
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

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          onStatus?.call(false);
          onResult(result.recognizedWords.toLowerCase());
        }
      },
      localeId: _localeId,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
    );
  }

  /// Returns true if [text] contains any trigger keyword.
  bool isTrigger(String text) {
    final triggers = _language == 'ar' ? _arabicTriggers : _englishTriggers;
    return triggers.any((kw) => text.contains(kw));
  }

  Future<void> stop() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }
}
