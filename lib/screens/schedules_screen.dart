import 'package:flutter/material.dart';

import '../models/fast_schedule.dart';
import '../services/fast_storage.dart';
import '../theme.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({
    super.key,
    this.onChanged,
    this.embedded = false,
  });

  final VoidCallback? onChanged;
  final bool embedded;

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  List<FastSchedule> _visible = [];
  Set<String> _hidden = {};
  String _activeId = FastSchedule.defaultId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final visible = await FastStorage.getVisibleSchedules();
    final hidden = await FastStorage.getHiddenScheduleIds();
    final active = await FastStorage.getActiveScheduleId();
    if (!mounted) return;
    setState(() {
      _visible = visible;
      _hidden = hidden;
      _activeId = active;
      _loading = false;
    });
  }

  Future<void> _editCustom([FastSchedule? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var fastHours = existing == null ? 16.0 : existing.fastMinutes / 60.0;
    var eatHours = existing == null ? 8.0 : existing.eatMinutes / 60.0;
    var flexi = existing?.isFlexi ?? false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TavrynColors.card,
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
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'New schedule' : 'Edit schedule',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: name,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: TavrynColors.ember),
                        ),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: flexi,
                      activeThumbColor: TavrynColors.ember,
                      title: const Text('Flexi (no time cap)'),
                      onChanged: (v) => setSheet(() => flexi = v),
                    ),
                    if (!flexi) ...[
                      Text('Fast ${fastHours.toStringAsFixed(0)} hours'),
                      Slider(
                        value: fastHours.clamp(1, 72),
                        min: 1,
                        max: 72,
                        divisions: 71,
                        activeColor: TavrynColors.ember,
                        onChanged: (v) => setSheet(() => fastHours = v),
                      ),
                      Text('Eat ${eatHours.toStringAsFixed(0)} hours'),
                      Slider(
                        value: eatHours.clamp(0, 24),
                        min: 0,
                        max: 24,
                        divisions: 24,
                        activeColor: TavrynColors.dawn,
                        onChanged: (v) => setSheet(() => eatHours = v),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: TavrynColors.ember,
                        foregroundColor: const Color(0xFF1A1208),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    final label = name.text.trim();
    name.dispose();
    if (saved != true || label.isEmpty) return;

    await FastStorage.saveCustomSchedule(
      FastSchedule(
        id: existing?.id ?? FastStorage.newId(),
        name: label,
        fastMinutes: flexi ? 0 : (fastHours.round() * 60),
        eatMinutes: flexi ? 0 : (eatHours.round() * 60),
        subtitle: 'Custom',
      ),
    );
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: CircularProgressIndicator(color: TavrynColors.ember),
        ),
      );
    }

    final hiddenPresets =
        FastSchedule.presets.where((p) => _hidden.contains(p.id)).toList();

    return ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'Schedules are snapshots when a fast starts. Editing a protocol does not rewrite history.',
          style: TextStyle(color: Color(0x88F4F1EA)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _editCustom(),
          icon: const Icon(Icons.add),
          label: const Text('Create custom schedule'),
          style: FilledButton.styleFrom(
            backgroundColor: TavrynColors.ember,
            foregroundColor: const Color(0xFF1A1208),
          ),
        ),
        const SizedBox(height: 20),
        for (final schedule in _visible)
          _ScheduleTile(
            schedule: schedule,
            selected: schedule.id == _activeId,
            onSelect: () async {
              await FastStorage.setActiveScheduleId(schedule.id);
              await _load();
              widget.onChanged?.call();
            },
            onHide: schedule.preset
                ? () async {
                    await FastStorage.setPresetHidden(schedule.id, true);
                    await _load();
                    widget.onChanged?.call();
                  }
                : null,
            onEdit: schedule.preset ? null : () => _editCustom(schedule),
            onDelete: schedule.preset
                ? null
                : () async {
                    await FastStorage.deleteCustomSchedule(schedule.id);
                    await _load();
                    widget.onChanged?.call();
                  },
          ),
        if (hiddenPresets.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Hidden presets',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final schedule in hiddenPresets)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(schedule.name),
              subtitle: Text(schedule.subtitle),
              trailing: TextButton(
                onPressed: () async {
                  await FastStorage.setPresetHidden(schedule.id, false);
                  await _load();
                  widget.onChanged?.call();
                },
                child: const Text('Restore'),
              ),
            ),
        ],
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.selected,
    required this.onSelect,
    this.onHide,
    this.onEdit,
    this.onDelete,
  });

  final FastSchedule schedule;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onHide;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TavrynColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? TavrynColors.ember.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        onTap: onSelect,
        title: Text(
          schedule.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (schedule.name != schedule.ratioLabel) schedule.ratioLabel,
            if (schedule.subtitle.isNotEmpty) schedule.subtitle,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            if (onHide != null)
              IconButton(
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: onHide,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: TavrynColors.danger),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
