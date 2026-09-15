import 'package:flutter/material.dart';

/// Guidance-only fasting timeline. Not medical advice.
class FastingStage {
  const FastingStage({
    required this.id,
    required this.timeLabel,
    required this.minHours,
    required this.maxHours,
    required this.title,
    required this.summary,
    required this.color,
    this.reachedFromHours,
  });

  final String id;

  /// Display label such as `12 Hours` or `3-5 Days`.
  final String timeLabel;
  final double minHours;

  /// Exclusive upper bound. `null` means unbounded.
  final double? maxHours;
  final String title;
  final String summary;
  final Color color;

  /// When the timeline node counts as reached. Defaults to [minHours].
  final double? reachedFromHours;

  bool containsHours(double hours) {
    if (hours < minHours) return false;
    if (maxHours == null) return true;
    return hours < maxHours!;
  }

  bool reached(double hours) => hours >= (reachedFromHours ?? minHours);

  /// 0–1 progress through this stage, used for the live timeline rail.
  double progressThrough(double hours) {
    if (hours < minHours) return 0;
    final cap = maxHours;
    if (cap == null) return 1;
    final span = cap - minHours;
    if (span <= 0) return hours >= minHours ? 1 : 0;
    return ((hours - minHours) / span).clamp(0.0, 1.0);
  }
}

class FastingStages {
  FastingStages._();

  static const List<FastingStage> all = [
    FastingStage(
      id: 'digestive',
      timeLabel: '12 Hours',
      minHours: 12,
      maxHours: 14,
      title: 'Digestive Begins',
      summary:
          'Your body shifts from digesting food to restoring your gut and liver.',
      color: Color(0xFF6EC8C0),
    ),
    FastingStage(
      id: 'insulin',
      timeLabel: '14 Hours',
      minHours: 14,
      maxHours: 16,
      title: 'Blood Sugar & Insulin Drop',
      summary:
          'Insulin levels fall, blood sugar stabilizes, and fat burning starts to kick in.',
      color: Color(0xFF8B7CFF),
    ),
    FastingStage(
      id: 'ketones',
      timeLabel: '16-18 Hours',
      minHours: 16,
      maxHours: 18,
      title: 'Ketones Rise & Brain Boosts',
      summary:
          'Ketones begin to rise and BDNF increases, supporting mental clarity and focus.',
      color: Color(0xFFE8A05A),
    ),
    FastingStage(
      id: 'inflammation',
      timeLabel: '18-24 Hours',
      minHours: 18,
      maxHours: 24,
      title: 'Inflammation Drops',
      summary:
          'Inflammation decreases, autophagy begins, and your cells start deep repair.',
      color: Color(0xFFE8A05A),
    ),
    FastingStage(
      id: 'hgh',
      timeLabel: '24 Hours',
      minHours: 24,
      maxHours: 26,
      title: 'Growth Hormone Surge',
      summary:
          'Human Growth Hormone rises significantly to repair tissues and build lean mass.',
      color: Color(0xFFC47A32),
    ),
    FastingStage(
      id: 'renewal',
      timeLabel: '24-36 Hours',
      minHours: 26,
      maxHours: 36,
      reachedFromHours: 24,
      title: 'Deeper Cellular Renewal',
      summary:
          'Gut microbiome balances and intestinal stem cells begin to increase.',
      color: Color(0xFFC47A32),
    ),
    FastingStage(
      id: 'autophagy',
      timeLabel: '36-48 Hours',
      minHours: 36,
      maxHours: 48,
      title: 'Autophagy Intensifies',
      summary:
          'Higher level of autophagy, immune system rejuvenation, and cellular cleanup continue.',
      color: Color(0xFFE85D5D),
    ),
    FastingStage(
      id: 'maximum',
      timeLabel: '48-72 Hours',
      minHours: 48,
      maxHours: 72,
      title: 'Maximum Renewal',
      summary:
          'Autophagy and stem cell production peak for deep healing and regeneration.',
      color: Color(0xFFE85D5D),
    ),
    FastingStage(
      id: 'peak',
      timeLabel: '3-5 Days',
      minHours: 72,
      maxHours: null,
      title: 'Peak Rejuvenation',
      summary:
          'Autophagy and stem cell increase stay maximized for full-body renewal.',
      color: Color(0xFFE85D5D),
    ),
  ];

  static FastingStage? forElapsed(Duration elapsed) {
    final hours = elapsed.inSeconds / 3600;
    for (final stage in all) {
      if (stage.containsHours(hours)) return stage;
    }
    return null;
  }

  static List<double> notifyBoundaries = const [
    12,
    14,
    16,
    18,
    24,
    36,
    48,
    72,
  ];
}
