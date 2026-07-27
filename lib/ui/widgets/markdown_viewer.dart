import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownViewer extends StatelessWidget {
  final String data;
  final double fontSize;

  const MarkdownViewer({
    super.key,
    required this.data,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Markdown(
      data: data,
      shrinkWrap: true,
      selectable: true,
      padding: EdgeInsets.zero,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodySmall?.copyWith(fontSize: fontSize),
        listBullet: theme.textTheme.bodySmall?.copyWith(fontSize: fontSize),
        code: theme.textTheme.bodySmall?.copyWith(
          fontSize: fontSize - 1,
          fontFamily: 'monospace',
          color: theme.colorScheme.primary,
        ),
        checkbox: theme.textTheme.bodySmall?.copyWith(fontSize: fontSize),
      ),
    );
  }
}
