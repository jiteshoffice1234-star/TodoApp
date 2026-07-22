import 'package:flutter/material.dart';

class VoiceInputButton extends StatelessWidget {
  final Function(String)? onResult;

  const VoiceInputButton({super.key, this.onResult});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice input requires microphone permission. Coming soon!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: const Icon(Icons.mic_none),
    );
  }
}
