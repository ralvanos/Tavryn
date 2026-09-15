# Tavryn

**Version:** 1.0.0+1 — see [RELEASE_NOTES.md](RELEASE_NOTES.md).

An **Android-only**, **offline** intermittent fasting timer. Tavryn does one job: start, watch, edit, and remember your fasts. No accounts, no ads, no weight/calorie extras. All data stays on your device and is encrypted at rest.

> **Not medical advice.** Fasting is not appropriate for everyone. Read the in-app disclaimer and talk to a clinician if you are pregnant, breastfeeding, under 18, on medication, or have a history of eating disorders.

## Features

* **Live fasting ring** — elapsed time, remaining time, and a quiet clock for when the goal lands
* **Predefined schedules** — `12h/12h`, `14h/10h`, `16h/8h`, `18h/6h`, `20h/4h`, OMAD, 36h, 48h, 72h, and Flexi (open-ended)
* **Custom schedules** — create, edit, or delete your own protocols; hide presets you do not use
* **Edit anything** — change the start of a live fast; swipe-delete or edit history (day, time, protocol, optional note)
* **Eating window** — after a timed fast ends, see the countdown and next-fast clock time
* **Fasting timeline** — bottom sheet, 12h through 3–5 days, guidance-only stage copy
* **Trends** — streaks, longest, total, hit-goal %, averages, session counts, days fasted, week/month/year, weekly chart, 12-week heatmap
* **Notifications** — optional local reminders for daily start, goal reached, eating-window end, and stage milestones
* **On-device encryption** — AES-CBC user-data blob; DEK in Android Keystore via `flutter_secure_storage`
* **Optional PIN lock** — 4–6 digit PIN; auto-lock Immediate / 30s / 1m / 5m; salted hash only
* **Backup & restore** — More → Import / Export. PIN-protect is optional on export (`enc_export_v1`)

## Why these extras

Tavryn stays a fasting app. A couple of fasting-only extras earned their place:

* **Optional note** when you end a fast
* **“Already started”** so a missed Start tap does not lose the session
* **First-run disclaimer** so the timer is never confused with treatment

Weight, water, photos, calories, and meal logging were left out on purpose. There is no 1–5 mood rating.

## Requirements

* Flutter SDK (stable channel)
* Android SDK
* Android device or emulator

Android-only. No backend. iOS / desktop / web folders are not maintained.

## Setup

```bash
flutter pub get
flutter test
flutter run
```

Debug APK:

```bash
flutter build apk --debug
```

Release APK (needs a project-specific keystore at `android/app/tavryn.jks` and `android/key.properties`, both gitignored):

```bash
flutter build apk --release
```

## What not to commit

These stay on your machine (see `.gitignore`):

* `android/key.properties` and `*.jks` / `*.keystore`
* `*.apk` / `*.aab`
* Backup and import files (`*backup*.json`, `tavryn_import*.json`, `tools/*.json`, `tools/*.tsv`)

`tools/merge_fasts.py` is a generic TSV→JSON helper with no user data. Do not commit the JSON/TSV it reads or writes.

## Project structure

* `lib/main.dart` — entry, encrypted store + notifications init
* `lib/app.dart` — theme and PIN auto-lock
* `lib/models/` — schedules, fast records, stages, stats math
* `lib/services/fast_storage.dart` — encrypted CRUD, export/import, notifications
* `lib/services/encrypted_store.dart` — AES-CBC blob
* `lib/services/pin_service.dart` — optional PIN
* `lib/screens/` — Fast, History, Trends, More
* `android/app/src/main/kotlin/.../MainActivity.kt` — Flutter activity shell only
* `test/` — math, encryption, PIN, import validation

## Privacy

See [PRIVACY.md](PRIVACY.md). Short version: local only, encrypted at rest, no analytics. The release APK does not request internet permission.

## License

MIT — see [LICENSE](LICENSE).
