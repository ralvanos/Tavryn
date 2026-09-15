import 'package:flutter/material.dart';

/// A fasting protocol: hours fasting vs hours eating, or open-ended (flexi).
class FastSchedule {
  const FastSchedule({
    required this.id,
    required this.name,
    required this.fastMinutes,
    required this.eatMinutes,
    this.subtitle = '',
    this.preset = false,
    this.hidden = false,
  });

  final String id;
  final String name;

  /// Target fast length. `0` means Flexi (no cap).
  final int fastMinutes;

  /// Planned eating window after a completed fast. `0` means none.
  final int eatMinutes;
  final String subtitle;
  final bool preset;
  final bool hidden;

  bool get isFlexi => fastMinutes <= 0;

  String get ratioLabel {
    if (isFlexi) return 'Flexi';
    final fastH = _hoursLabel(fastMinutes);
    if (eatMinutes <= 0) return '${fastH}h';
    return '${fastH}h/${_hoursLabel(eatMinutes)}h';
  }

  /// Current protocol label for a stored fast (presets follow the latest format).
  static String displayName(String scheduleId, String storedName) {
    return presetById(scheduleId)?.ratioLabel ?? storedName;
  }

  static FastSchedule matching({
    required String id,
    required String name,
    required int goalMinutes,
    List<FastSchedule> known = const [],
  }) {
    for (final schedule in known) {
      if (schedule.id == id) return schedule;
    }
    return presetById(id) ??
        FastSchedule(
          id: id.isEmpty ? 'legacy' : id,
          name: name,
          fastMinutes: goalMinutes,
          eatMinutes: 0,
        );
  }

  static String _hoursLabel(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60}';
    final hours = minutes / 60;
    if (hours == hours.roundToDouble()) return '${hours.toInt()}';
    return hours.toStringAsFixed(1);
  }

  FastSchedule copyWith({
    String? id,
    String? name,
    int? fastMinutes,
    int? eatMinutes,
    String? subtitle,
    bool? preset,
    bool? hidden,
  }) {
    return FastSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      fastMinutes: fastMinutes ?? this.fastMinutes,
      eatMinutes: eatMinutes ?? this.eatMinutes,
      subtitle: subtitle ?? this.subtitle,
      preset: preset ?? this.preset,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fastMinutes': fastMinutes,
        'eatMinutes': eatMinutes,
        'subtitle': subtitle,
        'preset': preset,
        'hidden': hidden,
      };

  factory FastSchedule.fromJson(Map<String, dynamic> json) {
    return FastSchedule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Custom',
      fastMinutes: (json['fastMinutes'] as num?)?.toInt() ?? 0,
      eatMinutes: (json['eatMinutes'] as num?)?.toInt() ?? 0,
      subtitle: json['subtitle'] as String? ?? '',
      preset: json['preset'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
    );
  }

  static const List<FastSchedule> presets = [
    FastSchedule(
      id: '12-12',
      name: '12h/12h',
      fastMinutes: 12 * 60,
      eatMinutes: 12 * 60,
      subtitle: 'Gentle start',
      preset: true,
    ),
    FastSchedule(
      id: '14-10',
      name: '14h/10h',
      fastMinutes: 14 * 60,
      eatMinutes: 10 * 60,
      subtitle: 'Beginner',
      preset: true,
    ),
    FastSchedule(
      id: '16-8',
      name: '16h/8h',
      fastMinutes: 16 * 60,
      eatMinutes: 8 * 60,
      subtitle: 'Classic',
      preset: true,
    ),
    FastSchedule(
      id: '18-6',
      name: '18h/6h',
      fastMinutes: 18 * 60,
      eatMinutes: 6 * 60,
      subtitle: 'Strong',
      preset: true,
    ),
    FastSchedule(
      id: '20-4',
      name: '20h/4h',
      fastMinutes: 20 * 60,
      eatMinutes: 4 * 60,
      subtitle: 'Warrior',
      preset: true,
    ),
    FastSchedule(
      id: 'omad',
      name: '23h/1h',
      fastMinutes: 23 * 60,
      eatMinutes: 60,
      subtitle: 'OMAD · one meal a day',
      preset: true,
    ),
    FastSchedule(
      id: '36h',
      name: '36h/12h',
      fastMinutes: 36 * 60,
      eatMinutes: 12 * 60,
      subtitle: 'Extended',
      preset: true,
    ),
    FastSchedule(
      id: '48h',
      name: '48h/24h',
      fastMinutes: 48 * 60,
      eatMinutes: 24 * 60,
      subtitle: 'Two-day',
      preset: true,
    ),
    FastSchedule(
      id: '72h',
      name: '72h/24h',
      fastMinutes: 72 * 60,
      eatMinutes: 24 * 60,
      subtitle: 'Three-day',
      preset: true,
    ),
    FastSchedule(
      id: 'flexi',
      name: 'Flexi',
      fastMinutes: 0,
      eatMinutes: 0,
      subtitle: 'No time cap',
      preset: true,
    ),
  ];

  static const String defaultId = '16-8';

  static FastSchedule? presetById(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Visual cue for a protocol chip.
Color scheduleAccent(FastSchedule schedule) {
  if (schedule.isFlexi) return const Color(0xFF8B7CFF);
  if (schedule.fastMinutes >= 36 * 60) return const Color(0xFFE85D5D);
  if (schedule.fastMinutes >= 20 * 60) return const Color(0xFFE8A05A);
  if (schedule.fastMinutes >= 16 * 60) return const Color(0xFFE8A05A);
  return const Color(0xFF6EC8C0);
}
