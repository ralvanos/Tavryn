import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class FastRing extends StatefulWidget {
  const FastRing({
    super.key,
    required this.progress,
    required this.child,
    this.accent = TavrynColors.ember,
    this.glow = false,
    this.size = 280,
  });

  final double progress;
  final Widget child;
  final Color accent;
  final bool glow;
  final double size;

  @override
  State<FastRing> createState() => _FastRingState();
}

class _FastRingState extends State<FastRing> with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _sheen = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant FastRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glow != widget.glow) _syncMotion();
  }

  void _syncMotion() {
    if (widget.glow) {
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
      if (!_sheen.isAnimating) _sheen.repeat();
    } else {
      _breathe
        ..stop()
        ..value = 0;
      _sheen
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return AnimatedBuilder(
          animation: Listenable.merge([_breathe, _sheen]),
          builder: (context, _) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  accent: widget.accent,
                  glow: widget.glow,
                  breathe: _breathe.value,
                  sheen: _sheen.value,
                ),
                child: Center(child: widget.child),
              ),
            );
          },
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.accent,
    required this.glow,
    required this.breathe,
    required this.sheen,
  });

  final double progress;
  final Color accent;
  final bool glow;
  final double breathe;
  final double sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 22;
    final stroke = size.shortestSide < 280 ? 12.0 : 16.0;

    if (glow) {
      final bloom = Paint()
        ..color = accent.withValues(alpha: 0.14 + breathe * 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + breathe * 14);
      canvas.drawCircle(center, radius + 10 + breathe * 8, bloom);

      final pulse = Paint()
        ..color = accent.withValues(alpha: (1 - breathe) * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(center, radius + 14 + breathe * 12, pulse);
    }

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final tickInset = stroke + 10;
    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + (i / 12) * math.pi * 2;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - tickInset),
        center.dy + math.sin(angle) * (radius - tickInset),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - tickInset + 8),
        center.dy + math.sin(angle) * (radius - tickInset + 8),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = math.pi * 2 * progress;
    final shader = SweepGradient(
      transform:
          GradientRotation(-math.pi / 2 + (glow ? sheen * math.pi * 2 : 0)),
      colors: [
        accent.withValues(alpha: 0.45 + breathe * 0.15),
        accent,
        Color.lerp(accent, Colors.white, 0.38)!,
        accent.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    ).createShader(rect);

    final arc = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.glow != glow ||
        oldDelegate.breathe != breathe ||
        oldDelegate.sheen != sheen;
  }
}
