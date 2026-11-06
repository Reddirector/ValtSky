import 'package:flutter/material.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = secondaryColor.withAlpha(120);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;

        // Step definitions
        Widget guideCard;
        Widget targetSpotlight;

        switch (widget.currentStep) {
          case 1:
            // STEP 1: Point to Settings (Bottom Navigation Bar)
            targetSpotlight = Positioned(
              bottom: 8,
              right: screenWidth * 0.12,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: GestureDetector(
                  onTap: () {
                    widget.onGoToSettings();
                    widget.onNext();
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: secondaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: secondaryColor.withAlpha(140),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.touch_app_rounded, size: 28, color: secondaryColor),
                    ),
                  ),
                ),
              ),
            );

            guideCard = Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: _buildGuideCard(
                step: 1,
                icon: Icons.tune_rounded,
                title: 'Connect Your Vault',
                subtitle: '1. Open Settings • 2. Enter Phone/Bot • 3. Channel links as cloud',
                actionLabel: 'Open Settings',
                actionIcon: Icons.arrow_forward_rounded,
                onAction: () {
                  widget.onGoToSettings();
                  widget.onNext();
                },
                cardBg: cardBg,
                borderColor: borderColor,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                isDark: isDark,
              ),
            );
            break;

          case 2:
            // STEP 2: Point to Scan Gallery (Quick Controls)
            targetSpotlight = Positioned(
              bottom: screenHeight * 0.32,
              right: screenWidth * 0.15,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: GestureDetector(
                  onTap: () {
                    widget.onTriggerScan();
                    widget.onNext();
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: secondaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: secondaryColor.withAlpha(140),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.touch_app_rounded, size: 28, color: secondaryColor),
                    ),
                  ),
                ),
              ),
            );

            guideCard = Positioned(
              bottom: screenHeight * 0.44,
              left: 20,
              right: 20,
              child: _buildGuideCard(
                step: 2,
                icon: Icons.photo_camera_back_outlined,
                title: 'Scan Gallery',
                subtitle: '1. Tap Scan Gallery • 2. Receives photos & videos • 3. Queues for backup',
                actionLabel: 'Scan Gallery Now',
                actionIcon: Icons.sync_rounded,
                onAction: () {
                  widget.onTriggerScan();
                  widget.onNext();
                },
                cardBg: cardBg,
                borderColor: borderColor,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                isDark: isDark,
              ),
            );
            break;

          case 3:
          default:
            // STEP 3: Point to Start Monitoring (Vault Storage Card)
            targetSpotlight = Positioned(
              top: screenHeight * 0.30,
              left: screenWidth * 0.35,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: GestureDetector(
                  onTap: () {
                    widget.onToggleMonitoring();
                    widget.onSkip();
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: secondaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: secondaryColor.withAlpha(140),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.touch_app_rounded, size: 28, color: secondaryColor),
                    ),
                  ),
                ),
              ),
            );

            guideCard = Positioned(
              top: screenHeight * 0.42,
              left: 20,
              right: 20,
              child: _buildGuideCard(
                step: 3,
                icon: Icons.play_circle_fill_rounded,
                title: 'Start Monitoring',
                subtitle: '1. Auto background sync • 2. Bit-for-bit EXIF preserved • 3. Full control',
                actionLabel: 'Start & Finish',
                actionIcon: Icons.check_rounded,
                onAction: () {
                  widget.onToggleMonitoring();
                  widget.onSkip();
                },
                cardBg: cardBg,
                borderColor: borderColor,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                isDark: isDark,
              ),
            );
            break;
        }

        return Stack(
          children: [
            // Darkened backdrop
            GestureDetector(
              onTap: widget.onSkip,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withAlpha(170),
              ),
            ),

            // Top Skip Button
            Positioned(
              top: 54,
              right: 20,
              child: TextButton.icon(
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(120),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text(
                  'Skip',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // Target Spotlight Circle
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
    required Color primaryColor,
    required Color secondaryColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step Counter Badge & Icon Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: secondaryColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: secondaryColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: secondaryColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: secondaryColor.withAlpha(60)),
                ),
                child: Text(
                  'STEP $step OF 3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: secondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Short Subtitle
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Interactive Action Button
          TactilePress(
            onTap: onAction,
            scaleDown: 0.96,
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(actionIcon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
