import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Separate day and time controls so both are obviously editable.
class DateTimeEditRow extends StatelessWidget {
  const DateTimeEditRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.lastDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PickerChip(
                icon: Icons.calendar_today_outlined,
                text: DateFormat('EEE d MMM y').format(value),
                onTap: () => _pickDate(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PickerChip(
                icon: Icons.schedule,
                text: DateFormat('HH:mm').format(value),
                onTap: () => _pickTime(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 1)),
      helpText: 'Choose day',
    );
    if (date == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, value.hour, value.minute),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: 'Choose time',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (time == null) return;
    onChanged(
      DateTime(value.year, value.month, value.day, time.hour, time.minute),
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TavrynColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 16, color: TavrynColors.ember),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> showDateAndTimePicker({
  required BuildContext context,
  required String title,
  required DateTime initial,
  DateTime? lastDate,
}) async {
  var current = initial;
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: TavrynColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                DateTimeEditRow(
                  label: 'Day and time',
                  value: current,
                  lastDate: lastDate,
                  onChanged: (next) => setSheet(() => current = next),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, current),
                  style: FilledButton.styleFrom(
                    backgroundColor: TavrynColors.ember,
                    foregroundColor: const Color(0xFF1A1208),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
