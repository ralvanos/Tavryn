import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../services/auto_lock_policy.dart';
import '../services/fast_storage.dart';
import '../services/pin_service.dart';
import '../theme.dart';
import 'pin_lock_screen.dart';
import 'schedules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onPinSettingsChanged,
    this.onSchedulesChanged,
  });

  final VoidCallback? onPinSettingsChanged;
  final VoidCallback? onSchedulesChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  FastSettings? _settings;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await FastStorage.getSettings();
    final pin = await PinService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _pinEnabled = pin;
    });
  }

  Future<void> _persist(FastSettings settings) async {
    await FastStorage.saveSettings(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await PinDialogs.promptExport(context);
    if (choice == null) return;
    final result = await FastStorage.exportData(passphrase: choice.passphrase);
    if (!mounted) return;
    final message = switch (result) {
      ExportResult.success =>
        choice.pinProtected ? 'PIN-protected backup saved' : 'Backup saved',
      ExportResult.cancelled => 'Export cancelled',
      ExportResult.failure => 'Export failed',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final parsed = await FastStorage.pickAndParseImport();
    if (!mounted) return;
    var result = parsed;
    if (result.needsPassphrase) {
      final pin = await PinDialogs.promptImportPassphrase(context);
      if (pin == null) return;
      result = FastStorage.decryptAndValidateImport(
        encryptedEnvelope: result.encryptedEnvelope!,
        passphrase: pin,
      );
    }
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Import failed')),
      );
      return;
    }
    await FastStorage.applyImport(result.data!);
    if (!mounted) return;
    widget.onSchedulesChanged?.call();
    widget.onPinSettingsChanged?.call();
    await _load();
    messenger.showSnackBar(
      const SnackBar(content: Text('Backup imported')),
    );
  }

  Future<void> _mail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: kFeedbackEmail,
      query: 'subject=Tavryn feedback',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Center(
        child: CircularProgressIndicator(color: TavrynColors.ember),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'More',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedules, reminders, lock, and backups. Everything stays on this device.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Schedules'),
          SchedulesScreen(
            embedded: true,
            onChanged: widget.onSchedulesChanged,
          ),
          const _SectionTitle('Notifications'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.reminderEnabled,
            activeThumbColor: TavrynColors.ember,
            title: const Text('Fasting reminders'),
            subtitle: Text(
              FastStorage.notificationsPermissionGranted
                  ? 'Local only. Nothing is sent off the device.'
                  : 'Notification permission is off. Enable it in system settings.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
            onChanged: (value) => _persist(
              FastSettings(
                reminderEnabled: value,
                notifyFastEnd: settings.notifyFastEnd,
                notifyStages: settings.notifyStages,
                notifyStartHour: settings.notifyStartHour,
                notifyStartMinute: settings.notifyStartMinute,
                autoLockTimeoutSeconds: settings.autoLockTimeoutSeconds,
                disclaimerAccepted: settings.disclaimerAccepted,
              ),
            ),
          ),
          if (settings.reminderEnabled) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.notifyFastEnd,
              activeThumbColor: TavrynColors.ember,
              title: const Text('Goal and eating-window alerts'),
              onChanged: (value) => _persist(
                FastSettings(
                  reminderEnabled: settings.reminderEnabled,
                  notifyFastEnd: value,
                  notifyStages: settings.notifyStages,
                  notifyStartHour: settings.notifyStartHour,
                  notifyStartMinute: settings.notifyStartMinute,
                  autoLockTimeoutSeconds: settings.autoLockTimeoutSeconds,
                  disclaimerAccepted: settings.disclaimerAccepted,
                ),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.notifyStages,
              activeThumbColor: TavrynColors.ember,
              title: const Text('Stage milestones'),
              subtitle: Text(
                'Optional notices at 12h, 14h, 16h, 18h, 24h, 36h, 48h, and 72h.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              ),
              onChanged: (value) => _persist(
                FastSettings(
                  reminderEnabled: settings.reminderEnabled,
                  notifyFastEnd: settings.notifyFastEnd,
                  notifyStages: value,
                  notifyStartHour: settings.notifyStartHour,
                  notifyStartMinute: settings.notifyStartMinute,
                  autoLockTimeoutSeconds: settings.autoLockTimeoutSeconds,
                  disclaimerAccepted: settings.disclaimerAccepted,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily start reminder'),
              subtitle: Text(
                TimeOfDay(
                  hour: settings.notifyStartHour,
                  minute: settings.notifyStartMinute,
                ).format(context),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: settings.notifyStartHour,
                    minute: settings.notifyStartMinute,
                  ),
                );
                if (picked == null) return;
                await _persist(
                  FastSettings(
                    reminderEnabled: settings.reminderEnabled,
                    notifyFastEnd: settings.notifyFastEnd,
                    notifyStages: settings.notifyStages,
                    notifyStartHour: picked.hour,
                    notifyStartMinute: picked.minute,
                    autoLockTimeoutSeconds: settings.autoLockTimeoutSeconds,
                    disclaimerAccepted: settings.disclaimerAccepted,
                  ),
                );
              },
            ),
          ],
          const _SectionTitle('Security'),
          Text(
            'Optional ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN. '
            'Stored as a salted hash. User data is encrypted at rest separately.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _pinEnabled,
            activeThumbColor: TavrynColors.ember,
            title: const Text('Require PIN'),
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              if (value) {
                final pin = await PinDialogs.promptNewPin(
                  context,
                  title: 'Set PIN',
                );
                if (pin == null) return;
                await PinService.instance.setPin(pin);
                if (!mounted) return;
                setState(() => _pinEnabled = true);
                widget.onPinSettingsChanged?.call();
                messenger.showSnackBar(
                  const SnackBar(content: Text('PIN lock enabled')),
                );
              } else {
                final current = await PinDialogs.promptCurrentPin(
                  context,
                  title: 'Confirm PIN to turn off',
                );
                if (current == null) return;
                try {
                  await PinService.instance.disablePin(current);
                  if (!mounted) return;
                  setState(() => _pinEnabled = false);
                  widget.onPinSettingsChanged?.call();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('PIN lock disabled')),
                  );
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                }
              }
            },
          ),
          if (_pinEnabled) ...[
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final current = await PinDialogs.promptCurrentPin(
                  context,
                  title: 'Enter current PIN',
                );
                if (current == null) return;
                if (!context.mounted) return;
                final next = await PinDialogs.promptNewPin(
                  context,
                  title: 'Choose new PIN',
                );
                if (next == null) return;
                try {
                  await PinService.instance.changePin(
                    currentPin: current,
                    newPin: next,
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('PIN changed')),
                  );
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                }
              },
              child: const Text('Change PIN'),
            ),
            const Text('Auto-lock'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey(settings.autoLockTimeoutSeconds),
              initialValue: settings.autoLockTimeoutSeconds,
              dropdownColor: TavrynColors.card,
              decoration: InputDecoration(
                isDense: true,
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: TavrynColors.ember),
                ),
              ),
              items: [
                for (final seconds in AutoLockPolicy.allowedTimeoutSeconds)
                  DropdownMenuItem(
                    value: seconds,
                    child: Text(AutoLockPolicy.labelForTimeout(seconds)),
                  ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await FastStorage.setAutoLockTimeoutSeconds(value);
                widget.onPinSettingsChanged?.call();
                await _load();
              },
            ),
          ],
          const _SectionTitle('Backup'),
          Text(
            'Import and export JSON on this device. You can PIN-protect a file when you export it. A plaintext backup is not protected once you save it elsewhere.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _import,
                  child: const Text('Import'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _export,
                  child: const Text('Export'),
                ),
              ),
            ],
          ),
          const _SectionTitle('About'),
          Text(
            kMedicalDisclaimer,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            kSupportTheAppMessage,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.35,
              fontSize: 13,
            ),
          ),
          TextButton.icon(
            onPressed: _mail,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Send feedback'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bitcoin'),
            subtitle: const Text(kDonateBtcAddress),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: kDonateBtcAddress));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitcoin address copied')),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Monero'),
            subtitle: const Text(kDonateXmrAddress),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: kDonateXmrAddress));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Monero address copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
