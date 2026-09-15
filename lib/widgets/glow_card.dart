import 'package:flutter/material.dart';

import '../theme.dart';

/// Soft dusk card with a faint top highlight. More glow than classic neumorphism.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent,
    this.glow = false,
    this.expand = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final bool glow;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? TavrynColors.ember;
    return Container(
      width: double.infinity,
      height: expand ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        color: TavrynColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: glow
              ? tint.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          if (glow)
            BoxShadow(
              color: tint.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.035),
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: child,
    );
  }
}
