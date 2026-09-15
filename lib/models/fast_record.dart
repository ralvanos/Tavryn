/// A single fasting session. [endAt] is null while the fast is in progress.
class FastRecord {
  const FastRecord({
    required this.id,
    required this.startAt,
    this.endAt,
    required this.scheduleId,
    required this.scheduleName,
    required this.goalMinutes,
    this.note,
    this.feeling,
  });

  final String id;
  final DateTime startAt;
  final DateTime? endAt;
  final String scheduleId;
  final String scheduleName;

  /// Goal at the moment the fast started (`0` = flexi).
  final int goalMinutes;
  final String? note;

  /// Optional 1–5 how the fast felt.
  final int? feeling;

  bool get isActive => endAt == null;

  Duration elapsed([DateTime? now]) {
    final end = endAt ?? now ?? DateTime.now();
    final d = end.difference(startAt);
    return d.isNegative ? Duration.zero : d;
  }

  bool metGoal([DateTime? now]) {
    if (goalMinutes <= 0) {
      return elapsed(now).inMinutes >= 1;
    }
    return elapsed(now).inMinutes >= goalMinutes;
  }

  FastRecord copyWith({
    String? id,
    DateTime? startAt,
    DateTime? endAt,
    bool clearEnd = false,
    String? scheduleId,
    String? scheduleName,
    int? goalMinutes,
    String? note,
    bool clearNote = false,
    int? feeling,
    bool clearFeeling = false,
  }) {
    return FastRecord(
      id: id ?? this.id,
      startAt: startAt ?? this.startAt,
      endAt: clearEnd ? null : (endAt ?? this.endAt),
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleName: scheduleName ?? this.scheduleName,
      goalMinutes: goalMinutes ?? this.goalMinutes,
      note: clearNote ? null : (note ?? this.note),
      feeling: clearFeeling ? null : (feeling ?? this.feeling),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'scheduleId': scheduleId,
        'scheduleName': scheduleName,
        'goalMinutes': goalMinutes,
        'note': note,
        'feeling': feeling,
      };

  factory FastRecord.fromJson(Map<String, dynamic> json) {
    final startRaw = json['startAt'] as String?;
    if (startRaw == null || startRaw.isEmpty) {
      throw const FormatException('Fast record missing startAt');
    }
    final endRaw = json['endAt'] as String?;
    return FastRecord(
      id: json['id'] as String? ?? startRaw,
      startAt: DateTime.parse(startRaw),
      endAt: (endRaw == null || endRaw.isEmpty) ? null : DateTime.parse(endRaw),
      scheduleId: json['scheduleId'] as String? ?? '',
      scheduleName: json['scheduleName'] as String? ?? '',
      goalMinutes: (json['goalMinutes'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      feeling: (json['feeling'] as num?)?.toInt(),
    );
  }
}
