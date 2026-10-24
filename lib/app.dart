import 'package:flutter/material.dart';

import 'screens/pin_lock_screen.dart';
import 'screens/shell.dart';
import 'services/auto_lock_policy.dart';
import 'services/fast_storage.dart';
import 'services/pin_service.dart';
import 'theme.dart';

class TavrynApp extends StatefulWidget {
  const TavrynApp({super.key});

  @override
  State<TavrynApp> createState() => _TavrynAppState();
}

class _TavrynAppState extends State<TavrynApp> with WidgetsBindingObserver {
  bool _pinEnabled = false;
  bool _unlocked = true;
  bool _ready = false;
  int _autoLockSeconds = AutoLockPolicy.defaultTimeoutSeconds;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPinState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FastStorage.ensureExactAlarms();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPinState({bool preserveSession = false}) async {
    final enabled = await PinService.instance.isEnabled();
    final autoLock = await FastStorage.getAutoLockTimeoutSeconds();
    if (!mounted) return;
    setState(() {
      _pinEnabled = enabled;
      _autoLockSeconds = autoLock;
      if (!preserveSession) {
        _unlocked = !enabled;
      } else if (!enabled) {
        _unlocked = true;
      }
      _ready = true;
    });
  }

  void refreshPinLock() {
    _loadPinState(preserveSession: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_pinEnabled) return;

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      if (AutoLockPolicy.lockImmediatelyOnPause(_autoLockSeconds) &&
          _unlocked) {
        setState(() => _unlocked = false);
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_unlocked &&
          AutoLockPolicy.shouldLockOnResume(
            timeoutSeconds: _autoLockSeconds,
            pausedAt: _pausedAt,
            now: DateTime.now(),
          )) {
        setState(() => _unlocked = false);
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tavryn',
      debugShowCheckedModeBanner: false,
      theme: TavrynTheme.dark(),
      home: !_ready
          ? const Scaffold(
              backgroundColor: TavrynColors.ink,
              body: Center(
                child: CircularProgressIndicator(color: TavrynColors.ember),
              ),
            )
          : (_pinEnabled && !_unlocked)
              ? PinLockScreen(
                  onUnlocked: () {
                    setState(() => _unlocked = true);
                  },
                )
              : MainShell(onPinSettingsChanged: refreshPinLock),
    );
  }
}
