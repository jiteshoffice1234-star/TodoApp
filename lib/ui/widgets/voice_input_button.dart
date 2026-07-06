import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputButton extends StatefulWidget {
  final Function(String)? onResult;

  const VoiceInputButton({super.key, this.onResult});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _listen() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice error: $error')),
          );
        },
      );

      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            setState(() => _text = result.recognizedWords);
            if (result.finalResult) {
              widget.onResult?.call(_text);
              setState(() => _text = '');
            }
          },
          localeId: 'en_US',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _listen,
      backgroundColor: _isListening ? Colors.red : null,
      child: Icon(_isListening ? Icons.mic : Icons.mic_none),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
