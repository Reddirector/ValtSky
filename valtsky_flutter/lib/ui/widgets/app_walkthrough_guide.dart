import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../util/formatters.dart';
import '../../util/permission_manager.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

/// Professional App Tutorial & Quick Guide
/// Features editorial minimalism, step-by-step app flow, interactive CTAs,
/// and a small "Don't show again" checkbox persisting to Prefs.tutorialDismissed.
class AppWalkthroughGuide extends StatefulWidget {
  final bool isConfigured;
  final int totalCount;
  final bool isMonitoring;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onScanGallery;
  final VoidCallback onDismiss;
  final VoidCallback? onStartInteractiveTour;
  final bool showHeader;

  const AppWalkthroughGuide({
    super.key,
    required this.isConfigured,
    required this.totalCount,
    required this.isMonitoring,
    required this.onNavigateToSettings,
    required this.onScanGallery,
    required this.onDismiss,
    this.onStartInteractiveTour,
    this.showHeader = true,
  });

  /// Displays the interactive walkthrough as an elegant modal bottom sheet
  static void showWalkthroughSheet(
    BuildContext context, {
    required bool isConfigured,
    required int totalCount,
    required bool isMonitoring,
    required VoidCallback onNavigateToSettings,
    required VoidCallback onScanGallery,
    VoidCallback? onStartInteractiveTour,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ValtSkyTheme.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 14,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.hairline(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Professional Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ValtSkyTheme.accent(isDark).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.explore_outlined,
                            size: 20,
                            color: ValtSkyTheme.accent(isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ValtSky Quick Guide',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: ValtSkyTheme.textPrimary(isDark),
                                ),
                              ),
                              Text(
                                '4 simple steps to setup & zero-loss backup',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyBody,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: ValtSkyTheme.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: Icon(Icons.close_rounded, size: 20, color: ValtSkyTheme.textSecondary(isDark)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Embedded Guide Body
              AppWalkthroughGuide(
                isConfigured: isConfigured,
                totalCount: totalCount,
                isMonitoring: isMonitoring,
                showHeader: false,
                onNavigateToSettings: () {
                  Navigator.pop(ctx);
                  onNavigateToSettings();
                },
                onScanGallery: () {
                  Navigator.pop(ctx);
                  onScanGallery();
                },
                onDismiss: () => Navigator.pop(ctx),
                onStartInteractiveTour: onStartInteractiveTour != null
                    ? () {
                        Navigator.pop(ctx);
                        onStartInteractiveTour();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<AppWalkthroughGuide> createState() => _AppWalkthroughGuideState();
}

class _AppWalkthroughGuideState extends State<AppWalkthroughGuide> {
  late bool _dontShowAgain;

  @override
  void initState() {
    super.initState();
    _dontShowAgain = Prefs.tutorialDismissed;
  }

  void _toggleDontShowAgain(bool? value) {
    setState(() {
      _dontShowAgain = value ?? false;
      Prefs.tutorialDismissed = _dontShowAgain;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.accent(isDark);
    final secondaryColor = ValtSkyTheme.textSecondary(isDark);
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final trackBg = ValtSkyTheme.raised(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header Row (rendered when standalone)
          if (widget.showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'QUICK START TUTORIAL',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: widget.onDismiss,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Dismiss',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyBody,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mutedText,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.close_rounded, size: 14, color: mutedText),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Step 1: Connect Telegram Vault
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '1',
            title: 'Connect Your Vault',
            description: 'Link your Telegram account in Settings to activate unlimited storage.',
            subSteps: const [
              'Enter your phone number with country code.',
              'Important: OTP code arrives inside your Telegram app, NOT SMS.',
              'A private channel "valtsky_vault" becomes your lossless cloud.',
            ],
            isDone: widget.isConfigured,
            ctaLabel: widget.isConfigured ? 'Connected' : 'Open Settings',
            ctaIcon: widget.isConfigured ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
            onCtaTap: widget.isConfigured ? null : widget.onNavigateToSettings,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 10),

          // Step 2: Standby Connections & Battery Whitelist
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '2',
            title: 'Standby Connections & Permissions',
            description: 'Enable background execution so uploads never sleep.',
            subSteps: const [
              'Grant Photos & Notifications permissions when prompted.',
              'Battery Whitelist: Set to "Unrestricted" in Android App Info.',
              'Standby Persistence: Keeps uploading on charging stands or when sleeping.',
            ],
            isDone: Prefs.permissionsRequested,
            ctaLabel: Prefs.permissionsRequested ? 'Configured' : 'Permissions',
            ctaIcon: Prefs.permissionsRequested ? Icons.check_circle_rounded : Icons.bolt_rounded,
            onCtaTap: () => PermissionManager.requestAllPermissions(),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 10),

          // Step 3: Automatic Gallery Discovery & Indexing
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '3',
            title: 'Scan Gallery & Dual-Lane Uploads',
            description: 'Auto-scan discovers media and streams photos & videos concurrently.',
            subSteps: const [
              'Zero-effort indexing: media is queued in local SQLite automatically.',
              'Dual-lane pipeline uploads photos & 4K videos without head-of-line blocking.',
            ],
            isDone: widget.totalCount > 0,
            ctaLabel: widget.totalCount > 0 ? '${ValtSkyFormatters.formatMediaCount(widget.totalCount)} indexed' : 'Scan Gallery',
            ctaIcon: widget.totalCount > 0 ? Icons.check_circle_rounded : Icons.photo_library_outlined,
            onCtaTap: widget.onScanGallery,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 10),

          // Step 4: Monitor & Nightly Alarm Clock Sync
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '4',
            title: 'Monitor & Nightly Alarm Loop',
            description: 'Automated scan-then-upload lifecycle and scheduled nightly sync.',
            subSteps: const [
              'Monitoring automatically pauses during uploads to save CPU/battery.',
              'Schedule an alarm clock (e.g. 12:00 AM) to sync daily captures while charging.',
            ],
            isDone: widget.isMonitoring,
            ctaLabel: widget.isMonitoring ? 'Monitoring Active' : 'Ready',
            ctaIcon: widget.isMonitoring ? Icons.radio_button_checked_rounded : Icons.check_circle_outline_rounded,
            onCtaTap: null,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),

          const SizedBox(height: 14),

          // Professional Checkbox Row: "Don't show this again"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: trackBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _dontShowAgain,
                    activeColor: primaryColor,
                    checkColor: isDark ? ValtSkyTheme.ink : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(
                      color: isDark ? ValtSkyTheme.darkHairline : ValtSkyTheme.coffeeBeigeBorder,
                      width: 1.5,
                    ),
                    onChanged: _toggleDontShowAgain,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _toggleDontShowAgain(!_dontShowAgain),
                    child: Text(
                      "Don't show this again",
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: mutedText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.onStartInteractiveTour != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: widget.onStartInteractiveTour,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.35), width: 1.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 15),
                label: const Text(
                  'INTERACTIVE SPOTLIGHT TOUR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Primary Done / Got It Button
          TactilePress(
            onTap: () {
              Prefs.tutorialDismissed = _dontShowAgain;
              widget.onDismiss();
            },
            scaleDown: 0.96,
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Got It',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildStepRow({
    required BuildContext context,
    required bool isDark,
    required String stepNumber,
    required String title,
    required String description,
    required List<String> subSteps,
    required bool isDone,
    required String ctaLabel,
    required IconData ctaIcon,
    required VoidCallback? onCtaTap,
    required Color primaryColor,
    required Color secondaryColor,
    required Color trackBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? ValtSkyTheme.synced(isDark).withValues(alpha: 0.35) : borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone ? ValtSkyTheme.synced(isDark) : primaryColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : Text(
                        stepNumber,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
              ),
              if (onCtaTap != null)
                TactilePress(
                  onTap: onCtaTap,
                  scaleDown: 0.94,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctaLabel,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(ctaIcon, size: 11, color: Colors.white),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDone ? ValtSkyTheme.synced(isDark) : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ctaIcon, size: 12, color: isDone ? ValtSkyTheme.synced(isDark) : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        ctaLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDone ? ValtSkyTheme.synced(isDark) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: ValtSkyTheme.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 5),
          ...subSteps.map((step) => Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 11,
                          height: 1.25,
                          color: ValtSkyTheme.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
