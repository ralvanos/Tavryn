import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/fast_storage.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'trends_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.onPinSettingsChanged});

  final VoidCallback? onPinSettingsChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _trendsKey = GlobalKey<TrendsScreenState>();
  bool _disclaimerReady = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadDisclaimer();
  }

  Future<void> _loadDisclaimer() async {
    final settings = await FastStorage.getSettings();
    if (!mounted) return;
    setState(() {
      _accepted = settings.disclaimerAccepted;
      _disclaimerReady = true;
    });
  }

  void _refreshOthers() {
    _homeKey.currentState?.reload();
    _historyKey.currentState?.reload();
    _trendsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_disclaimerReady) {
      return const Scaffold(
        backgroundColor: TavrynColors.ink,
        body: Center(
          child: CircularProgressIndicator(color: TavrynColors.ember),
        ),
      );
    }

    if (!_accepted) {
      return Scaffold(
        backgroundColor: TavrynColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Text(
                  'Tavryn',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A private fasting timer. One job.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  kMedicalDisclaimer,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    await FastStorage.setDisclaimerAccepted(true);
                    if (!mounted) return;
                    setState(() => _accepted = true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: TavrynColors.ember,
                    foregroundColor: const Color(0xFF1A1208),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'I understand',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(key: _homeKey, onChanged: _refreshOthers),
          HistoryScreen(key: _historyKey, onChanged: _refreshOthers),
          TrendsScreen(key: _trendsKey),
          SettingsScreen(
            onPinSettingsChanged: widget.onPinSettingsChanged,
            onSchedulesChanged: _refreshOthers,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: TavrynColors.inkElevated,
        indicatorColor: TavrynColors.ember.withValues(alpha: 0.22),
        onDestinationSelected: (value) {
          setState(() => _index = value);
          if (value == 0) _homeKey.currentState?.reload();
          if (value == 1) _historyKey.currentState?.reload();
          if (value == 2) _trendsKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nights_stay_outlined),
            selectedIcon: Icon(Icons.nights_stay),
            label: 'Fast',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
