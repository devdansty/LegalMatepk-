import 'package:speech_to_text/speech_to_text.dart';

class STTService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    _isInitialized = await _speech.initialize();
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    String languageCode = "en_US",
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _speech.listen(
      localeId: languageCode,
      onResult: (result) {
        // Only send final results to avoid duplicates from partial results
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  void stopListening() {
    _speech.stop();
  }

  bool get isListening => _speech.isListening;
}