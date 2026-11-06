import 'package:flutter/material.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

class AppWalkthroughGuide extends StatelessWidget {
  final bool isConfigured;
  final int totalCount;
  final bool isMonitoring;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onScanGallery;
  final VoidCallback onDismiss;
  final VoidCallback? onStartInteractiveTour;

  const AppWalkthroughGuide({
    super.key,
    required this.isConfigured,
    required this.totalCount,
    required this.isMonitoring,
    required this.onNavigateToSettings,
    required this.onScanGallery,
    required this.onDismiss,
    this.onStartInteractiveTour,
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
      backgroundColor: ValtSkyTheme.tertiaryCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 18,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.tertiaryBorder(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ValtSkyTheme.primary(isDark).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 20,
                          color: ValtSkyTheme.primary(isDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ValtSky Quick Guide',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '3 simple steps to start zero-loss backup',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppWalkthroughGuide(
                isConfigured: isConfigured,
                totalCount: totalCount,
                isMonitoring: isMonitoring,
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dismiss',
                        style: TextStyle(
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

          // Step 1: Connect Telegram Vault
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '1',
            title: 'Connect Your Vault',
            description: 'Link your Telegram in Settings to activate unlimited storage.',
            subSteps: const [
              'Enter phone number for instant login OTP code.',
              'Private Telegram channel becomes your unlimited vault.',
            ],
            isDone: isConfigured,
            ctaLabel: isConfigured ? 'Connected' : 'Open Settings',
            ctaIcon: isConfigured ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
            onCtaTap: isConfigured ? null : onNavigateToSettings,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 10),

          // Step 2: Scan Gallery to Receive Images
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '2',
            title: 'Scan Gallery to Receive Media',
            description: 'Index camera photos & videos into the system queue.',
            subSteps: const [
              'Tap Scan Gallery on Dashboard or Activity tab.',
              'Media is discovered & queued for zero-loss backup.',
            ],
            isDone: totalCount > 0,
            ctaLabel: totalCount > 0 ? '$totalCount indexed' : 'Scan Gallery',
            ctaIcon: totalCount > 0 ? Icons.check_circle_rounded : Icons.photo_library_outlined,
            onCtaTap: onScanGallery,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),
          const SizedBox(height: 10),

          // Step 3: Monitor & Automatic Sync Controls
          _buildStepRow(
            context: context,
            isDark: isDark,
            stepNumber: '3',
            title: 'Monitor & Manage Sync',
            description: 'Automated background upload with full control.',
            subSteps: const [
              'Bit-for-bit upload preserves full camera quality & EXIF.',
              'Tap Pause or Stop Process anytime to control workers.',
            ],
            isDone: isMonitoring,
            ctaLabel: isMonitoring ? 'Monitoring Active' : 'Ready',
            ctaIcon: isMonitoring ? Icons.radio_button_checked_rounded : Icons.check_circle_outline_rounded,
            onCtaTap: null,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trackBg: trackBg,
            borderColor: borderColor,
          ),

          if (onStartInteractiveTour != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: onStartInteractiveTour,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.4), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 16),
                label: const Text(
                  'INTERACTIVE SPOTLIGHT TOUR',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ],
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
          color: isDone ? ValtSkyTheme.success.withValues(alpha: 0.35) : borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone ? ValtSkyTheme.success : primaryColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : Text(
                        stepNumber,
                        style: TextStyle(
                          fontSize: 11,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                            fontWeight: FontWeight.w900,
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
                    color: (isDone ? ValtSkyTheme.success : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ctaIcon, size: 12, color: isDone ? ValtSkyTheme.success : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        ctaLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDone ? ValtSkyTheme.success : Colors.grey,
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
              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
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
                          fontSize: 11,
                          height: 1.25,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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

