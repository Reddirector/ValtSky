import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

/// Professional Interactive App Spotlight Tutorial
/// Highlights the updated app flow with clean editorial styling,
/// subtle highlight beacons, step navigation, and a "Don't show again" checkbox.
class InteractiveSpotlightTutorial extends StatefulWidget {
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onGoToSettings;
  final VoidCallback onTriggerScan;
  final VoidCallback onToggleMonitoring;

  const InteractiveSpotlightTutorial({
    super.key,
    required this.currentStep,
    required this.onNext,
    required this.onSkip,
    required this.onGoToSettings,
    required this.onTriggerScan,
    required this.onToggleMonitoring,
  });

  @override
  State<InteractiveSpotlightTutorial> createState() => _InteractiveSpotlightTutorialState();
}

class _InteractiveSpotlightTutorialState extends State<InteractiveSpotlightTutorial>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late bool _dontShowAgain;

  @override
  void initState() {
    super.initState();
    _dontShowAgain = Prefs.tutorialDismissed;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (!_isTest) {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  bool get _isTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleDontShowAgain(bool? val) {
    setState(() {
      _dontShowAgain = val ?? false;
      Prefs.tutorialDismissed = _dontShowAgain;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.accent(isDark);
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final trackBg = ValtSkyTheme.raised(isDark);
    final textSecondary = ValtSkyTheme.textSecondary(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;

        Widget guideCard;
        Widget targetSpotlight;

        switch (widget.currentStep) {
          case 1:
            // STEP 1: Point to Settings (Bottom Navigation Bar)
            targetSpotlight = Positioned(
              bottom: 12,
              right: (screenWidth * 0.16).clamp(16.0, 120.0),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );

            guideCard = Positioned(
              bottom: 96,
              left: 20,
              right: 20,
              child: _buildGuideCard(
                step: 1,
                icon: Icons.tune_rounded,
                title: 'Connect Your Vault',
                subtitle: 'Link Telegram in Settings. Your channel serves as unlimited cloud vault.',
                actionLabel: 'Open Settings',
                actionIcon: Icons.arrow_forward_rounded,
                onAction: () {
                  widget.onGoToSettings();
                  widget.onNext();
                },
                cardBg: cardBg,
                borderColor: borderColor,
                trackBg: trackBg,
                primaryColor: primaryColor,
                textSecondary: textSecondary,
                isDark: isDark,
              ),
            );
            break;

          case 2:
            // STEP 2: Automatic Gallery Discovery & Media Queue
            targetSpotlight = Positioned(
              top: screenHeight * 0.44,
              left: screenWidth * 0.15,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );

            guideCard = Positioned(
              top: screenHeight * 0.20,
              left: 20,
              right: 20,
              child: _buildGuideCard(
                step: 2,
                icon: Icons.photo_library_outlined,
                title: 'Scan Gallery',
                subtitle: 'Auto-scan discovers camera photos & videos upon channel setup. Zero effort.',
                actionLabel: 'Scan Gallery Now',
                actionIcon: Icons.sync_rounded,
                onAction: () {
                  widget.onTriggerScan();
                  widget.onNext();
                },
                cardBg: cardBg,
                borderColor: borderColor,
                trackBg: trackBg,
                primaryColor: primaryColor,
                textSecondary: textSecondary,
                isDark: isDark,
              ),
            );
            break;

          case 3:
          default:
            // STEP 3: Point to Active Monitoring & Quick Controls
            targetSpotlight = Positioned(
              top: screenHeight * 0.32,
              left: 24,
              right: 24,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                    border: Border.all(color: primaryColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );

            guideCard = Positioned(
              bottom: 96,
              left: 20,
              right: 20,
              child: _buildGuideCard(
                step: 3,
                icon: Icons.play_circle_fill_rounded,
                title: 'Start Monitoring',
                subtitle: 'Liquid bucket tracking fills live. Stop Monitoring controls watcher.',
                actionLabel: 'Start & Finish',
                actionIcon: Icons.check_rounded,
                onAction: () {
                  widget.onToggleMonitoring();
                  widget.onSkip();
                },
                cardBg: cardBg,
                borderColor: borderColor,
                trackBg: trackBg,
                primaryColor: primaryColor,
                textSecondary: textSecondary,
                isDark: isDark,
              ),
            );
            break;
        }

        return Stack(
          children: [
            // Soft dimmed backdrop
            GestureDetector(
              onTap: widget.onSkip,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),

            // Top Skip Pill Button
            Positioned(
              top: 50,
              right: 18,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onSkip,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Skip',
                            style: TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyBody,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Target Spotlight Circle / Ring
            targetSpotlight,

            // Floating Interactive Guide Card
            guideCard,
          ],
        );
      },
    );
  }

  Widget _buildGuideCard({
    required int step,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onAction,
    required Color cardBg,
    required Color borderColor,
    required Color trackBg,
    required Color primaryColor,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Counter Badge & Icon Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'STEP $step OF 3',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Short Subtitle
          Text(
            title,
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamilyDisplay,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: ValtSkyTheme.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamilyBody,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Action Button
          TactilePress(
            onTap: onAction,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(actionIcon, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Checkbox Row: "Don't show this again"
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _dontShowAgain,
                  activeColor: primaryColor,
                  checkColor: isDark ? ValtSkyTheme.ink : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(
                    color: isDark ? ValtSkyTheme.darkHairline : ValtSkyTheme.coffeeBeigeBorder,
                    width: 1.2,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
