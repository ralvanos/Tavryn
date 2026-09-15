import 'fast_record.dart';
import 'fasting_stage.dart';

class WeekBucket {
  const WeekBucket({required this.weekStart, required this.minutes});

  final DateTime weekStart;
  final int minutes;

  double get hours => minutes / 60.0;
}

class PeriodStats {
  const PeriodStats({
    required this.minutes,
    required this.daysFasted,
    required this.sessions,
  });

  final int minutes;
  final int daysFasted;
  final int sessions;

  double get hours => minutes / 60.0;
}

class FastingStats {
  const FastingStats({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.longestFastMinutes,
    required this.totalFastMinutes,
    required this.completedCount,
    required this.endedCount,
    required this.sessionCount,
    required this.daysFasted,
    required this.avgCompletedMinutes,
    required this.weeklyHours,
    required this.hoursByDay,
    required this.topStageId,
    required this.week,
    required this.month,
    required this.year,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final int longestFastMinutes;
  final int totalFastMinutes;
  final int completedCount;
  final int endedCount;
  final int sessionCount;
  final int daysFasted;
  final double avgCompletedMinutes;
  final List<WeekBucket> weeklyHours;
  final Map<DateTime, double> hoursByDay;
  final String? topStageId;
  final PeriodStats week;
  final PeriodStats month;
  final PeriodStats year;

  double get completionRate =>
      endedCount == 0 ? 0 : completedCount / endedCount;

  double get totalHours => totalFastMinutes / 60.0;
  double get longestHours => longestFastMinutes / 60.0;
  double get avgCompletedHours => avgCompletedMinutes / 60.0;
}

class FastingMath {
  FastingMath._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime mondayOf(DateTime d) {
    final day = dateOnly(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static double progress({
    required int goalMinutes,
    required Duration elapsed,
  }) {
    if (goalMinutes <= 0) {
      final day = const Duration(hours: 24).inSeconds;
      if (day <= 0) return 0;
      return (elapsed.inSeconds % day) / day;
    }
    if (elapsed.inSeconds <= 0) return 0;
    final goal = goalMinutes * 60;
    final p = elapsed.inSeconds / goal;
    return p.clamp(0.0, 1.0);
  }

  static bool metGoal({
    required int goalMinutes,
    required Duration elapsed,
  }) {
    if (elapsed.isNegative) return false;
    if (goalMinutes <= 0) return elapsed.inMinutes >= 1;
    return elapsed.inMinutes >= goalMinutes;
  }

  static String formatDuration(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  /// 24-hour clock, e.g. `19:05`.
  static String formatClock24(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Subtitle under the eating-window countdown. Clock time only — not a second timer.
  static String nextFastAtLabel(DateTime until, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final time = formatClock24(until);
    final untilDay = dateOnly(until);
    final today = dateOnly(clock);
    if (untilDay == today) return 'Next fast at $time';
    if (untilDay == today.add(const Duration(days: 1))) {
      return 'Next fast at $time tomorrow';
    }
    return 'Next fast at $time';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Quiet clock under the live remaining line, e.g. `Ends at 09:04`.
  static String endsAtLabel(
    DateTime at, {
    DateTime? now,
    bool overtime = false,
  }) {
    final clock = now ?? DateTime.now();
    final time = formatClock24(at);
    final atDay = dateOnly(at);
    final today = dateOnly(clock);
    final verb = overtime ? 'Goal' : 'Ends';
    if (atDay == today) return '$verb at $time';
    if (atDay == today.add(const Duration(days: 1))) {
      return '$verb tomorrow at $time';
    }
    return '$verb ${_months[at.month - 1]} ${at.day} at $time';
  }

  static String formatHoursCompact(double hours) {
    if (hours < 1) {
      final mins = (hours * 60).round();
      return '${mins}m';
    }
    if (hours < 10) return '${hours.toStringAsFixed(1)}h';
    return '${hours.round()}h';
  }

  static Set<DateTime> daysCoveredByGoalFasts(
    List<FastRecord> records, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final days = <DateTime>{};
    for (final record in records) {
      if (!record.metGoal(clock)) continue;
      final end = record.endAt ?? clock;
      var cursor = dateOnly(record.startAt);
      final last = dateOnly(end);
      while (!cursor.isAfter(last)) {
        days.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return days;
  }

  static int streakFrom(
    Set<DateTime> days, {
    required DateTime origin,
  }) {
    var cursor = dateOnly(origin);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (!days.contains(cursor)) return 0;
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static int longestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap == 1) {
        run++;
        if (run > best) best = run;
      } else if (gap > 1) {
        run = 1;
      }
    }
    return best;
  }

  static FastingStats compute(
    List<FastRecord> records, {
    DateTime? now,
    int weekCount = 8,
    int heatmapWeeks = 12,
  }) {
    final clock = now ?? DateTime.now();
    final ended = records.where((r) => r.endAt != null).toList();
    final completed = ended.where((r) => r.metGoal(clock)).toList();

    var longest = 0;
    var total = 0;
    var completedMinutes = 0;
    final stageCounts = <String, int>{};

    for (final record in records) {
      final mins = record.elapsed(clock).inMinutes;
      if (mins > longest) longest = mins;
      total += mins;
      if (record.endAt != null && record.metGoal(clock)) {
        completedMinutes += mins;
        final stage = FastingStages.forElapsed(record.elapsed(clock));
        if (stage != null) {
          stageCounts[stage.id] = (stageCounts[stage.id] ?? 0) + 1;
        }
      }
    }

    final covered = daysCoveredByGoalFasts(records, now: clock);
    final currentStreak = streakFrom(covered, origin: dateOnly(clock));
    final longStreak = longestStreak(covered);

    String? topStage;
    var topCount = 0;
    stageCounts.forEach((id, count) {
      if (count > topCount) {
        topCount = count;
        topStage = id;
      }
    });

    final weekly = <WeekBucket>[];
    var week = mondayOf(clock).subtract(Duration(days: 7 * (weekCount - 1)));
    for (var i = 0; i < weekCount; i++) {
      final start = week;
      final end = start.add(const Duration(days: 7));
      var minutes = 0;
      for (final record in records) {
        minutes += _overlapMinutes(record, start, end, clock);
      }
      weekly.add(WeekBucket(weekStart: start, minutes: minutes));
      week = week.add(const Duration(days: 7));
    }

    final hoursByDay = <DateTime, double>{};
    final heatmapStart =
        mondayOf(clock).subtract(Duration(days: 7 * (heatmapWeeks - 1)));
    final heatmapEnd = dateOnly(clock);
    var day = heatmapStart;
    while (!day.isAfter(heatmapEnd)) {
      final next = day.add(const Duration(days: 1));
      var minutes = 0;
      for (final record in records) {
        minutes += _overlapMinutes(record, day, next, clock);
      }
      hoursByDay[day] = minutes / 60.0;
      day = next;
    }

    final avg = completed.isEmpty ? 0.0 : completedMinutes / completed.length;

    final daysFasted = _daysWithFasting(records, now: clock).length;
    final weekStart = mondayOf(clock);
    final monthStart = DateTime(clock.year, clock.month);
    final yearStart = DateTime(clock.year);

    return FastingStats(
      currentStreakDays: currentStreak,
      longestStreakDays: longStreak,
      longestFastMinutes: longest,
      totalFastMinutes: total,
      completedCount: completed.length,
      endedCount: ended.length,
      sessionCount: records.length,
      daysFasted: daysFasted,
      avgCompletedMinutes: avg,
      weeklyHours: weekly,
      hoursByDay: hoursByDay,
      topStageId: topStage,
      week: _periodStats(records, weekStart, clock),
      month: _periodStats(records, monthStart, clock),
      year: _periodStats(records, yearStart, clock),
    );
  }

  static Set<DateTime> _daysWithFasting(
    List<FastRecord> records, {
    required DateTime now,
  }) {
    final days = <DateTime>{};
    for (final record in records) {
      final end = record.endAt ?? now;
      var cursor = dateOnly(record.startAt);
      final last = dateOnly(end);
      while (!cursor.isAfter(last)) {
        final next = cursor.add(const Duration(days: 1));
        if (_overlapMinutes(record, cursor, next, now) > 0) {
          days.add(cursor);
        }
        cursor = next;
      }
    }
    return days;
  }

  static PeriodStats _periodStats(
    List<FastRecord> records,
    DateTime rangeStart,
    DateTime now,
  ) {
    final start = dateOnly(rangeStart);
    var minutes = 0;
    var sessions = 0;
    for (final record in records) {
      final overlap = _overlapMinutes(record, start, now, now);
      if (overlap > 0) {
        minutes += overlap;
        sessions++;
      }
    }

    var days = 0;
    var cursor = start;
    final last = dateOnly(now);
    while (!cursor.isAfter(last)) {
      final next = cursor.add(const Duration(days: 1));
      var dayMinutes = 0;
      for (final record in records) {
        dayMinutes += _overlapMinutes(record, cursor, next, now);
      }
      if (dayMinutes > 0) days++;
      cursor = next;
    }

    return PeriodStats(
      minutes: minutes,
      daysFasted: days,
      sessions: sessions,
    );
  }

  static int _overlapMinutes(
    FastRecord record,
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime now,
  ) {
    final start = record.startAt;
    final end = record.endAt ?? now;
    final lo = start.isAfter(rangeStart) ? start : rangeStart;
    final hi = end.isBefore(rangeEnd) ? end : rangeEnd;
    if (!hi.isAfter(lo)) return 0;
    return hi.difference(lo).inMinutes;
  }
}
