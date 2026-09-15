import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavryn/models/fast_record.dart';
import 'package:tavryn/models/fast_schedule.dart';
import 'package:tavryn/models/fasting_math.dart';
import 'package:tavryn/models/fasting_stage.dart';
import 'package:tavryn/services/auto_lock_policy.dart';
import 'package:tavryn/services/encrypted_store.dart';
import 'package:tavryn/services/export_crypto.dart';
import 'package:tavryn/services/fast_storage.dart';
import 'package:tavryn/services/key_vault.dart';
import 'package:tavryn/services/pin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FastingMath', () {
    test('progress clamps to 1 at and beyond goal', () {
      expect(
        FastingMath.progress(
          goalMinutes: 60,
          elapsed: const Duration(minutes: 30),
        ),
        0.5,
      );
      expect(
        FastingMath.progress(
          goalMinutes: 60,
          elapsed: const Duration(minutes: 90),
        ),
        1.0,
      );
    });

    test('flexi progress wraps every 24 hours', () {
      final p = FastingMath.progress(
        goalMinutes: 0,
        elapsed: const Duration(hours: 30),
      );
      expect(p, closeTo(6 / 24, 0.0001));
    });

    test('metGoal for timed and flexi', () {
      expect(
        FastingMath.metGoal(
          goalMinutes: 16 * 60,
          elapsed: const Duration(hours: 16),
        ),
        isTrue,
      );
      expect(
        FastingMath.metGoal(
          goalMinutes: 16 * 60,
          elapsed: const Duration(hours: 15),
        ),
        isFalse,
      );
      expect(
        FastingMath.metGoal(
          goalMinutes: 0,
          elapsed: const Duration(minutes: 1),
        ),
        isTrue,
      );
    });

    test('ratioLabel uses hours not clock time', () {
      expect(FastSchedule.presetById('14-10')!.ratioLabel, '14h/10h');
      expect(FastSchedule.presetById('16-8')!.ratioLabel, '16h/8h');
      expect(FastSchedule.presetById('omad')!.ratioLabel, '23h/1h');
      expect(FastSchedule.presetById('flexi')!.ratioLabel, 'Flexi');
    });

    test('matching prefers known schedule over stored name', () {
      final matched = FastSchedule.matching(
        id: '14-10',
        name: '16h/8h',
        goalMinutes: 16 * 60,
        known: FastSchedule.presets,
      );
      expect(matched.ratioLabel, '14h/10h');
      expect(matched.fastMinutes, 14 * 60);
      expect(matched.eatMinutes, 10 * 60);
    });

    test('formatDuration pads hours', () {
      expect(
        FastingMath.formatDuration(
            const Duration(hours: 2, minutes: 5, seconds: 9)),
        '02:05:09',
      );
    });

    test('formatClock24 is 24-hour', () {
      expect(
        FastingMath.formatClock24(DateTime(2026, 9, 14, 9, 5)),
        '09:05',
      );
      expect(
        FastingMath.formatClock24(DateTime(2026, 9, 14, 19, 30)),
        '19:30',
      );
    });

    test('nextFastAtLabel uses clock time not a countdown', () {
      final now = DateTime(2026, 9, 14, 12, 0);
      expect(
        FastingMath.nextFastAtLabel(DateTime(2026, 9, 14, 19, 0), now: now),
        'Next fast at 19:00',
      );
      expect(
        FastingMath.nextFastAtLabel(DateTime(2026, 9, 15, 7, 30), now: now),
        'Next fast at 07:30 tomorrow',
      );
    });

    test('endsAtLabel is a quiet date and time under remaining', () {
      final now = DateTime(2026, 9, 14, 19, 5);
      expect(
        FastingMath.endsAtLabel(DateTime(2026, 9, 14, 9, 4), now: now),
        'Ends at 09:04',
      );
      expect(
        FastingMath.endsAtLabel(DateTime(2026, 9, 15, 9, 4), now: now),
        'Ends tomorrow at 09:04',
      );
      expect(
        FastingMath.endsAtLabel(DateTime(2026, 9, 16, 9, 4), now: now),
        'Ends Sep 16 at 09:04',
      );
      expect(
        FastingMath.endsAtLabel(
          DateTime(2026, 9, 14, 9, 4),
          now: now,
          overtime: true,
        ),
        'Goal at 09:04',
      );
    });

    test('streak counts consecutive covered days from today', () {
      final now = DateTime(2026, 9, 14, 12);
      final records = [
        FastRecord(
          id: 'a',
          startAt: DateTime(2026, 9, 13, 20),
          endAt: DateTime(2026, 9, 14, 12),
          scheduleId: '16-8',
          scheduleName: '16:8',
          goalMinutes: 16 * 60,
        ),
        FastRecord(
          id: 'b',
          startAt: DateTime(2026, 9, 12, 20),
          endAt: DateTime(2026, 9, 13, 12),
          scheduleId: '16-8',
          scheduleName: '16:8',
          goalMinutes: 16 * 60,
        ),
      ];
      final stats = FastingMath.compute(records, now: now);
      expect(stats.currentStreakDays, 3);
      expect(stats.completedCount, 2);
      expect(stats.longestHours, 16);
    });

    test('period stats count hours, days, and sessions', () {
      final now = DateTime(2026, 9, 14, 12);
      final records = [
        FastRecord(
          id: 'sep',
          startAt: DateTime(2026, 9, 14, 0),
          endAt: DateTime(2026, 9, 14, 10),
          scheduleId: '16-8',
          scheduleName: '16h/8h',
          goalMinutes: 16 * 60,
        ),
        FastRecord(
          id: 'aug',
          startAt: DateTime(2026, 8, 1, 8),
          endAt: DateTime(2026, 8, 1, 20),
          scheduleId: '14-10',
          scheduleName: '14h/10h',
          goalMinutes: 14 * 60,
        ),
      ];
      final stats = FastingMath.compute(records, now: now);
      expect(stats.sessionCount, 2);
      expect(stats.daysFasted, 2);
      expect(stats.week.sessions, 1);
      expect(stats.week.hours, 10);
      expect(stats.week.daysFasted, 1);
      expect(stats.month.sessions, 1);
      expect(stats.year.sessions, 2);
      expect(stats.year.hours, 22);
    });

    test('timeline stage at 16 hours is ketones', () {
      final stage = FastingStages.forElapsed(const Duration(hours: 16));
      expect(stage?.id, 'ketones');
      expect(stage?.timeLabel, '16-18 Hours');
    });

    test('timeline is empty before 12 hours', () {
      expect(
        FastingStages.forElapsed(const Duration(hours: 11)),
        isNull,
      );
    });

    test('progressThrough fills the current stage', () {
      final stage = FastingStages.all.firstWhere((s) => s.id == 'ketones');
      expect(stage.progressThrough(16), 0);
      expect(stage.progressThrough(17), 0.5);
      expect(stage.progressThrough(18), 1);
    });

    test('3-5 day stage is peak rejuvenation', () {
      final stage = FastingStages.forElapsed(const Duration(hours: 80));
      expect(stage?.id, 'peak');
    });
  });

  group('PinService', () {
    late PinService pin;

    setUp(() {
      pin = PinService(keyVault: InMemoryKeyVault());
      PinService.resetInstanceForTest(pin);
    });

    tearDown(() {
      PinService.resetInstanceForTest();
    });

    test('set and verify PIN', () async {
      await pin.setPin('2468');
      expect(await pin.isEnabled(), isTrue);
      expect(await pin.verifyPin('2468'), isTrue);
      expect(await pin.verifyPin('0000'), isFalse);
    });

    test('throttle after repeated failures', () async {
      await pin.setPin('1234');
      for (var i = 0; i < PinService.failThrottleAfter; i++) {
        expect(await pin.verifyPin('0000'), isFalse);
      }
      expect(pin.throttleRemaining(), isNotNull);
      expect(await pin.verifyPin('1234'), isFalse);
    });
  });

  group('EncryptedStore', () {
    tearDown(() {
      EncryptedStore.resetInstanceForTest();
    });

    test('round-trip string values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = EncryptedStore(
        keyVault: InMemoryKeyVault(),
        prefs: prefs,
      );
      EncryptedStore.resetInstanceForTest(store);
      await store.setString('fasts', '[]');
      expect(await store.getString('fasts'), '[]');
      final blob = prefs.getString(EncryptedStore.blobPrefsKey);
      expect(blob, isNotNull);
      expect(blob, isNot(contains('fasts')));
    });
  });

  group('ExportCrypto', () {
    test('encrypt decrypt round-trip', () {
      const plaintext = '{"schema_version":1,"fasts":"secret"}';
      final envelope = ExportCrypto.encryptExport(
        plaintextJson: plaintext,
        passphrase: '2468',
      );
      expect(envelope['format'], ExportCrypto.formatId);
      expect(jsonEncodeSafe(envelope), isNot(contains('secret')));
      expect(
        ExportCrypto.decryptExport(envelope: envelope, passphrase: '2468'),
        plaintext,
      );
    });

    test('wrong passphrase fails', () {
      final envelope = ExportCrypto.encryptExport(
        plaintextJson: '{"ok":true}',
        passphrase: 'correct',
      );
      expect(
        () => ExportCrypto.decryptExport(
          envelope: envelope,
          passphrase: 'wrong1',
        ),
        throwsA(isA<ExportCryptoException>()),
      );
    });
  });

  group('FastStorage import', () {
    test('rejects future schema', () {
      final result = FastStorage.validateImportMap({
        'schema_version': 99,
        'fasts': '[]',
      });
      expect(result.success, isFalse);
    });

    test('accepts valid fasts list', () {
      final result = FastStorage.validateImportMap({
        'schema_version': 1,
        'fasts': [
          {
            'id': '1',
            'startAt': '2026-09-01T20:00:00.000',
            'endAt': '2026-09-02T12:00:00.000',
            'scheduleId': '16-8',
            'scheduleName': '16:8',
            'goalMinutes': 960,
          }
        ],
      });
      expect(result.success, isTrue);
      expect(result.data, isNotNull);
    });

    test('encrypted envelope needs passphrase', () {
      final result = FastStorage.parseImportMap({
        'format': 'enc_export_v1',
        'ciphertext': 'x',
      });
      expect(result.needsPassphrase, isTrue);
    });
  });

  group('FastStorage eating window', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      EncryptedStore.resetInstanceForTest(
        EncryptedStore(keyVault: InMemoryKeyVault(), prefs: prefs),
      );
    });

    tearDown(() {
      EncryptedStore.resetInstanceForTest();
    });

    test('deleting the only ended fast clears the eating window', () async {
      final schedule = FastSchedule.presetById('16-8')!;
      final record = await FastStorage.startFast(schedule: schedule);
      await FastStorage.endFast(id: record.id);
      expect(await FastStorage.getEatingUntil(), isNotNull);

      await FastStorage.deleteFast(record.id);
      expect(await FastStorage.getEatingUntil(), isNull);
      expect(await FastStorage.getActiveFast(), isNull);
    });

    test('deleting an active fast leaves no countdown', () async {
      final schedule = FastSchedule.presetById('16-8')!;
      final record = await FastStorage.startFast(schedule: schedule);
      await FastStorage.deleteFast(record.id);
      expect(await FastStorage.getActiveFast(), isNull);
      expect(await FastStorage.getEatingUntil(), isNull);
    });
  });

  group('AutoLockPolicy', () {
    test('immediate lock on pause', () {
      expect(AutoLockPolicy.lockImmediatelyOnPause(0), isTrue);
      expect(AutoLockPolicy.lockImmediatelyOnPause(30), isFalse);
    });

    test('resume lock after timeout', () {
      final paused = DateTime(2026, 9, 14, 12, 0, 0);
      expect(
        AutoLockPolicy.shouldLockOnResume(
          timeoutSeconds: 60,
          pausedAt: paused,
          now: paused.add(const Duration(seconds: 59)),
        ),
        isFalse,
      );
      expect(
        AutoLockPolicy.shouldLockOnResume(
          timeoutSeconds: 60,
          pausedAt: paused,
          now: paused.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
    });
  });
}

String jsonEncodeSafe(Map<String, dynamic> map) {
  return map.toString();
}
