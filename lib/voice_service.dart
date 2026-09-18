import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechReady = false;

  String localeId = 'ru-RU';

  Future<bool> init() async {
    _speechReady = await _speech.initialize(
      onError: (e) => print('STT error: $e'),
      onStatus: (s) => print('STT status: $s'),
    );
    await _tts.setLanguage(localeId);
    await _tts.setSpeechRate(0.48);
    return _speechReady;
  }

  bool get isListening => _speech.isListening;

  Future<void> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
  }) async {
    if (!_speechReady) {
      _speechReady = await _speech.initialize();
    }
    if (!_speechReady) return;

    await _speech.listen(
      localeId: localeId,
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
