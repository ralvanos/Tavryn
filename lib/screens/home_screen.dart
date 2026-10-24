import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fast_record.dart';
import '../models/fast_schedule.dart';
import '../models/fasting_math.dart';
import '../models/fasting_stage.dart';
import '../services/fast_storage.dart';
import '../theme.dart';
import '../widgets/datetime_fields.dart';
import '../widgets/fast_ring.dart';
import '../widgets/fasting_timeline.dart';
import '../widgets/schedule_choice_strip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  FastRecord? _active;
  FastSchedule _schedule =
      FastSchedule.presets.firstWhere((s) => s.id == FastSchedule.defaultId);
  List<FastSchedule> _schedules = FastSchedule.presets;
  DateTime? _eatingUntil;
  bool _loading = true;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final active = await FastStorage.getActiveFast();
    final schedule = await FastStorage.getActiveSchedule();
    final schedules = await FastStorage.getVisibleSchedules();
    await FastStorage.syncEatingWindow();
    final eating = await FastStorage.getEatingUntil();
    if (!mounted) return;
    setState(() {
      _active = active;
      _schedule = schedule;
      _schedules = schedules;
      _eatingUntil = eating;
      _loading = false;
      _now = DateTime.now();
    });
    _syncTicker();
  }

  bool get _shouldTick {
    if (_active != null) return true;
    return _eatingUntil != null && _eatingUntil!.isAfter(_now);
  }

  void _syncTicker() {
    if (_shouldTick) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final now = DateTime.now();
        setState(() => _now = now);
        if (_active == null &&
            (_eatingUntil == null || !_eatingUntil!.isAfter(now))) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _notify() => widget.onChanged?.call();

  Future<void> _selectSchedule(FastSchedule schedule) async {
    if (_active != null) return;
    await FastStorage.setActiveScheduleId(schedule.id);
    if (!mounted) return;
    setState(() => _schedule = schedule);
  }

  Future<void> _start({DateTime? startAt, FastSchedule? schedule}) async {
    try {
      final proto = schedule ?? _schedule;
      if (schedule != null && schedule.id != _schedule.id) {
        await FastStorage.setActiveScheduleId(schedule.id);
      }
      final record = await FastStorage.startFast(
        schedule: proto,
        startAt: startAt,
      );
      if (!mounted) return;
      setState(() {
        _active = record;
        _schedule = proto;
        _eatingUntil = null;
      });
      _syncTicker();
      _notify();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _end() async {
    final active = _active;
    if (active == null) return;
    final extras = await _promptEndExtras(active);
    if (extras == null || !mounted) return;
    try {
      final updated = await FastStorage.endFast(
        id: active.id,
        endAt: extras.$2,
        note: extras.$1,
      );
      if (!mounted) return;
      setState(() {
        _active = null;
        _eatingUntil = updated.endAt?.add(
          Duration(minutes: _schedule.eatMinutes),
        );
      });
      _syncTicker();
      await _load();
      _notify();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<(String?, DateTime)?> _promptEndExtras(FastRecord active) async {
    var endAt = DateTime.now();
    final note = TextEditingController(text: active.note ?? '');
    final met = active.metGoal();
    final result = await showModalBottomSheet<bool>(
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
              final invalid = endAt.isBefore(active.startAt);
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      met ? 'Goal reached' : 'End this fast?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      met
                          ? 'Save as now, or change the end day and time. Note is optional.'
                          : 'You can still save it. Change the end time if this finished earlier.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DateTimeEditRow(
                      label: 'Ended',
                      value: endAt,
                      lastDate: DateTime.now(),
                      onChanged: (next) => setSheet(() => endAt = next),
                    ),
                    if (invalid) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'End must be at or after the start time.',
                        style: TextStyle(
                          color: TavrynColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Optional note',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
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
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          invalid ? null : () => Navigator.pop(ctx, true),
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
                ),
              );
            },
          ),
        );
      },
    );
    final text = note.text.trim();
    note.dispose();
    if (result != true) return null;
    var ended = endAt;
    final now = DateTime.now();
    if (ended.isAfter(now)) ended = now;
    return (text.isEmpty ? null : text, ended);
  }

  Future<void> _editStart() async {
    final active = _active;
    if (active == null) return;
    final next = await showDateAndTimePicker(
      context: context,
      title: 'Edit start',
      initial: active.startAt,
      lastDate: DateTime.now(),
    );
    if (next == null) return;
    await FastStorage.upsertFast(active.copyWith(startAt: next));
    await _load();
    _notify();
  }

  Future<void> _startLate() async {
    var start = DateTime.now().subtract(const Duration(hours: 1));
    var proto = _schedule;
    final saved = await showModalBottomSheet<bool>(
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
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'When did this fast start?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ScheduleChoiceStrip(
                      schedules: _schedules,
                      selectedId: proto.id,
                      onSelected: (next) => setSheet(() => proto = next),
                    ),
                    const SizedBox(height: 16),
                    DateTimeEditRow(
                      label: 'Day and time',
                      value: start,
                      lastDate: DateTime.now(),
                      onChanged: (next) => setSheet(() => start = next),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
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
                ),
              );
            },
          ),
        );
      },
    );
    if (saved != true) return;
    await _start(startAt: start, schedule: proto);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: TavrynColors.ember),
      );
    }

    final active = _active;
    final elapsed = active?.elapsed(_now) ?? Duration.zero;
    final goal = active?.goalMinutes ?? _schedule.fastMinutes;
    final progress = FastingMath.progress(
      goalMinutes: goal,
      elapsed: elapsed,
    );
    final stage = FastingStages.forElapsed(elapsed);
    final fasting = active != null;
    final overtime = fasting && goal > 0 && elapsed.inMinutes >= goal;
    final eating =
        !fasting && _eatingUntil != null && _eatingUntil!.isAfter(_now);
    final accent = fasting
        ? (overtime ? TavrynColors.dawn : TavrynColors.ember)
        : (eating ? TavrynColors.dawn : TavrynColors.dusk);

    String statusLabel;
    String detail;
    String? whenLabel;
    if (fasting) {
      statusLabel = overtime ? 'Goal reached' : 'Fasting';
      if (goal <= 0) {
        detail = stage == null
            ? 'Flexi · first milestone at 12 hours'
            : 'Flexi · ${stage.title}';
      } else {
        final goalAt = active.startAt.add(Duration(minutes: goal));
        whenLabel = FastingMath.endsAtLabel(
          goalAt,
          now: _now,
          overtime: overtime,
        );
        if (overtime) {
          detail = 'Beyond ${FastingMath.formatHoursCompact(goal / 60)}';
        } else {
          final left = Duration(minutes: goal) - elapsed;
          detail = '${FastingMath.formatDuration(left)} remaining';
        }
      }
    } else if (eating) {
      statusLabel = 'Eating window';
      detail = FastingMath.nextFastAtLabel(_eatingUntil!, now: _now);
    } else {
      statusLabel = 'Ready';
      detail = _schedule.isFlexi
          ? 'Open-ended fast · tap start when you begin'
          : _schedule.subtitle.isEmpty
              ? 'Tap start when you begin'
              : _schedule.subtitle;
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12101A), TavrynColors.ink],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'Tavryn',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('EEE d MMM').format(_now),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (!fasting)
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _schedules.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final s = _schedules[index];
                    final selected = s.id == _schedule.id;
                    return ChoiceChip(
                      label: Text(s.ratioLabel),
                      selected: selected,
                      selectedColor: TavrynColors.ember,
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF1A1208)
                            : TavrynColors.onInk,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => _selectSchedule(s),
                    );
                  },
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final ringSize =
                        (constraints.maxWidth < constraints.maxHeight
                                ? constraints.maxWidth
                                : constraints.maxHeight) *
                            0.92;
                    return Center(
                      child: FastRing(
                        size: ringSize.clamp(220.0, 360.0),
                        progress: fasting
                            ? progress
                            : eating
                                ? () {
                                    final end = _eatingUntil!;
                                    final eatMins = _schedule.eatMinutes <= 0
                                        ? 60
                                        : _schedule.eatMinutes;
                                    final start = end.subtract(
                                      Duration(minutes: eatMins),
                                    );
                                    final total =
                                        end.difference(start).inSeconds;
                                    if (total <= 0) return 0.0;
                                    return (_now.difference(start).inSeconds /
                                            total)
                                        .clamp(0.0, 1.0);
                                  }()
                                : 0,
                        accent: accent,
                        glow: fasting || eating,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              statusLabel.toUpperCase(),
                              style: TextStyle(
                                letterSpacing: 2.2,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fasting
                                  ? FastingMath.formatDuration(elapsed)
                                  : eating
                                      ? FastingMath.formatDuration(
                                          _eatingUntil!.difference(_now),
                                        )
                                      : _schedule.ratioLabel,
                              style: TextStyle(
                                fontSize: ringSize >= 300 ? 42 : 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: ringSize * 0.62,
                              child: Text(
                                detail,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (whenLabel != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                whenLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.38),
                                  fontSize: 12.5,
                                  letterSpacing: 0.15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            _TimelineLaunch(
              fasting: fasting,
              stageTitle: stage?.title,
              onTap: () => showFastingTimelineSheet(
                context,
                startAt: active?.startAt,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: _HomeActionDock(
                fasting: fasting,
                accent: accent,
                onStart: () => _start(),
                onStartLate: _startLate,
                onEnd: _end,
                onEditStart: _editStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineLaunch extends StatelessWidget {
  const _TimelineLaunch({
    required this.fasting,
    required this.onTap,
    this.stageTitle,
  });

  final bool fasting;
  final String? stageTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = fasting && stageTitle != null
        ? 'Timeline · $stageTitle'
        : 'Fasting timeline';

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timeline,
                    size: 16,
                    color: fasting
                        ? TavrynColors.ember
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fasting
                          ? TavrynColors.ember
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeActionDock extends StatelessWidget {
  const _HomeActionDock({
    required this.fasting,
    required this.accent,
    required this.onStart,
    required this.onStartLate,
    required this.onEnd,
    required this.onEditStart,
  });

  final bool fasting;
  final Color accent;
  final VoidCallback onStart;
  final VoidCallback onStartLate;
  final VoidCallback onEnd;
  final VoidCallback onEditStart;

  static final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xCC101218),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: TavrynColors.ember.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: fasting ? _fastingRow() : _idleRow(),
        ),
      ),
    );
  }

  Widget _idleRow() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: FilledButton(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: TavrynColors.ember,
              foregroundColor: const Color(0xFF1A1208),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: _shape,
            ),
            child: const Text(
              'Start fast',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: OutlinedButton(
            onPressed: onStartLate,
            style: OutlinedButton.styleFrom(
              foregroundColor: TavrynColors.onInk,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: _shape,
            ),
            child: const Text(
              'Already started',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fastingRow() {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onEnd,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xFF1A1208),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: _shape,
            ),
            child: const Text(
              'End fast',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Edit start time',
          onPressed: onEditStart,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            foregroundColor: TavrynColors.onInk,
            minimumSize: const Size(44, 44),
            shape: _shape,
          ),
          icon: const Icon(Icons.schedule_outlined),
        ),
      ],
    );
  }
}
