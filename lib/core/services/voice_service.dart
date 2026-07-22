import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  static final VoiceService instance = VoiceService._();
  VoiceService._();

  stt.SpeechToText? _speech;
  bool _initialized = false;
  bool _isListening = false;

  bool get isAvailable => _initialized;
  bool get isListening => _isListening;

  Future<bool> init() async {
    if (_initialized) return true;
    _speech = stt.SpeechToText();
    _initialized = await _speech!.initialize();
    return _initialized;
  }

  Future<String?> listen() async {
    if (_speech == null) return null;
    if (_isListening) return null;

    String? result;
    _isListening = true;

    await _speech!.listen(
      onResult: (val) {
        result = val.recognizedWords;
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
    );

    while (_isListening && _speech!.isListening) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isListening = false;
    return result;
  }

  void stop() {
    _speech?.stop();
    _isListening = false;
  }
}
