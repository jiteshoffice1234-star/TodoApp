import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/voice_service.dart';
import '../../core/services/natural_language_parser.dart';
import '../../providers/todo_provider.dart';

class VoiceInputButton extends StatefulWidget {
  final Function(String)? onResult;

  const VoiceInputButton({super.key, this.onResult});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final service = VoiceService.instance;
    final available = await service.init();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available on this device'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    _pulseCtrl.repeat(reverse: true);

    final result = await service.listen();

    _pulseCtrl.stop();
    setState(() => _isListening = false);

    if (result != null && result.isNotEmpty) {
      final parsed = NaturalLanguageParser.parse(result);
      if (parsed.title.isNotEmpty) {
        if (!mounted) return;
        await context.read<TodoProvider>().addFromQuickAdd(parsed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added via voice: ${parsed.title}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _isListening ? null : _startListening,
      backgroundColor: _isListening
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
      child: _isListening
          ? Icon(Icons.mic, color: Colors.white)
              .animate(controller: _pulseCtrl)
              .scaleXY(
                begin: 1.0,
                end: 1.3,
                duration: 600.ms,
                curve: Curves.easeInOut,
              )
          : const Icon(Icons.mic_none),
    );
  }
}
