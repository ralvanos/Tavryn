import 'package:flutter/material.dart';

import '../models/fast_schedule.dart';
import '../theme.dart';

class ScheduleChoiceStrip extends StatelessWidget {
  const ScheduleChoiceStrip({
    super.key,
    required this.schedules,
    required this.selectedId,
    required this.onSelected,
  });

  final List<FastSchedule> schedules;
  final String selectedId;
  final ValueChanged<FastSchedule> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Protocol',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: schedules.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final s = schedules[index];
              final selected = s.id == selectedId;
              return ChoiceChip(
                label: Text(s.ratioLabel),
                selected: selected,
                selectedColor: TavrynColors.ember,
                labelStyle: TextStyle(
                  color:
                      selected ? const Color(0xFF1A1208) : TavrynColors.onInk,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onSelected(s),
              );
            },
          ),
        ),
      ],
    );
  }
}
