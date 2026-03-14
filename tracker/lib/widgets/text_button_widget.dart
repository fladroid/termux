// lib/widgets/text_button_widget.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../services/app_theme.dart';
import '../services/translation_service.dart';

class TextButtonWidget extends StatefulWidget {
  final ButtonModel button;
  final String?     savedText;
  final bool        showLabel;
  final Function(String) onSave;

  const TextButtonWidget({
    super.key,
    required this.button,
    required this.savedText,
    required this.showLabel,
    required this.onSave,
  });

  @override
  State<TextButtonWidget> createState() => _TextButtonWidgetState();
}

class _TextButtonWidgetState extends State<TextButtonWidget> {
  final _theme = AppTheme();
  final _tr    = TranslationService();
  final _ctrl  = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _openEditor() async {
    _ctrl.text = widget.savedText ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.button.getLabel(_tr.language),
          style: TextStyle(fontFamily: 'monospace', fontSize: _theme.bodySize)),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 4,
          style: TextStyle(fontFamily: 'monospace', fontSize: _theme.bodySize),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            hintText: _tr.t('text_hint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(_tr.t('warning_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ctrl.text.trim()),
            child: Text(_tr.t('range_apply'))),
        ],
      ),
    );
    if (result != null) widget.onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.savedText != null && widget.savedText!.isNotEmpty;
    final bgColor = hasText ? _theme.accent.withOpacity(0.08) : _theme.surface;
    final border  = hasText ? _theme.accent : _theme.border;

    return GestureDetector(
      onTap: _openEditor,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color:  bgColor,
          border: Border.all(color: border, width: hasText ? 1.5 : 1.0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(widget.button.symbol, style: TextStyle(
                fontSize: _theme.symbolSize * 0.65)),
              const SizedBox(width: 6),
              if (widget.showLabel)
                Expanded(child: Text(
                  widget.button.getLabel(_tr.language),
                  style: TextStyle(fontFamily: 'monospace',
                    fontSize: _theme.labelSize, color: _theme.inkFaint),
                  overflow: TextOverflow.ellipsis,
                )),
            ]),
            if (hasText) ...[
              const SizedBox(height: 4),
              Text(
                widget.savedText!,
                style: TextStyle(fontFamily: 'monospace',
                  fontSize: _theme.captionSize, color: _theme.inkMedium),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(_tr.t('text_tap_to_edit'),
                style: TextStyle(fontFamily: 'monospace',
                  fontSize: _theme.captionSize, color: _theme.inkFaint,
                  fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
