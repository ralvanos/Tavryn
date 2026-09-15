import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fast_record.dart';
import '../models/fast_schedule.dart';
import '../models/fasting_math.dart';
import '../services/fast_storage.dart';
import '../theme.dart';
import '../widgets/datetime_fields.dart';
import '../widgets/fasting_timeline.dart';
import '../widgets/schedule_choice_strip.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<FastRecord> _fasts = [];
  bool _loading = true;
  String _filter = 'all';

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

  List<FastRecord> get _visible {
    switch (_filter) {
      case 'completed':
        return _fasts.where((f) => !f.isActive && f.metGoal()).toList();
      case 'early':
        return _fasts.where((f) => !f.isActive && !f.metGoal()).toList();
      case 'active':
        return _fasts.where((f) => f.isActive).toList();
      default:
        return _fasts;
    }
  }

  Future<void> _openEditor(FastRecord record) async {
    final schedules = [...await FastStorage.getVisibleSchedules()];
    if (!mounted) return;
    var selected = FastSchedule.matching(
      id: record.scheduleId,
      name: record.scheduleName,
      goalMinutes: record.goalMinutes,
      known: schedules,
    );
    if (!schedules.any((s) => s.id == selected.id)) {
      schedules.insert(0, selected);
    }
    var start = record.startAt;
    var end = record.endAt;
    final note = TextEditingController(text: record.note ?? '');

    final action = await showModalBottomSheet<String>(
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
              final elapsedEnd = end ?? DateTime.now();
              var elapsed = elapsedEnd.difference(start);
              if (elapsed.isNegative) elapsed = Duration.zero;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected.ratioLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      end == null
                          ? 'In progress'
                          : (selected.fastMinutes <= 0
                                  ? elapsed.inMinutes >= 1
                                  : elapsed.inMinutes >= selected.fastMinutes)
                              ? 'Completed session'
                              : 'Ended early',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ScheduleChoiceStrip(
                      schedules: schedules,
                      selectedId: selected.id,
                      onSelected: (next) => setSheet(() => selected = next),
                    ),
                    if (selected.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        selected.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DateTimeEditRow(
                      label: 'Start',
                      value: start,
                      lastDate: DateTime.now(),
                      onChanged: (next) => setSheet(() => start = next),
                    ),
                    const SizedBox(height: 14),
                    DateTimeEditRow(
                      label: 'End',
                      value: end ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      onChanged: (next) => setSheet(() => end = next),
                    ),
                    if (end != null)
                      TextButton(
                        onPressed: () => setSheet(() => end = null),
                        child: const Text('Clear end (resume as active)'),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Optional note',
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
                    const SizedBox(height: 20),
                    FastingTimeline(
                      elapsed: elapsed,
                      active: true,
                      live: end == null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: TavrynColors.ember,
                        foregroundColor: const Color(0xFF1A1208),
                      ),
                      child: const Text('Save changes'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'delete'),
                      child: const Text(
                        'Delete this fast',
                        style: TextStyle(color: TavrynColors.danger),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    final noteText = note.text.trim();
    note.dispose();
    if (!mounted || action == null) return;

    if (action == 'delete') {
      await _deleteFast(record);
      return;
    }

    try {
      await FastStorage.upsertFast(
        record.copyWith(
          startAt: start,
          endAt: end,
          clearEnd: end == null,
          note: noteText.isEmpty ? null : noteText,
          clearNote: noteText.isEmpty,
          scheduleId: selected.id,
          scheduleName: selected.ratioLabel,
          goalMinutes: selected.fastMinutes,
        ),
      );
      if (end == null) {
        await FastStorage.setActiveScheduleId(selected.id);
      }
      await reload();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _deleteFast(FastRecord record) async {
    final ok = await _confirmDelete();
    if (ok != true) return;
    await FastStorage.deleteFast(record.id);
    await reload();
    widget.onChanged?.call();
  }

  Future<bool?> _confirmDelete() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this fast?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: TavrynColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: TavrynColors.ember),
      );
    }

    final items = _visible;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'History',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                _FilterChip(
                  label: 'Completed',
                  selected: _filter == 'completed',
                  onTap: () => setState(() => _filter = 'completed'),
                ),
                _FilterChip(
                  label: 'Ended early',
                  selected: _filter == 'early',
                  onTap: () => setState(() => _filter = 'early'),
                ),
                _FilterChip(
                  label: 'Active',
                  selected: _filter == 'active',
                  onTap: () => setState(() => _filter = 'active'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No fasts here yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final fast = items[index];
                      final elapsed = fast.elapsed();
                      final met = !fast.isActive && fast.metGoal();
                      return Dismissible(
                        key: ValueKey(fast.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: TavrynColors.danger.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          return await _confirmDelete() ?? false;
                        },
                        onDismissed: (_) async {
                          await FastStorage.deleteFast(fast.id);
                          await reload();
                          widget.onChanged?.call();
                        },
                        child: Material(
                          color: TavrynColors.card,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openEditor(fast),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: fast.isActive
                                          ? TavrynColors.ember
                                          : met
                                              ? TavrynColors.dawn
                                              : TavrynColors.danger
                                                  .withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          FastSchedule.displayName(
                                            fast.scheduleId,
                                            fast.scheduleName,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('EEE d MMM, HH:mm')
                                              .format(fast.startAt),
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.55),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (fast.note != null &&
                                            fast.note!.isNotEmpty)
                                          Text(
                                            fast.note!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.45),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        FastingMath.formatDuration(elapsed),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      fast.isActive
                                          ? const _LiveBadge()
                                          : Text(
                                              met ? 'Completed' : 'Early',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TavrynColors.danger.withValues(alpha: 0.55 + t * 0.45),
                boxShadow: [
                  BoxShadow(
                    color:
                        TavrynColors.danger.withValues(alpha: 0.2 + t * 0.5),
                    blurRadius: 4 + t * 6,
                    spreadRadius: t * 1.4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Opacity(
              opacity: 0.7 + t * 0.3,
              child: child,
            ),
          ],
        );
      },
      child: const Text(
        'Live',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: TavrynColors.danger,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: TavrynColors.ember,
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF1A1208) : TavrynColors.onInk,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
