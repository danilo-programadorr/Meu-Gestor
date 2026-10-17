import 'dart:math' as math;

import 'package:flutter/material.dart';

class StartupGridLoader extends StatefulWidget {
  const StartupGridLoader({super.key});

  @override
  State<StartupGridLoader> createState() => _StartupGridLoaderState();
}

// Reproduz a onda radial do exemplo anime.js em um único canvas Flutter.
class _StartupGridLoaderState extends State<StartupGridLoader>
    with SingleTickerProviderStateMixin {
  static const Duration _cycleDuration = Duration(milliseconds: 2800);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycleDuration,
  );

  bool? _animationsDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        label: 'Carregando',
        child: SizedBox.square(
          dimension: 176,
          child: CustomPaint(
            key: const ValueKey<String>('startup-dot-wave'),
            painter: _RadialDotWavePainter(
              progress: _controller,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialDotWavePainter extends CustomPainter {
  _RadialDotWavePainter({
    required Animation<double> progress,
    required this.color,
  }) : _progress = progress,
       super(repaint: progress);

  static const int _gridSize = 13;
  static const double _minimumScale = 0.75;
  static const double _maximumScale = 1.1;
  static const double _waveDuration = 0.34;
  static const double _maximumDelay = 0.58;

  final Animation<double> _progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    final double spacing = side / (_gridSize + 1);
    final double baseRadius = math.max(1.45, spacing * 0.18);
    const double center = (_gridSize - 1) / 2;
    final double maximumDistance = math.sqrt(2 * center * center);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int row = 0; row < _gridSize; row += 1) {
      for (int column = 0; column < _gridSize; column += 1) {
        final double dx = column - center;
        final double dy = row - center;
        final double distance = math.sqrt((dx * dx) + (dy * dy));
        final double delay = (distance / maximumDistance) * _maximumDelay;
        double localProgress = _progress.value - delay;
        if (localProgress < 0) localProgress += 1;

        double pulse = 0;
        if (localProgress <= _waveDuration) {
          final double normalized = localProgress / _waveDuration;
          final double eased = _inOutQuad(normalized);
          pulse = math.sin(math.pi * eased);
        }
        final double scale =
            _minimumScale + ((_maximumScale - _minimumScale) * pulse);
        paint.color = color.withValues(alpha: 0.28 + (0.72 * pulse));
        canvas.drawCircle(
          Offset(spacing * (column + 1), spacing * (row + 1)),
          baseRadius * scale,
          paint,
        );
      }
    }
  }

  static double _inOutQuad(double value) => value < 0.5
      ? 2 * value * value
      : 1 - (math.pow(-2 * value + 2, 2).toDouble() / 2);

  @override
  bool shouldRepaint(covariant _RadialDotWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
