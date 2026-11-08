import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_engine.dart';
import '../services/background_service.dart';
import '../main.dart';
import '../util/theme.dart';
import '../util/media_scanner.dart';
import '../util/permission_manager.dart';
import '../data/prefs.dart';
import 'views/dashboard_view.dart';
import 'views/activity_view.dart';
import 'views/settings_view.dart';
import 'widgets/valtsky_logo.dart';
import 'widgets/interactive_spotlight_tutorial.dart';
import 'widgets/app_walkthrough_guide.dart';
import 'widgets/animated_stagger.dart';
import 'widgets/valtsky_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final PageController _pageController;
  final GlobalKey<DashboardViewState> _dashboardKey = GlobalKey<DashboardViewState>();
  final GlobalKey<ActivityViewState> _activityKey = GlobalKey<ActivityViewState>();
  bool _isRefreshing = false;
  bool _isTutorialActive = false;
  int _tutorialStep = 1;
  bool _isLocked = false;
  final TextEditingController _unlockPinController = TextEditingController();
  String? _unlockErrorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    if (Prefs.vaultPinEnabled && Prefs.hasVaultPin && !_isTest) {
      _isLocked = true;
    }
    _initApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLocked) {
        _checkPermissionsOnFirstLaunch();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Prefs.vaultPinEnabled && Prefs.hasVaultPin && !_isTest) {
        if (!_isLocked) {
          setState(() => _isLocked = true);
        }
      }
    }
  }

  Future<void> _checkPermissionsOnFirstLaunch() async {
    if (!mounted || _isTest) return;
    if (!Prefs.permissionsRequested) {
      await PermissionManager.showPermissionOnboardingModal(
        context,
        onComplete: () {
          _onDataChanged();
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _unlockPinController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    if (kIsWeb) {
      await MediaScanner.scanForNewMedia();
    }
    _dashboardKey.currentState?.refreshStats();
    _activityKey.currentState?.refreshItems();

    // Auto-resume background monitoring if configured and monitoring was enabled
    if (Prefs.isConfigured() && Prefs.monitoringEnabled) {
      if (!kIsWeb) {
        try {
          await BackgroundService.start();
        } catch (e) {
          debugPrint('Error starting background service: $e');
        }
      }
    }

    // Always ensure queue uploader is active for pending items unless explicitly paused
    if (Prefs.isConfigured() && !Prefs.uploadPaused) {
      SyncEngine().startSync();
    }
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
      final newCount = await MediaScanner.scanForNewMedia();
      await SyncEngine.fetchCurrentStats(forceDb: true);
      _onDataChanged();
      if (mounted) {
        final total = SyncEngine.statsNotifier.value?.total ?? 0;
        final inQueue = SyncEngine.statsNotifier.value?.inQueue ?? 0;
        final msg = newCount > 0
            ? 'Gallery scanned: $newCount new captures queued ($total total)'
            : 'Gallery up to date ($total total media, $inQueue queued)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  bool get _isTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  void _switchPage(int index) {
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      if (_isTest) {
        _pageController.jumpToPage(index);
      } else {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _openGuide() {
    AppWalkthroughGuide.showWalkthroughSheet(
      context,
      isConfigured: Prefs.isConfigured(),
      totalCount: SyncEngine.statsNotifier.value?.total ?? 0,
      isMonitoring: Prefs.monitoringEnabled,
      onNavigateToSettings: () => _switchPage(2),
      onScanGallery: _handleGlobalRefresh,
      onStartInteractiveTour: () {
        setState(() {
          _isTutorialActive = true;
          _tutorialStep = 1;
        });
      },
    );
  }

  void _navigateToActivityWithFilter(String? filter) {
    _switchPage(1);
    if (filter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _activityKey.currentState?.setFilter(filter);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = ValtSkyTheme.accentText(isDark);
    final surfaceBg = ValtSkyTheme.canvas(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final trackBg = ValtSkyTheme.raised(isDark);

    return Scaffold(
      backgroundColor: surfaceBg,
      body: Stack(
        children: [
          // Decorative thin line-art swirl behind content (~6% opacity, drawn in code)
          Positioned.fill(
            child: LineArtSwirl(opacity: isDark ? 0.05 : 0.06),
          ),
          LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1024;

          final content = PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              if (index == 0) _dashboardKey.currentState?.refreshStats();
              if (index == 1) _activityKey.currentState?.refreshItems();
            },
            children: [
              DashboardView(
                key: _dashboardKey,
                onNavigateToSettings: () => _switchPage(2),
                onNavigateToActivity: _navigateToActivityWithFilter,
              ),
              ActivityView(
                key: _activityKey,
                onDataChanged: _onDataChanged,
              ),
              SettingsView(
                onDataChanged: _onDataChanged,
              ),
            ],
          );

          if (isDesktop) {
            // Expanded (>1024): Left Navigation Rail with 3 labeled destinations
            return Stack(
              children: [
                Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (index) {
                        _switchPage(index);
                        if (index == 0) _dashboardKey.currentState?.refreshStats();
                        if (index == 1) _activityKey.currentState?.refreshItems();
                      },
                      backgroundColor: ValtSkyTheme.surface(isDark),
                      indicatorColor: ValtSkyTheme.amber,
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: const ValtSkyLogo(size: 30),
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.cloud_outlined),
                          selectedIcon: Icon(Icons.cloud_rounded, color: ValtSkyTheme.ink),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.format_list_bulleted_rounded),
                          selectedIcon: Icon(Icons.fact_check_rounded, color: ValtSkyTheme.ink),
                          label: Text('Queue & Activity'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_outlined),
                          selectedIcon: Icon(Icons.tune_rounded, color: ValtSkyTheme.ink),
                          label: Text('Settings'),
                        ),
                      ],
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: Column(
                            children: [
                              _buildAppBar(isDark, secondaryColor, trackBg, borderColor),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isTutorialActive && !_isLocked) _buildTutorialOverlay(),
                if (_isLocked) _buildLockScreen(isDark),
              ],
            );
          }

          // Compact (<600) & Medium (600-1024): Floating Pill Bottom Dock
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Stack(
                children: [
                  Scaffold(
                    extendBody: true,
                    backgroundColor: Colors.transparent,
                    appBar: _buildAppBar(isDark, secondaryColor, trackBg, borderColor),
                    body: content,
                    bottomNavigationBar: SafeArea(
                      child: ValtSkyNavigationDock(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) {
                          _switchPage(index);
                          if (index == 0) _dashboardKey.currentState?.refreshStats();
                          if (index == 1) _activityKey.currentState?.refreshItems();
                        },
                      ),
                    ),
                  ),
                  if (_isTutorialActive && !_isLocked) _buildTutorialOverlay(),
                  if (_isLocked) _buildLockScreen(isDark),
                ],
              ),
            ),
          );
        },
      ),
    ],
  ),
);
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color secondaryColor, Color trackBg, Color borderColor) {
    final slabColor = ValtSkyTheme.capSlab(isDark);
    final slabTextColor = ValtSkyTheme.capSlabText(isDark);

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: BoxDecoration(
          color: slabColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(ValtSkyTheme.radiusCapSlab),
            bottomRight: Radius.circular(ValtSkyTheme.radiusCapSlab),
          ),
          border: isDark
              ? Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1.0,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? ValtSkyTheme.darkSurface3 : const Color(0xFF1E1E22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? borderColor : Colors.white12),
                  ),
                  child: const ValtSkyLogo(size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  'ValtSky',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: slabTextColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Interactive Guide',
                  icon: Icon(Icons.help_outline_rounded, color: slabTextColor, size: 21),
                  onPressed: _openGuide,
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Refresh Live Counts',
                  icon: _isRefreshing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: slabTextColor),
                        )
                      : Icon(Icons.sync_rounded, color: slabTextColor, size: 21),
                  onPressed: _handleGlobalRefresh,
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: slabTextColor,
                    size: 21,
                  ),
                  onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    return InteractiveSpotlightTutorial(
      currentStep: _tutorialStep,
      onNext: () {
        setState(() {
          if (_tutorialStep < 3) {
            _tutorialStep++;
          } else {
            _isTutorialActive = false;
            Prefs.tutorialDismissed = true;
          }
        });
      },
      onSkip: () {
        setState(() {
          _isTutorialActive = false;
          Prefs.tutorialDismissed = true;
        });
      },
      onGoToSettings: () {
        _switchPage(2);
      },
      onTriggerScan: () {
        _switchPage(0);
        _handleGlobalRefresh();
      },
      onToggleMonitoring: () {
        _switchPage(0);
        _dashboardKey.currentState?.refreshStats();
      },
    );
  }

  void _handleUnlockAttempt(String pin) {
    if (Prefs.verifyVaultPin(pin)) {
      _unlockPinController.clear();
      setState(() {
        _isLocked = false;
        _unlockErrorMsg = null;
      });
      _checkPermissionsOnFirstLaunch();
    } else {
      _unlockPinController.clear();
      setState(() {
        _unlockErrorMsg = 'Incorrect PIN. Please try again.';
      });
    }
  }

  Widget _buildLockScreen(bool isDark) {
    final bg = ValtSkyTheme.canvas(isDark);
    final primaryColor = ValtSkyTheme.amber;
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);

    return Positioned.fill(
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.16 : 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(Icons.lock_rounded, size: 36, color: primaryColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Vault Privacy Lock',
                    style: TextStyle(
                      fontFamily: ValtSkyTheme.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ValtSkyTheme.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter 4-digit security PIN to access cloud media',
                    style: TextStyle(
                      fontFamily: ValtSkyTheme.fontFamily,
                      fontSize: 13,
                      color: ValtSkyTheme.textSecondary(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _unlockPinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamily,
                        fontSize: 24,
                        letterSpacing: 14,
                        fontWeight: FontWeight.bold,
                        color: ValtSkyTheme.textPrimary(isDark),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: '••••',
                        hintStyle: TextStyle(color: ValtSkyTheme.textSecondary(isDark)),
                      ),
                      onChanged: (val) {
                        if (val.length == 4) {
                          _handleUnlockAttempt(val);
                        }
                      },
                    ),
                  ),
                  if (_unlockErrorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _unlockErrorMsg!,
                      style: const TextStyle(
                        fontFamily: ValtSkyTheme.fontFamily,
                        color: ValtSkyTheme.statusFailed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TactilePress(
                    onTap: () => _handleUnlockAttempt(_unlockPinController.text),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'UNLOCK VAULT',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ValtSkyTheme.ink,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
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
