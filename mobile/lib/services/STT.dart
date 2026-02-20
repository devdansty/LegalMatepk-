import 'package:speech_to_text/speech_to_text.dart';

class STTService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    _isInitialized = await _speech.initialize();
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    String languageCode = "en_US",
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _speech.listen(
      localeId: languageCode,
      onResult: (result) {
        onResult(result.recognizedWords);
      },
    );
  }

  void stopListening() {
    _speech.stop();
  }

  bool get isListening => _speech.isListening;
}