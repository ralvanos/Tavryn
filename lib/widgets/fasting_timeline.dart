import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fasting_math.dart';
import '../models/fasting_stage.dart';
import '../theme.dart';
import 'glow_card.dart';

Future<void> showFastingTimelineSheet(
  BuildContext context, {
  DateTime? startAt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TavrynColors.inkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return FastingTimelineSheet(startAt: startAt);
    },
  );
}

class FastingTimelineSheet extends StatefulWidget {
  const FastingTimelineSheet({super.key, this.startAt});

  final DateTime? startAt;

  @override
  State<FastingTimelineSheet> createState() => _FastingTimelineSheetState();
}

class _FastingTimelineSheetState extends State<FastingTimelineSheet> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.startAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startAt;
    final elapsed = start == null ? Duration.zero : _now.difference(start);
    final fasting = start != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.48,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            24,
            10,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            FastingTimeline(
              elapsed: elapsed.isNegative ? Duration.zero : elapsed,
              active: fasting,
            ),
          ],
        );
      },
    );
  }
}

/// Vertical fasting timeline with a live ember beacon on the current stage.
class FastingTimeline extends StatelessWidget {
  const FastingTimeline({
    super.key,
    this.elapsed = Duration.zero,
    this.active = false,
    this.live,
  });

  final Duration elapsed;

  /// Highlight the stage reached at [elapsed].
  final bool active;

  /// When false, copy reads as a past result ("Reached") instead of "You are here".
  final bool? live;

  @override
  Widget build(BuildContext context) {
    final hours = elapsed.inSeconds / 3600;
    final isLive = live ?? active;
    final caption = !active
        ? 'Guidance only — not medical advice.'
        : isLive
            ? 'You are here · ${FastingMath.formatDuration(elapsed)}'
            : 'Reached · ${FastingMath.formatDuration(elapsed)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fasting timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: TextStyle(
            color: active
                ? TavrynColors.ember
                : Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < FastingStages.all.length; i++)
          _TimelineRow(
            stage: FastingStages.all[i],
            isLast: i == FastingStages.all.length - 1,
            hours: hours,
            tracking: active,
            live: isLive,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stage,
    required this.isLast,
    required this.hours,
    required this.tracking,
    required this.live,
  });

  final FastingStage stage;
  final bool isLast;
  final double hours;
  final bool tracking;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final current = tracking && stage.containsHours(hours);
    final reached = tracking && stage.reached(hours);
    final railFill = current
        ? stage.progressThrough(hours)
        : reached
            ? 1.0
            : 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                _BeaconDot(
                  color: stage.color,
                  current: current,
                  reached: reached,
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                width: 3,
                                height: constraints.maxHeight,
                                margin: const EdgeInsets.only(left: 16.5),
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              Container(
                                width: 3,
                                height: constraints.maxHeight * railFill,
                                margin: const EdgeInsets.only(left: 16.5),
                                decoration: BoxDecoration(
                                  color: stage.color.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: GlowCard(
                padding: const EdgeInsets.all(14),
                accent: stage.color,
                glow: current,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stage.timeLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: current
                                ? stage.color
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        if (current) ...[
                          const Spacer(),
                          _HereChip(color: stage.color, live: live),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: current
                            ? TavrynColors.onInk
                            : Colors.white
                                .withValues(alpha: reached ? 0.9 : 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stage.summary,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(
                          alpha: current ? 0.78 : 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HereChip extends StatelessWidget {
  const _HereChip({required this.color, required this.live});

  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        live ? 'YOU ARE HERE' : 'REACHED',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _BeaconDot extends StatefulWidget {
  const _BeaconDot({
    required this.color,
    required this.current,
    required this.reached,
  });

  final Color color;
  final bool current;
  final bool reached;

  @override
  State<_BeaconDot> createState() => _BeaconDotState();
}

class _BeaconDotState extends State<_BeaconDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _BeaconDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) _sync();
  }

  void _sync() {
    if (widget.current) {
      _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core =
        widget.current || widget.reached ? widget.color : Colors.transparent;
    final border = widget.current || widget.reached
        ? widget.color
        : Colors.white.withValues(alpha: 0.22);

    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = widget.current ? _pulse.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.current) ...[
                _ring(t),
                _ring((t + 0.45) % 1.0),
              ],
              child!,
            ],
          );
        },
        child: Container(
          width: widget.current ? 14 : 11,
          height: widget.current ? 14 : 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: core,
            border: Border.all(color: border, width: 2),
            boxShadow: widget.current
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.7),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _ring(double t) {
    return IgnorePointer(
      child: Container(
        width: 12 + (24 * t),
        height: 12 + (24 * t),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withValues(alpha: (1 - t) * 0.55),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
