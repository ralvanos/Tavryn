import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fast_record.dart';
import '../models/fasting_math.dart';
import '../models/fasting_stage.dart';
import '../services/fast_storage.dart';
import '../theme.dart';
import '../widgets/glow_card.dart';
import '../widgets/heatmap.dart';
import '../widgets/stat_card.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => TrendsScreenState();
}

class TrendsScreenState extends State<TrendsScreen> {
  List<FastRecord> _fasts = [];
  bool _loading = true;
  _TrendSpan _span = _TrendSpan.week;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final fasts = await FastStorage.getFasts();
    if (!mounted) return;
    setState(() {
      _fasts = fasts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: TavrynColors.ember),
      );
    }

    final stats = FastingMath.compute(_fasts);
    FastingStage? topStage;
    if (stats.topStageId != null) {
      for (final s in FastingStages.all) {
        if (s.id == stats.topStageId) topStage = s;
      }
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text(
            'Trends',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Streaks count calendar days covered by a completed goal fast.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.28,
            children: [
              StatCard(
                label: 'Current streak',
                value: '${stats.currentStreakDays}d',
                icon: Icons.local_fire_department_outlined,
              ),
              StatCard(
                label: 'Longest streak',
                value: '${stats.longestStreakDays}d',
                icon: Icons.timeline,
                color: TavrynColors.dusk,
              ),
              StatCard(
                label: 'Longest fast',
                value: FastingMath.formatHoursCompact(stats.longestHours),
                icon: Icons.hourglass_bottom,
              ),
              StatCard(
                label: 'Total fasted',
                value: FastingMath.formatHoursCompact(stats.totalHours),
                icon: Icons.timelapse,
                color: TavrynColors.dawn,
              ),
              StatCard(
                label: 'Hit goal',
                value: stats.endedCount == 0
                    ? '—'
                    : '${(stats.completionRate * 100).round()}%',
                icon: Icons.flag_outlined,
                color: TavrynColors.dusk,
              ),
              StatCard(
                label: 'Avg completed',
                value: stats.completedCount == 0
                    ? '—'
                    : FastingMath.formatHoursCompact(stats.avgCompletedHours),
                icon: Icons.insights_outlined,
                color: TavrynColors.dawn,
              ),
              StatCard(
                label: 'Fasts',
                value: '${stats.sessionCount}',
                icon: Icons.nights_stay_outlined,
              ),
              StatCard(
                label: 'Days fasted',
                value: '${stats.daysFasted}',
                icon: Icons.calendar_today_outlined,
                color: TavrynColors.dusk,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PeriodCard(
            span: _span,
            stats: stats,
            onChanged: (value) => setState(() => _span = value),
          ),
          if (topStage != null) ...[
            const SizedBox(height: 12),
            GlowCard(
              accent: topStage.color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: topStage.color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Most common completed stage: ${topStage.title}',
                      style: TextStyle(
                        color: topStage.color,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Hours per week',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GlowCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: SizedBox(
              height: 196,
              child: _WeekChart(buckets: stats.weeklyHours),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Daily pattern',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GlowCard(
            child: FastHeatmap(hoursByDay: stats.hoursByDay),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.buckets});

  final List<WeekBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.every((b) => b.minutes == 0)) {
      return Center(
        child: Text(
          'Weekly hours will appear after your first fast.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    final maxY =
        buckets.map((b) => b.hours).fold<double>(8, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: (maxY * 1.25).clamp(4, 200),
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= buckets.length) {
                  return const SizedBox.shrink();
                }
                if (buckets.length > 6 && i.isOdd) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d MMM').format(buckets[i].weekStart),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].hours,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [TavrynColors.emberDeep, TavrynColors.ember],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _TrendSpan { week, month, year }

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.span,
    required this.stats,
    required this.onChanged,
  });

  final _TrendSpan span;
  final FastingStats stats;
  final ValueChanged<_TrendSpan> onChanged;

  PeriodStats get _selected {
    switch (span) {
      case _TrendSpan.week:
        return stats.week;
      case _TrendSpan.month:
        return stats.month;
      case _TrendSpan.year:
        return stats.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _selected;
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This period',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final option in _TrendSpan.values)
                ChoiceChip(
                  label: Text(switch (option) {
                    _TrendSpan.week => 'Week',
                    _TrendSpan.month => 'Month',
                    _TrendSpan.year => 'Year',
                  }),
                  selected: span == option,
                  selectedColor: TavrynColors.ember,
                  labelStyle: TextStyle(
                    color: span == option
                        ? const Color(0xFF1A1208)
                        : TavrynColors.onInk,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PeriodMetric(
                label: 'Hours',
                value: FastingMath.formatHoursCompact(period.hours),
              ),
              _PeriodMetric(
                label: 'Days fasted',
                value: '${period.daysFasted}',
              ),
              _PeriodMetric(
                label: 'Sessions',
                value: '${period.sessions}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodMetric extends StatelessWidget {
  const _PeriodMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
