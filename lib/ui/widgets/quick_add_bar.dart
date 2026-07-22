import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/natural_language_parser.dart';
import '../../providers/todo_provider.dart';

class QuickAddBar extends StatefulWidget {
  const QuickAddBar({super.key});

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> with SingleTickerProviderStateMixin {
  late TextEditingController _ctrl;
  late AnimationController _animCtrl;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final parsed = NaturalLanguageParser.parse(text);
    if (parsed.title.isEmpty) return;

    final provider = context.read<TodoProvider>();
    provider.addFromQuickAdd(parsed);

    _ctrl.clear();
    _collapse();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added: ${parsed.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _expand() {
    setState(() => _isExpanded = true);
    _animCtrl.forward();
  }

  void _collapse() {
    _animCtrl.reverse();
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Animate(
        controller: _animCtrl,
        effects: [
          ShakeEffect(duration: 300.ms, hz: 1),
        ],
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isExpanded
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: _isExpanded ? _buildExpanded(theme) : _buildCollapsed(theme),
        ),
      ),
    );
  }

  Widget _buildCollapsed(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _expand,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.bolt, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Quick add — e.g. "Buy milk tomorrow 3pm high #groceries"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.bolt, size: 20),
            onPressed: null,
            color: theme.colorScheme.primary,
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. "Buy milk tomorrow 3pm high #groceries"',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: theme.textTheme.bodyMedium,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            onPressed: _submit,
            color: theme.colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _collapse,
          ),
        ],
      ),
    );
  }
}
