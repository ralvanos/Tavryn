# Privacy Policy

**Tavryn** is a standalone, offline Android fasting timer. This policy describes how the app handles information.

## Data collection

The app does **not** collect, transmit, or share personal data. There are no analytics, crash reporters, advertising SDKs, or backend APIs.

## Data storage

All data stays on your device:

- Fast start/end times, schedule snapshots, and optional notes
- Custom schedules and hidden-preset choices
- Reminder preferences
- Optional app PIN (stored only as a salted hash — never in plaintext)
- Exported backup files (only when you choose to save them)

Imported backups may include a leftover `feeling` field from an older format or another app. Tavryn does not ask for a mood rating.

**On-device encryption:** User data is encrypted at rest (AES-CBC). The data-encryption key is kept in Android Keystore-backed secure storage (`flutter_secure_storage`).

**Optional PIN lock:** You may enable a 4–6 digit PIN in More → Security. When enabled, the app asks for the PIN on open and after the configured **Auto-lock** delay. Failed attempts are briefly throttled; the app does **not** wipe your data.

**Exports:** More → Export saves a JSON backup. PIN-protect is optional at export time (`format: enc_export_v1`: PBKDF2 + AES-CBC). Treat a plaintext export like any other personal document. On-device encryption does not protect a plaintext file you save elsewhere.

There is no cloud sync. Backup export/import uses the system file picker; the app does not upload files anywhere.

## Network access

The **release** app does not declare the `INTERNET` permission and does not make HTTP requests or connect to remote servers. Core use is fully offline.

Optional actions may open external apps (for example, your email client for feedback). Those interactions are handled by the system and are outside this app. Debug/profile builds include internet permission only so Flutter tooling (hot reload) can talk to the device.

## Notifications

If you enable reminders, the app schedules local notifications on your device only. No notification data is sent to third parties. Reminders use exact alarms so they fire at the scheduled time, including while the phone is idle.

## Permissions

- **Notifications** — optional, for fasting reminders
- **Exact alarms** — so a reminder fires at the scheduled time, including while the phone is idle
- **Boot completed** — reschedule local reminders after device restart
- **Vibrate** — vibration for those reminders
- **Storage / file picker** — only when you export or import a backup

The release APK does not request network access.

## Contact

Questions about privacy: [ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)

## Changes

This policy may be updated as the app evolves. The current version applies to the open-source release in this repository.
