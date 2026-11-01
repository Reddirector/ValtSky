import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/prefs.dart';
import '../main.dart';
import '../util/theme.dart';
import '../util/media_scanner.dart';
import 'views/dashboard_view.dart';
import 'views/activity_view.dart';
import 'views/settings_view.dart';
import 'widgets/passive_elements.dart';
import 'widgets/valtsky_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final GlobalKey<DashboardViewState> _dashboardKey = GlobalKey<DashboardViewState>();
  final GlobalKey<ActivityViewState> _activityKey = GlobalKey<ActivityViewState>();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    if (kIsWeb) {
      await MediaScanner.scanForNewMedia();
    }
    _dashboardKey.currentState?.refreshStats();
    _activityKey.currentState?.refreshItems();
  }

  void _onDataChanged() {
    _dashboardKey.currentState?.refreshStats();
    _activityKey.currentState?.refreshItems();
    setState(() {});
  }

  Future<void> _handleGlobalRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await MediaScanner.scanForNewMedia();
      _onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Media scan complete — all counts updated'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _navigateToActivityWithFilter(String? filter) {
    setState(() => _currentIndex = 1);
    if (filter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _activityKey.currentState?.setFilter(filter);
      });
    }
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return DashboardView(
          key: _dashboardKey,
          onNavigateToSettings: () => setState(() => _currentIndex = 2),
          onNavigateToActivity: _navigateToActivityWithFilter,
        );
      case 1:
        return ActivityView(
          key: _activityKey,
          onDataChanged: _onDataChanged,
        );
      case 2:
      default:
        return SettingsView(
          onDataChanged: _onDataChanged,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMonitoring = Prefs.monitoringEnabled;
    final isPaused = Prefs.uploadPaused;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              titleSpacing: 20,
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const ValtSkyLogo(size: 30),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ValtSky',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  if (isMonitoring)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isPaused ? ValtSkyTheme.warning : ValtSkyTheme.success)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AmbientRadarDot(
                            color: isPaused ? ValtSkyTheme.warning : ValtSkyTheme.success,
                            size: 6,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPaused ? 'PAUSED' : 'ONLINE',
                            style: TextStyle(
                              color: isPaused ? ValtSkyTheme.warning : ValtSkyTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Scan Gallery',
                  icon: _isRefreshing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  onPressed: _handleGlobalRefresh,
                ),
                IconButton(
                  tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                  icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                  onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: _buildCurrentTab(),
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  if (index == 0) _dashboardKey.currentState?.refreshStats();
                  if (index == 1) _activityKey.currentState?.refreshItems();
                },
                backgroundColor: isDark ? const Color(0xFF09090B) : Colors.white,
                indicatorColor: isDark ? Colors.white : Colors.black,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.cloud_outlined, color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    selectedIcon: Icon(Icons.cloud_rounded, color: isDark ? Colors.black : Colors.white),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.format_list_bulleted_rounded, color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    selectedIcon: Icon(Icons.fact_check_rounded, color: isDark ? Colors.black : Colors.white),
                    label: 'Queue & Activity',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined, color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    selectedIcon: Icon(Icons.tune_rounded, color: isDark ? Colors.black : Colors.white),
                    label: 'Settings',
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
