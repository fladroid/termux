// lib/widgets/counter_button.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../services/app_theme.dart';
import '../services/translation_service.dart';

class CounterButton extends StatefulWidget {
  final ButtonModel button;
  final int value;
  final bool showLabel;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  const CounterButton({
    super.key,
    required this.button,
    required this.value,
    required this.showLabel,
    required this.onPlus,
    required this.onMinus,
  });

  @override
  State<CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<CounterButton> {
  final _theme = AppTheme();
  final _tr    = TranslationService();

  @override
  Widget build(BuildContext context) {
    final isActive = widget.value > 0;
    final bgColor  = isActive ? _theme.accent     : _theme.surface;
    final fgColor  = isActive ? _theme.accentText : _theme.ink;
    final subColor = isActive ? _theme.accentText.withOpacity(0.6) : _theme.inkFaint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color:  bgColor,
        border: Border.all(
          color: isActive ? _theme.accent : _theme.ink, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [

          // Simbol
          Text(widget.button.symbol, style: TextStyle(
            fontSize: _theme.symbolSize * 0.75,
            color: fgColor,
            height: 1.1,
          )),

          // Label
          if (widget.showLabel)
            Text(
              widget.button.getLabel(_tr.language),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: _theme.labelSize * 0.85,
                letterSpacing: 0.5,
                color: subColor,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: 4),

          // + broj −
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlBtn('−', widget.onMinus, isActive),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${widget.value}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: _theme.counterSize * 0.75,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
                  ),
                ),
                _controlBtn('+', widget.onPlus, isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn(String label, VoidCallback onTap, bool isActive) {
    final btnSize = (_theme.counterSize * 0.85).clamp(20.0, 36.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: btnSize, height: btnSize,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.15)
              : _theme.background,
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.3)
                : _theme.border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? _theme.accentText : _theme.inkMedium,
          )),
        ),
      ),
    );
  }
}
