// lib/widgets/symbol_button.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../services/app_theme.dart';

class SymbolButton extends StatefulWidget {
  final ButtonModel button;
  final String language;
  final bool showLabel;
  final int todayCount;
  final bool isActive;
  final VoidCallback onTap;

  const SymbolButton({
    super.key,
    required this.button,
    required this.language,
    required this.showLabel,
    required this.todayCount,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<SymbolButton> createState() => _SymbolButtonState();
}

class _SymbolButtonState extends State<SymbolButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  final _theme = AppTheme();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? _theme.accent : _theme.surface,
            border: Border.all(
              color: isActive ? _theme.accent : _theme.ink,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              if (widget.todayCount > 0)
                Positioned(
                  top: 6, right: 8,
                  child: Text(
                    '${widget.todayCount}×',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: _theme.badgeSize,
                      color: isActive
                          ? Colors.white.withOpacity(0.5)
                          : _theme.inkFaint,
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.button.symbol, style: TextStyle(
                      fontSize: _theme.symbolSize,
                      color: isActive ? _theme.accentText : _theme.ink,
                    )),
                    if (widget.showLabel) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.button.getLabel(widget.language),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: _theme.labelSize,
                          letterSpacing: 0.8,
                          color: isActive
                              ? Colors.white.withOpacity(0.6)
                              : _theme.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
