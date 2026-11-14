import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_engine.dart';
import '../services/background_service.dart';
import '../main.dart';
import '../util/formatters.dart';
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

  int _initTimestamp = 0;
  int _lastResumeTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _initTimestamp = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _currentIndex);
    if (Prefs.vaultPinEnabled && Prefs.hasVaultPin && !_isTest) {
      _isLocked = true;
    }
    // Defer async services until after Frame 1 renders smoothly at 120 FPS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
      if (!_isLocked) {
        _checkPermissionsOnFirstLaunch();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Lock screen on resume if PIN is enabled
      if (Prefs.vaultPinEnabled && Prefs.hasVaultPin && !_isTest) {
        if (!_isLocked) {
          setState(() => _isLocked = true);
        }
      }

      // Ignore initial resume event within 2.0s of cold launch or if fired again within 1.5s
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _initTimestamp < 2000 || now - _lastResumeTimestamp < 1500) {
        return;
      }
      _lastResumeTimestamp = now;

      // Resume sync engine and refresh stats when returning to foreground.
      // Session state is persisted — this just ensures the engine is alive.
      _resumeSyncOnForeground();
    }
  }

  /// Resumes sync engine when the app returns to the foreground.
  /// Does NOT reset the session — picks up where it left off.
  /// Reloads cross-isolate preferences and fetches stats from database.
  Future<void> _resumeSyncOnForeground() async {
    // Reload SharedPreferences from disk so any progress made by the background isolate is visible
    await Prefs.reload();
    // Refresh stats from database (session state is restored from prefs automatically)
    await SyncEngine.fetchCurrentStats(forceDb: true);
    if (!mounted) return;
    // Only trigger a UI refresh if the dashboard widget is still mounted
    if (_dashboardKey.currentState?.mounted == true) {
      _dashboardKey.currentState!.refreshStats();
    }

    // Restart sync workers if there are pending items and uploads aren't paused
    if (Prefs.isConfigured() && !Prefs.uploadPaused && !SyncEngine.instance.isSyncing) {
      SyncEngine().startSync();
    }
  }

  Future<void> _checkPermissionsOnFirstLaunch() async {
    if (!mounted || _isTest) return;
    if (!Prefs.permissionsRequested) {
      // Like standard Android apps and games, request device system permissions
      // directly on first launch rather than within an in-app screen.
      await PermissionManager.requestAllPermissions();
      if (mounted) {
        _onDataChanged();
      }
    }
    // Automatically present the onboarding guide for new users on first download
    if (mounted && !Prefs.tutorialDismissed && !_isTest) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !Prefs.tutorialDismissed) {
          _openGuide();
        }
      });
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

    // Auto-resume background monitoring if configured and monitoring was enabled
    if (Prefs.isConfigured() && Prefs.monitoringEnabled) {
      if (!kIsWeb) {
        try {
          if (!await BackgroundService.isRunning()) {
            await BackgroundService.start();
          }
        } catch (e) {
          debugPrint('Error starting background service: $e');
        }
      }
    }

    // Always ensure queue uploader is active for pending items unless explicitly paused
    if (Prefs.isConfigured() && !Prefs.uploadPaused && !SyncEngine.instance.isSyncing) {
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
        final totalFormatted = ValtSkyFormatters.formatMediaCount(total);
        final inQueueFormatted = ValtSkyFormatters.formatMediaCount(inQueue);
        final newCountFormatted = ValtSkyFormatters.formatMediaCount(newCount);
        final msg = newCount > 0
            ? 'Gallery scanned: $newCountFormatted new captures queued ($totalFormatted total)'
            : 'Gallery up to date ($totalFormatted total media, $inQueueFormatted queued)';
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

  void _switchPage(int targetIndex) {
    if (!mounted) return;
    if (targetIndex == _currentIndex && _pageController.hasClients && _pageController.page?.round() == targetIndex) {
      return;
    }

    setState(() => _currentIndex = targetIndex);
    if (_pageController.hasClients) {
      if (_isTest || (context.mounted && MediaQuery.of(context).disableAnimations)) {
        _pageController.jumpToPage(targetIndex);
        if (targetIndex == 0) _dashboardKey.currentState?.refreshStats();
        if (targetIndex == 1) _activityKey.currentState?.refreshItems();
      } else {
        // Smooth slide via PageView's own animation — lightweight, GPU-composited.
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        // Defer database queries until after the transition to keep animation at 120fps
        Future.delayed(const Duration(milliseconds: 280), () {
          if (!mounted) return;
          if (_currentIndex == 0) _dashboardKey.currentState?.refreshStats();
          if (_currentIndex == 1) _activityKey.currentState?.refreshItems();
        });
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

          // Fluid PageView swipe physics with zero animation-wrapper overhead
          final content = PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
                  onPageChanged: (index) {
                    if (index != _currentIndex) {
                      setState(() => _currentIndex = index);
                      // Page has settled after swipe; run refresh in next frame
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (index == 0) _dashboardKey.currentState?.refreshStats();
                        if (index == 1) _activityKey.currentState?.refreshItems();
                      });
                    }
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
                      onDestinationSelected: _switchPage,
                      backgroundColor: isDark ? ValtSkyTheme.surface(isDark) : ValtSkyTheme.coffeeBeige,
                      indicatorColor: isDark ? ValtSkyTheme.amber : Colors.white,
                      unselectedIconTheme: IconThemeData(
                        color: isDark ? ValtSkyTheme.darkText2 : ValtSkyTheme.coffeeBeigeTextSecondary,
                      ),
                      selectedIconTheme: IconThemeData(
                        color: isDark ? ValtSkyTheme.ink : ValtSkyTheme.coffeeBeigeTextPrimary,
                      ),
                      unselectedLabelTextStyle: TextStyle(
                        color: isDark ? ValtSkyTheme.darkText2 : ValtSkyTheme.coffeeBeigeTextSecondary,
                      ),
                      selectedLabelTextStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? ValtSkyTheme.paper : ValtSkyTheme.coffeeBeigeTextPrimary,
                      ),
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark ? trackBg : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? borderColor : ValtSkyTheme.coffeeBeigeBorder,
                            ),
                          ),
                          child: const ValtSkyLogo(size: 30),
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.cloud_outlined),
                          selectedIcon: Icon(Icons.cloud_rounded),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.format_list_bulleted_rounded),
                          selectedIcon: Icon(Icons.fact_check_rounded),
                          label: Text('Queue & Activity'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_outlined),
                          selectedIcon: Icon(Icons.tune_rounded),
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
                              _buildAppBar(isDark, borderColor),
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
                    appBar: _buildAppBar(isDark, borderColor),
                    body: content,
                    bottomNavigationBar: SafeArea(
                      child: ValtSkyNavigationDock(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: _switchPage,
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

  PreferredSizeWidget _buildAppBar(bool isDark, Color borderColor) {
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
              : Border.all(
                  color: ValtSkyTheme.coffeeBeigeBorder,
                  width: 1.0,
                ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : ValtSkyTheme.coffeeBeigeTextPrimary.withValues(alpha: 0.08),
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
                    color: isDark ? ValtSkyTheme.darkSurface3 : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? borderColor : ValtSkyTheme.coffeeBeigeBorder,
                    ),
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
