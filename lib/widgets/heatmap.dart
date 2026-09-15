import 'package:flutter/material.dart';

import '../models/fasting_math.dart';
import '../theme.dart';

/// 12-week fasting heatmap as a compact contribution grid.
class FastHeatmap extends StatelessWidget {
  const FastHeatmap({
    super.key,
    required this.hoursByDay,
    this.weeks = 12,
  });

  final Map<DateTime, double> hoursByDay;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    if (hoursByDay.isEmpty) {
      return Text(
        'Complete a fast to see your week-by-week pattern.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
      );
    }

    final days = hoursByDay.keys.toList()..sort();
    final start = FastingMath.mondayOf(days.first);
    var cursor = start;
    final end = days.last;
    final cells = <DateTime>[];
    while (!cursor.isAfter(end)) {
      cells.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    while (cells.length % 7 != 0) {
      cells.add(cells.last.add(const Duration(days: 1)));
    }

    final columns = cells.length ~/ 7;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        const labelWidth = 14.0;
        final usable = constraints.maxWidth - labelWidth - 8;
        final size =
            ((usable - gap * (columns - 1)) / columns).clamp(8.0, 14.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (final label in labels)
                      SizedBox(
                        height: size + gap,
                        width: labelWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) const SizedBox(width: gap),
                          Column(
                            children: [
                              for (var row = 0; row < 7; row++) ...[
                                if (row > 0) const SizedBox(height: gap),
                                _Cell(
                                  size: size,
                                  hours: hoursByDay[cells[col * 7 + row]] ?? 0,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Less',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 8),
                for (final alpha in [0.08, 0.22, 0.4, 0.65, 1.0])
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: TavrynColors.ember.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                Text(
                  'More',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.size, required this.hours});

  final double size;
  final double hours;

  @override
  Widget build(BuildContext context) {
    final t = (hours / 16).clamp(0.0, 1.0);
    final color = t == 0
        ? Colors.white.withValues(alpha: 0.06)
        : Color.lerp(
            TavrynColors.ember.withValues(alpha: 0.25),
            TavrynColors.ember,
            t,
          )!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
