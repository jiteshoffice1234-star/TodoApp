import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownEditor extends StatefulWidget {
  final TextEditingController controller;

  const MarkdownEditor({super.key, required this.controller});

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  bool _preview = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller;
  }

  void _insert(String before, String after) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final newText = text.substring(0, start) + before + selected + after + text.substring(end);
    _ctrl.text = newText;
    _ctrl.selection = TextSelection.collapsed(offset: start + before.length + selected.length + after.length);
    setState(() {});
  }

  void _insertAtCursor(String s) {
    final text = _ctrl.text;
    final pos = _ctrl.selection.start;
    _ctrl.text = text.substring(0, pos) + s + text.substring(pos);
    _ctrl.selection = TextSelection.collapsed(offset: pos + s.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(children: [
                  _tbBtn(context, 'B', () => _insert('**', '**')),
                  const SizedBox(width: 2),
                  _tbBtn(context, 'I', () => _insert('_', '_'), italic: true),
                  const SizedBox(width: 2),
                  _tbBtn(context, 'U', () => _insert('__', '__'), underline: true),
                  const SizedBox(width: 2),
                  _tbBtn(context, '</>', () => _insert('`', '`'), mono: true),
                  const SizedBox(width: 2),
                  _tbBtn(context, '\u2022', () => _insertAtCursor('\n\u2022 ')),
                  const SizedBox(width: 2),
                  _tbBtn(context, '\u2610', () => _insertAtCursor('\n- [ ] ')),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_preview ? Icons.edit : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _preview = !_preview),
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ]),
              ),
              if (_preview)
                SizedBox(
                  width: double.infinity,
                  child: Markdown(
                    data: _ctrl.text.isEmpty ? '*No description*' : _ctrl.text,
                    padding: const EdgeInsets.all(12),
                    shrinkWrap: true,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyMedium,
                      checkbox: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                TextField(
                  controller: _ctrl,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Add details... (**bold**, _italic_, - [ ] checklist)',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tbBtn(BuildContext context, String label, VoidCallback onTap,
      {bool italic = false, bool underline = false, bool mono = false}) {
    return SizedBox(
      width: 32,
      height: 32,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration: underline ? TextDecoration.underline : null,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      ),
    );
  }
}
