// lib/widgets/symbol_button.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';

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
            color: isActive ? const Color(0xFF2D5A27) : const Color(0xFFFAF7F2),
            border: Border.all(
              color: isActive ? const Color(0xFF2D5A27) : const Color(0xFF1A1A1A),
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
                      fontSize: 10,
                      color: isActive
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFFC8C0B4),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.button.symbol,
                      style: TextStyle(
                        fontSize: 32,
                        color: isActive ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if (widget.showLabel) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.button.getLabel(widget.language),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          letterSpacing: 0.8,
                          color: isActive
                              ? Colors.white.withOpacity(0.6)
                              : const Color(0xFFC8C0B4),
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
