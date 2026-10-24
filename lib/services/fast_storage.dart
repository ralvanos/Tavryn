import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/export_schema.dart';
import '../models/fast_record.dart';
import '../models/fast_schedule.dart';
import '../models/fasting_stage.dart';
import 'auto_lock_policy.dart';
import 'encrypted_store.dart';
import 'export_crypto.dart';

class ImportResult {
  const ImportResult.success(this.data)
      : success = true,
        needsPassphrase = false,
        encryptedEnvelope = null,
        errorMessage = null;

  const ImportResult.needsPassphrase(this.encryptedEnvelope)
      : success = false,
        needsPassphrase = true,
        data = null,
        errorMessage = null;

  const ImportResult.failure(this.errorMessage)
      : success = false,
        needsPassphrase = false,
        encryptedEnvelope = null,
        data = null;

  final bool success;
  final bool needsPassphrase;
  final String? errorMessage;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? encryptedEnvelope;
}

enum ExportResult { success, cancelled, failure }

class FastSettings {
  const FastSettings({
    required this.reminderEnabled,
    required this.notifyFastEnd,
    required this.notifyStages,
    required this.notifyStartHour,
    required this.notifyStartMinute,
    required this.autoLockTimeoutSeconds,
    required this.disclaimerAccepted,
  });

  final bool reminderEnabled;
  final bool notifyFastEnd;
  final bool notifyStages;
  final int notifyStartHour;
  final int notifyStartMinute;
  final int autoLockTimeoutSeconds;
  final bool disclaimerAccepted;
}

/// Encrypted local store for fasts, schedules, settings, and notifications.
class FastStorage {
  FastStorage._();

  static const keyFasts = 'fasts';
  static const keyCustomSchedules = 'custom_schedules';
  static const keyHiddenScheduleIds = 'hidden_schedule_ids';
  static const keyActiveScheduleId = 'active_schedule_id';
  static const keyReminderEnabled = 'reminder_enabled';
  static const keyNotifyFastEnd = 'notify_fast_end';
  static const keyNotifyStages = 'notify_stages';
  static const keyNotifyStartHour = 'notify_start_hour';
  static const keyNotifyStartMinute = 'notify_start_minute';
  static const keyEatingUntil = 'eating_until';
  static const keyAutoLockTimeoutSeconds = 'auto_lock_timeout_seconds';
  static const keyDisclaimerAccepted = 'disclaimer_accepted';

  static const _notificationIdFastEnd = 1;
  static const _notificationIdDailyStart = 2;
  static const _notificationIdEatingEnd = 3;
  static const _stageNotificationBase = 10;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool? _notificationsPermissionGranted;
  static EncryptedStore get _store => EncryptedStore.instance;

  static bool get notificationsPermissionGranted =>
      _notificationsPermissionGranted ?? true;

  static String newId() {
    final rng = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-${rng.nextInt(1 << 32)}';
  }

  static Future<void> initNotifications() async {
    await EncryptedStore.instance.ensureInitialized();

    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings: initSettings);

    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'fasting_reminders',
        'Fasting reminders',
        description: 'Start, end, and stage reminders for your fast',
        importance: Importance.high,
      ),
    );

    final permissionGranted =
        await androidPlugin?.requestNotificationsPermission();
    _notificationsPermissionGranted = permissionGranted ?? true;

    await rescheduleNotifications();
  }

  /// Confirms the app may schedule exact alarms, and rebuilds pending alerts
  /// if the user has to grant that access.
  ///
  /// Call this after the Android activity exists. Notification setup runs
  /// before [runApp], when a settings screen cannot be opened.
  static Future<void> ensureExactAlarms() async {
    final androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    try {
      final canExact = await androidPlugin.canScheduleExactNotifications();
      if (canExact != false) return;
      final granted = await androidPlugin.requestExactAlarmsPermission();
      if (granted == true) await rescheduleNotifications();
    } catch (e) {
      debugPrint('Exact alarm permission check skipped: $e');
    }
  }

  static Future<List<FastRecord>> getFasts() async {
    final raw = await _store.getString(keyFasts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final records = <FastRecord>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          records.add(
            FastRecord.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          continue;
        }
      }
      records.sort((a, b) => b.startAt.compareTo(a.startAt));
      return records;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveFasts(List<FastRecord> records) async {
    final sorted = [...records]..sort((a, b) => b.startAt.compareTo(a.startAt));
    await _store.setString(
      keyFasts,
      jsonEncode([for (final r in sorted) r.toJson()]),
    );
    await rescheduleNotifications();
  }

  static Future<FastRecord?> getActiveFast() async {
    final fasts = await getFasts();
    for (final fast in fasts) {
      if (fast.isActive) return fast;
    }
    return null;
  }

  static Future<FastRecord> startFast({
    required FastSchedule schedule,
    DateTime? startAt,
  }) async {
    final existing = await getActiveFast();
    if (existing != null) {
      throw StateError('A fast is already in progress');
    }
    final record = FastRecord(
      id: newId(),
      startAt: startAt ?? DateTime.now(),
      scheduleId: schedule.id,
      scheduleName: schedule.ratioLabel,
      goalMinutes: schedule.fastMinutes,
    );
    final fasts = await getFasts();
    fasts.insert(0, record);
    await _saveFasts(fasts);
    await syncEatingWindow();
    return record;
  }

  static Future<FastRecord> endFast({
    required String id,
    DateTime? endAt,
    String? note,
    int? feeling,
  }) async {
    final fasts = await getFasts();
    final index = fasts.indexWhere((f) => f.id == id);
    if (index < 0) throw StateError('Fast not found');
    final current = fasts[index];
    final endedAt = endAt ?? DateTime.now();
    if (!endedAt.isAfter(current.startAt) && endedAt != current.startAt) {
      throw ArgumentError('End time must be at or after start time');
    }
    final updated = current.copyWith(
      endAt: endedAt.isBefore(current.startAt) ? current.startAt : endedAt,
      note: note,
      feeling: feeling,
    );
    fasts[index] = updated;
    await _saveFasts(fasts);
    await syncEatingWindow();
    return updated;
  }

  static Future<int> _eatMinutesFor(String scheduleId) async {
    final schedules = await getVisibleSchedules();
    for (final s in schedules) {
      if (s.id == scheduleId) return s.eatMinutes;
    }
    return FastSchedule.presetById(scheduleId)?.eatMinutes ?? 0;
  }

  static Future<FastRecord> upsertFast(FastRecord record) async {
    if (record.endAt != null && record.endAt!.isBefore(record.startAt)) {
      throw ArgumentError('End time cannot be before start time');
    }
    final fasts = await getFasts();
    final index = fasts.indexWhere((f) => f.id == record.id);
    final actives = fasts.where((f) => f.isActive && f.id != record.id);
    if (record.isActive && actives.isNotEmpty) {
      throw StateError('Only one active fast is allowed');
    }
    if (index >= 0) {
      fasts[index] = record;
    } else {
      fasts.insert(0, record);
    }
    await _saveFasts(fasts);
    await syncEatingWindow();
    return record;
  }

  static Future<void> deleteFast(String id) async {
    final fasts = await getFasts();
    fasts.removeWhere((f) => f.id == id);
    await _saveFasts(fasts);
    await syncEatingWindow();
  }

  /// Eating-window countdown follows the latest ended fast. No fasts → no timer.
  static Future<void> syncEatingWindow({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final fasts = await getFasts();
    final hasActive = fasts.any((f) => f.isActive);
    if (hasActive) {
      await _store.remove(keyEatingUntil);
      await rescheduleNotifications();
      return;
    }

    FastRecord? latestEnded;
    for (final fast in fasts) {
      final end = fast.endAt;
      if (end == null) continue;
      if (latestEnded == null || end.isAfter(latestEnded.endAt!)) {
        latestEnded = fast;
      }
    }

    if (latestEnded?.endAt == null) {
      await _store.remove(keyEatingUntil);
      await rescheduleNotifications();
      return;
    }

    final eatMinutes = await _eatMinutesFor(latestEnded!.scheduleId);
    if (eatMinutes <= 0) {
      await _store.remove(keyEatingUntil);
      await rescheduleNotifications();
      return;
    }

    final until = latestEnded.endAt!.add(Duration(minutes: eatMinutes));
    if (!until.isAfter(clock)) {
      await _store.remove(keyEatingUntil);
    } else {
      await _store.setString(keyEatingUntil, until.toIso8601String());
    }
    await rescheduleNotifications();
  }

  static Future<DateTime?> getEatingUntil() async {
    final raw = await _store.getString(keyEatingUntil);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearEatingUntil() async {
    await _store.remove(keyEatingUntil);
    await rescheduleNotifications();
  }

  static Future<String> getActiveScheduleId() async {
    return await _store.getString(keyActiveScheduleId) ??
        FastSchedule.defaultId;
  }

  static Future<void> setActiveScheduleId(String id) async {
    await _store.setString(keyActiveScheduleId, id);
  }

  static Future<List<FastSchedule>> getCustomSchedules() async {
    final raw = await _store.getString(keyCustomSchedules);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            FastSchedule.fromJson(Map<String, dynamic>.from(item))
                .copyWith(preset: false),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> getHiddenScheduleIds() async {
    final list = await _store.getStringList(keyHiddenScheduleIds) ?? [];
    return list.toSet();
  }

  static Future<List<FastSchedule>> getVisibleSchedules() async {
    final hidden = await getHiddenScheduleIds();
    final custom = await getCustomSchedules();
    return [
      for (final p in FastSchedule.presets)
        if (!hidden.contains(p.id)) p,
      ...custom.where((s) => !s.hidden),
    ];
  }

  static Future<FastSchedule> getActiveSchedule() async {
    final id = await getActiveScheduleId();
    final all = await getVisibleSchedules();
    for (final s in all) {
      if (s.id == id) return s;
    }
    return FastSchedule.presetById(FastSchedule.defaultId)!;
  }

  static Future<void> saveCustomSchedule(FastSchedule schedule) async {
    if (schedule.preset) {
      throw ArgumentError('Cannot overwrite a preset as custom');
    }
    if (schedule.name.trim().isEmpty) {
      throw ArgumentError('Name is required');
    }
    if (schedule.fastMinutes < 0 || schedule.eatMinutes < 0) {
      throw ArgumentError('Durations cannot be negative');
    }
    final list = await getCustomSchedules();
    final index = list.indexWhere((s) => s.id == schedule.id);
    final saved = schedule.copyWith(
      id: schedule.id.isEmpty ? newId() : schedule.id,
      name: schedule.name.trim(),
      preset: false,
    );
    if (index >= 0) {
      list[index] = saved;
    } else {
      list.add(saved);
    }
    await _store.setString(
      keyCustomSchedules,
      jsonEncode([for (final s in list) s.toJson()]),
    );
  }

  static Future<void> deleteCustomSchedule(String id) async {
    final list = await getCustomSchedules();
    list.removeWhere((s) => s.id == id);
    await _store.setString(
      keyCustomSchedules,
      jsonEncode([for (final s in list) s.toJson()]),
    );
    final active = await getActiveScheduleId();
    if (active == id) {
      await setActiveScheduleId(FastSchedule.defaultId);
    }
  }

  static Future<void> setPresetHidden(String id, bool hidden) async {
    if (FastSchedule.presetById(id) == null) return;
    final ids = await getHiddenScheduleIds();
    if (hidden) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    await _store.setStringList(keyHiddenScheduleIds, ids.toList());
    final active = await getActiveScheduleId();
    if (hidden && active == id) {
      await setActiveScheduleId(FastSchedule.defaultId);
    }
  }

  static Future<FastSettings> getSettings() async {
    return FastSettings(
      reminderEnabled: await _store.getBool(keyReminderEnabled) ?? false,
      notifyFastEnd: await _store.getBool(keyNotifyFastEnd) ?? true,
      notifyStages: await _store.getBool(keyNotifyStages) ?? false,
      notifyStartHour: await _store.getInt(keyNotifyStartHour) ?? 20,
      notifyStartMinute: await _store.getInt(keyNotifyStartMinute) ?? 0,
      autoLockTimeoutSeconds: AutoLockPolicy.normalizeTimeout(
        await _store.getInt(keyAutoLockTimeoutSeconds),
      ),
      disclaimerAccepted: await _store.getBool(keyDisclaimerAccepted) ?? false,
    );
  }

  static Future<int> getAutoLockTimeoutSeconds() async {
    return AutoLockPolicy.normalizeTimeout(
      await _store.getInt(keyAutoLockTimeoutSeconds),
    );
  }

  static Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    await _store.setInt(
      keyAutoLockTimeoutSeconds,
      AutoLockPolicy.normalizeTimeout(seconds),
    );
  }

  static Future<void> saveSettings(FastSettings settings) async {
    await _store.setBool(keyReminderEnabled, settings.reminderEnabled);
    await _store.setBool(keyNotifyFastEnd, settings.notifyFastEnd);
    await _store.setBool(keyNotifyStages, settings.notifyStages);
    await _store.setInt(keyNotifyStartHour, settings.notifyStartHour);
    await _store.setInt(keyNotifyStartMinute, settings.notifyStartMinute);
    await _store.setInt(
      keyAutoLockTimeoutSeconds,
      AutoLockPolicy.normalizeTimeout(settings.autoLockTimeoutSeconds),
    );
    await _store.setBool(keyDisclaimerAccepted, settings.disclaimerAccepted);
    await rescheduleNotifications();
  }

  static Future<void> setDisclaimerAccepted(bool value) async {
    await _store.setBool(keyDisclaimerAccepted, value);
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> buildExportMap() async {
    final snapshot = await _store.exportSnapshot();
    return <String, dynamic>{
      'schema_version': kExportSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'tavryn',
      'export_note':
          'Plaintext backup. Prefer PIN-protected export if you store this file elsewhere.',
      keyFasts: snapshot[keyFasts] ?? '[]',
      keyCustomSchedules: snapshot[keyCustomSchedules] ?? '[]',
      keyHiddenScheduleIds: snapshot[keyHiddenScheduleIds] ?? <String>[],
      keyActiveScheduleId:
          snapshot[keyActiveScheduleId] ?? FastSchedule.defaultId,
      keyReminderEnabled: snapshot[keyReminderEnabled] ?? false,
      keyNotifyFastEnd: snapshot[keyNotifyFastEnd] ?? true,
      keyNotifyStages: snapshot[keyNotifyStages] ?? false,
      keyNotifyStartHour: snapshot[keyNotifyStartHour] ?? 20,
      keyNotifyStartMinute: snapshot[keyNotifyStartMinute] ?? 0,
      keyEatingUntil: snapshot[keyEatingUntil],
      keyAutoLockTimeoutSeconds: snapshot[keyAutoLockTimeoutSeconds] ??
          AutoLockPolicy.defaultTimeoutSeconds,
      keyDisclaimerAccepted: snapshot[keyDisclaimerAccepted] ?? false,
    };
  }

  /// Suggested save name, e.g. `Tavryn_Backup_2026-10-23_15-26-04.json`.
  ///
  /// PIN-protected files use `.enc.json`. [now] is read as local clock fields.
  @visibleForTesting
  static String exportFileName({DateTime? now, bool encrypted = false}) {
    final clock = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${clock.year.toString().padLeft(4, '0')}-'
        '${two(clock.month)}-${two(clock.day)}_'
        '${two(clock.hour)}-${two(clock.minute)}-${two(clock.second)}';
    final extension = encrypted ? '.enc.json' : '.json';
    return 'Tavryn_Backup_$stamp$extension';
  }

  static Future<ExportResult> exportData({String? passphrase}) async {
    try {
      final data = await buildExportMap();
      final fileName = exportFileName(encrypted: passphrase != null);
      final String jsonString;
      if (passphrase != null) {
        final envelope = ExportCrypto.encryptExport(
          plaintextJson: jsonEncode(data),
          passphrase: passphrase,
        );
        jsonString = jsonEncode(envelope);
      } else {
        jsonString = jsonEncode(data);
      }

      final path = await FilePicker.saveFile(
        dialogTitle: passphrase != null
            ? 'Save PIN-protected backup'
            : 'Save fasting data',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(jsonString)),
      );

      if (path == null) return ExportResult.cancelled;
      return ExportResult.success;
    } catch (e) {
      debugPrint('Export error: $e');
      return ExportResult.failure;
    }
  }

  static Future<ImportResult> pickAndParseImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) {
      return const ImportResult.failure('No file selected.');
    }
    try {
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        return const ImportResult.failure('The selected file is empty.');
      }
      return parseImportBytes(bytes);
    } on FormatException {
      return const ImportResult.failure('Invalid backup file: malformed JSON.');
    } catch (e) {
      debugPrint('Import parse error: $e');
      return const ImportResult.failure('Could not read the selected file.');
    }
  }

  @visibleForTesting
  static ImportResult parseImportBytes(List<int> bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map) {
        return const ImportResult.failure(
            'Invalid backup file: expected a JSON object.');
      }
      return parseImportMap(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return const ImportResult.failure('Invalid backup file: malformed JSON.');
    } catch (e) {
      debugPrint('Import parse error: $e');
      return const ImportResult.failure('Could not read the selected file.');
    }
  }

  @visibleForTesting
  static ImportResult parseImportMap(Map<String, dynamic> decoded) {
    if (ExportCrypto.isEncryptedExport(decoded)) {
      return ImportResult.needsPassphrase(decoded);
    }
    return validateImportMap(decoded);
  }

  static ImportResult decryptAndValidateImport({
    required Map<String, dynamic> encryptedEnvelope,
    required String passphrase,
  }) {
    try {
      final plaintext = ExportCrypto.decryptExport(
        envelope: encryptedEnvelope,
        passphrase: passphrase,
      );
      final dynamic decoded = jsonDecode(plaintext);
      if (decoded is! Map) {
        return const ImportResult.failure(
          'Decrypted backup is invalid: expected a JSON object.',
        );
      }
      return validateImportMap(Map<String, dynamic>.from(decoded));
    } on ExportCryptoException catch (e) {
      return ImportResult.failure(e.message);
    } on FormatException {
      return const ImportResult.failure(
        'Incorrect PIN or passphrase. Your data was not changed.',
      );
    } catch (e) {
      debugPrint('Encrypted import error: $e');
      return const ImportResult.failure(
        'Incorrect PIN or passphrase. Your data was not changed.',
      );
    }
  }

  @visibleForTesting
  static ImportResult validateImportMap(Map<String, dynamic> data) {
    final validated = <String, dynamic>{};

    if (data.containsKey('schema_version')) {
      final version = data['schema_version'];
      if (version is! int) {
        return const ImportResult.failure(
            'Invalid backup file: schema_version must be a number.');
      }
      if (version > kExportSchemaVersion) {
        return const ImportResult.failure(
          'This backup was created by a newer app version. Please update the app and try again.',
        );
      }
      validated['schema_version'] = version;
    }

    if (data.containsKey(keyFasts)) {
      final raw = data[keyFasts];
      List<dynamic> list;
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! List) {
            return const ImportResult.failure(
                'Invalid backup file: fasts must be a list.');
          }
          list = decoded;
        } catch (_) {
          return const ImportResult.failure(
              'Invalid backup file: fasts JSON is malformed.');
        }
      } else if (raw is List) {
        list = raw;
      } else {
        return const ImportResult.failure(
            'Invalid backup file: fasts must be a list.');
      }
      final records = <Map<String, dynamic>>[];
      var activeCount = 0;
      for (final item in list) {
        if (item is! Map) continue;
        try {
          final record = FastRecord.fromJson(Map<String, dynamic>.from(item));
          if (record.endAt != null && record.endAt!.isBefore(record.startAt)) {
            continue;
          }
          if (record.isActive) activeCount++;
          if (activeCount > 1) {
            return const ImportResult.failure(
              'Invalid backup file: more than one active fast.',
            );
          }
          records.add(record.toJson());
        } catch (_) {
          continue;
        }
      }
      validated[keyFasts] = jsonEncode(records);
    }

    if (data.containsKey(keyCustomSchedules)) {
      final raw = data[keyCustomSchedules];
      List<dynamic> list;
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! List) {
            return const ImportResult.failure(
                'Invalid backup file: custom_schedules must be a list.');
          }
          list = decoded;
        } catch (_) {
          return const ImportResult.failure(
              'Invalid backup file: custom_schedules JSON is malformed.');
        }
      } else if (raw is List) {
        list = raw;
      } else {
        return const ImportResult.failure(
            'Invalid backup file: custom_schedules must be a list.');
      }
      final schedules = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is! Map) continue;
        final schedule = FastSchedule.fromJson(Map<String, dynamic>.from(item));
        if (schedule.id.isEmpty || schedule.name.trim().isEmpty) continue;
        schedules.add(schedule.copyWith(preset: false).toJson());
      }
      validated[keyCustomSchedules] = jsonEncode(schedules);
    }

    if (data.containsKey(keyHiddenScheduleIds)) {
      final raw = data[keyHiddenScheduleIds];
      if (raw is! List) {
        return const ImportResult.failure(
            'Invalid backup file: hidden_schedule_ids must be a list.');
      }
      validated[keyHiddenScheduleIds] = raw.map((e) => e.toString()).toList();
    }

    if (data.containsKey(keyActiveScheduleId)) {
      final raw = data[keyActiveScheduleId];
      if (raw is! String || raw.isEmpty) {
        return const ImportResult.failure(
            'Invalid backup file: active_schedule_id must be a string.');
      }
      validated[keyActiveScheduleId] = raw;
    }

    for (final key in [
      keyReminderEnabled,
      keyNotifyFastEnd,
      keyNotifyStages,
      keyDisclaimerAccepted,
    ]) {
      if (data.containsKey(key)) {
        final value = data[key];
        if (value is! bool) {
          return ImportResult.failure(
              'Invalid backup file: $key must be true or false.');
        }
        validated[key] = value;
      }
    }

    for (final key in [
      keyNotifyStartHour,
      keyNotifyStartMinute,
      keyAutoLockTimeoutSeconds,
    ]) {
      if (data.containsKey(key)) {
        final value = data[key];
        if (value is! int) {
          return ImportResult.failure(
              'Invalid backup file: $key must be a number.');
        }
        validated[key] = value;
      }
    }

    if (data.containsKey(keyEatingUntil) && data[keyEatingUntil] != null) {
      final raw = data[keyEatingUntil];
      if (raw is! String) {
        return const ImportResult.failure(
            'Invalid backup file: eating_until must be a string.');
      }
      validated[keyEatingUntil] = raw;
    }

    return ImportResult.success(validated);
  }

  static Future<void> applyImport(Map<String, dynamic> validated) async {
    await _store.applyMap(validated);
    await rescheduleNotifications();
  }

  static Future<void> rescheduleNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      final settings = await getSettings();
      if (!settings.reminderEnabled) return;

      final active = await getActiveFast();
      final now = tz.TZDateTime.now(tz.local);

      if (active != null) {
        if (settings.notifyFastEnd && active.goalMinutes > 0) {
          final goalAt = tz.TZDateTime.from(
            active.startAt.add(Duration(minutes: active.goalMinutes)),
            tz.local,
          );
          if (goalAt.isAfter(now)) {
            await _scheduleNotification(
              id: _notificationIdFastEnd,
              scheduledDate: goalAt,
              title: 'Eating window is open',
              body:
                  'Your ${active.scheduleName} fast reached its goal. End it when you are ready.',
            );
          }
        }
        if (settings.notifyStages) {
          var slot = 0;
          for (final hours in FastingStages.notifyBoundaries) {
            final at = tz.TZDateTime.from(
              active.startAt.add(Duration(minutes: (hours * 60).round())),
              tz.local,
            );
            if (!at.isAfter(now)) continue;
            final stage = FastingStages.forElapsed(
              Duration(minutes: (hours * 60).round()),
            );
            if (stage == null) continue;
            await _scheduleNotification(
              id: _stageNotificationBase + slot,
              scheduledDate: at,
              title: 'Fasting stage: ${stage.title}',
              body: stage.summary,
            );
            slot++;
            if (slot >= 8) break;
          }
        }
        return;
      }

      if (settings.notifyFastEnd) {
        final eatingUntil = await getEatingUntil();
        if (eatingUntil != null) {
          final at = tz.TZDateTime.from(eatingUntil, tz.local);
          if (at.isAfter(now)) {
            await _scheduleNotification(
              id: _notificationIdEatingEnd,
              scheduledDate: at,
              title: 'Time to start your next fast',
              body: 'Your eating window is ending.',
            );
          }
        }
      }

      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        settings.notifyStartHour,
        settings.notifyStartMinute,
      );
      if (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }
      await _scheduleNotification(
        id: _notificationIdDailyStart,
        scheduledDate: next,
        title: 'Start your fast',
        body: 'Tavryn is ready when you are.',
        match: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Reminder reschedule skipped: $e');
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String title,
    required String body,
    DateTimeComponents? match,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fasting_reminders',
      'Fasting reminders',
      channelDescription: 'Start, end, and stage reminders for your fast',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    // Inexact idle alarms are batched by Android and commonly arrive about
    // 15 minutes late. Fasting alerts have to fire at the scheduled instant.
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }
}
