import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Barras animadas mientras [active] es true (nivel simulado / “fake” si no hay RMS real).
class WaveformBars extends StatefulWidget {
  const WaveformBars({
    super.key,
    required this.active,
    this.barCount = 10,
  });

  final bool active;
  final int barCount;

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void didUpdateWidget(WaveformBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    }
    if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.barCount,
            (i) => _Bar(
              height: 6 + (i % 3) * 2.0,
              color: AppTheme.textSecondary.withValues(alpha: 0.25),
            ),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        return SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              final phase = t + i * 0.45;
              final h = 10 + (math.sin(phase) * 0.5 + 0.5) * 38 + (i % 4) * 2.0;
              return _Bar(
                height: h.clamp(8.0, 52.0),
                color: AppTheme.accentCyan.withValues(
                  alpha: 0.55 + (i % 3) * 0.12,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 5,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentCyan.withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
