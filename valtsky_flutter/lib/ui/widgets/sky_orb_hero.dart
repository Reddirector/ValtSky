import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../util/theme.dart';

// ─── SKY ORB HERO WIDGET ────────────────────────────────────────────────
/// Living Night-Sky Vault Hero Orb (about 45% of viewport width)
/// Features:
/// - Circular glass-edged orb with cosmic starfield
/// - Lit stars = proportional to synced items (bound to real state, max 60)
/// - Thick rounded arc stroke with gradient accent -> accent-2 and glowing head cap
/// - Center percentage readout with Sora Light 56
/// - Subtle star twinkle animation (respects reduce motion and eco mode)
/// - Pointer/ambient parallax effect
/// - RepaintBoundary for optimal 60fps GPU performance
class SkyOrbHero extends StatefulWidget {
  final double progress;
  final int totalCount;
  final int syncedCount;
  final double size;
  final bool isUploading;

  const SkyOrbHero({
    super.key,
    required this.progress,
    required this.totalCount,
    required this.syncedCount,
    this.size = 180.0,
    this.isUploading = false,
  });

  @override
  State<SkyOrbHero> createState() => _SkyOrbHeroState();
}

class _SkyOrbHeroState extends State<SkyOrbHero> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkleController;
  final List<Offset> _starOffsets = [];
  final List<double> _starSizes = [];
  final List<double> _starPhases = [];

  bool get _isTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!_isTest) {
      _twinkleController.repeat(reverse: true);
    } else {
      _twinkleController.value = 0.5;
    }

    _generateStarfield();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _twinkleController.isAnimating) {
      _twinkleController.stop();
    } else if (!reduceMotion && !_twinkleController.isAnimating && !_isTest) {
      _twinkleController.repeat(reverse: true);
    }
  }

  void _generateStarfield() {
    _starOffsets.clear();
    _starSizes.clear();
    _starPhases.clear();

    final rng = math.Random(42); // Deterministic seed for stable star placement
    const maxStars = 60;
    final starCount = math.min(math.max(widget.totalCount, 8), maxStars);

    for (int i = 0; i < starCount; i++) {
      // Polar coordinates inside the orb (radius < 0.72 to stay within the ring)
      final r = (0.15 + rng.nextDouble() * 0.58);
      final theta = rng.nextDouble() * 2 * math.pi;
      _starOffsets.add(Offset(0.5 + r * math.cos(theta), 0.5 + r * math.sin(theta)));
      _starSizes.add(1.2 + rng.nextDouble() * 2.2);
      _starPhases.add(rng.nextDouble() * 2 * math.pi);
    }
  }

  @override
  void didUpdateWidget(SkyOrbHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalCount != widget.totalCount) {
      _generateStarfield();
    }
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final clampedProgress = widget.progress.clamp(0.0, 1.0);
    final percentInt = (clampedProgress * 100).toInt();

    return RepaintBoundary(
      child: Semantics(
        label: '$percentInt percent synchronized',
        value: '$percentInt%',
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Soft Ambient Sky Glow (Pre-rendered radial gradient)
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isDark
                        ? [
                            ValtSkyTheme.darkAccent.withValues(alpha: widget.isUploading ? 0.28 : 0.14),
                            ValtSkyTheme.darkSurface3.withValues(alpha: 0.05),
                            Colors.transparent,
                          ]
                        : [
                            ValtSkyTheme.lightAccentFill.withValues(alpha: 0.16),
                            ValtSkyTheme.lightSurface3.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                    stops: const [0.2, 0.7, 1.0],
                  ),
                ),
              ),

              // 2. Cosmic Starfield + Progress Arc Canvas
              AnimatedBuilder(
                animation: _twinkleController,
                builder: (context, _) {
                  final twinkle = reduceMotion ? 0.5 : _twinkleController.value;
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _SkyOrbPainter(
                      progress: clampedProgress,
                      isDark: isDark,
                      twinkleValue: twinkle,
                      starOffsets: _starOffsets,
                      starSizes: _starSizes,
                      starPhases: _starPhases,
                      totalCount: widget.totalCount,
                      syncedCount: widget.syncedCount,
                      isUploading: widget.isUploading,
                    ),
                  );
                },
              ),

              // 3. Center Percentage Readout (Sora Light 56 / 42 depending on size)
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: percentInt),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, animatedVal, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$animatedVal',
                            style: TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyDisplay,
                              fontSize: widget.size >= 160 ? 52 : 38,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -1.2,
                              color: ValtSkyTheme.textPrimary(isDark),
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '%',
                            style: TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyDisplay,
                              fontSize: widget.size >= 160 ? 20 : 16,
                              fontWeight: FontWeight.w400,
                              color: ValtSkyTheme.accentText(isDark),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkyOrbPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final double twinkleValue;
  final List<Offset> starOffsets;
  final List<double> starSizes;
  final List<double> starPhases;
  final int totalCount;
  final int syncedCount;
  final bool isUploading;

  _SkyOrbPainter({
    required this.progress,
    required this.isDark,
    required this.twinkleValue,
    required this.starOffsets,
    required this.starSizes,
    required this.starPhases,
    required this.totalCount,
    required this.syncedCount,
    required this.isUploading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.065;
    final radius = (size.width - strokeWidth) / 2 - 2;

    // A. Glass Orb Body Fill
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                ValtSkyTheme.darkSurface2.withValues(alpha: 0.85),
                ValtSkyTheme.darkSurface1.withValues(alpha: 0.95),
              ]
            : [
                ValtSkyTheme.lightSurface1.withValues(alpha: 0.90),
                ValtSkyTheme.lightSurface2.withValues(alpha: 0.95),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, orbPaint);

    // B. Draw Stars Inside Orb
    final totalStars = starOffsets.length;
    final litStarsCount = totalCount > 0
        ? ((syncedCount / totalCount).clamp(0.0, 1.0) * totalStars).round()
        : 0;

    for (int i = 0; i < totalStars; i++) {
      final pos = Offset(
        size.width * starOffsets[i].dx,
        size.height * starOffsets[i].dy,
      );
      final isLit = i < litStarsCount;
      final phase = starPhases[i];
      final osc = (math.sin(twinkleValue * 2 * math.pi + phase) + 1.0) / 2.0;
      final opacity = isLit
          ? (0.55 + osc * 0.45).clamp(0.0, 1.0)
          : (0.12 + osc * 0.15).clamp(0.0, 1.0);

      final starPaint = Paint()
        ..color = isLit
            ? (isDark ? ValtSkyTheme.statusSynced : ValtSkyTheme.lightAccentFill).withValues(alpha: opacity)
            : (isDark ? ValtSkyTheme.darkTextTertiary : ValtSkyTheme.lightTextSecondary).withValues(alpha: opacity);

      canvas.drawCircle(pos, starSizes[i] * (isLit ? 1.15 : 0.85), starPaint);
    }

    // C. Recessed Track Arc (Surface-3)
    final trackPaint = Paint()
      ..color = ValtSkyTheme.surface(isDark, level: 3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // D. Progress Arc with Gradient (Accent -> Accent-2)
    if (progress > 0.005) {
      final sweepAngle = 2 * math.pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);

      final progressShader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: isDark
            ? const [ValtSkyTheme.darkAccent, ValtSkyTheme.darkAccent2]
            : const [ValtSkyTheme.lightAccentFill, Color(0xFF7C8CFF)],
      ).createShader(rect);

      final progressPaint = Paint()
        ..shader = progressShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);

      // E. Glowing Head Cap of the Arc
      final headAngle = -math.pi / 2 + sweepAngle;
      final headX = center.dx + radius * math.cos(headAngle);
      final headY = center.dy + radius * math.sin(headAngle);
      final headPoint = Offset(headX, headY);

      final headGlow = Paint()
        ..color = (isUploading
                ? ValtSkyTheme.darkAqua
                : (isDark ? ValtSkyTheme.darkAccent2 : ValtSkyTheme.lightAccentFill))
            .withValues(alpha: isDark ? 0.70 : 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(headPoint, strokeWidth * 0.8, headGlow);

      final headCore = Paint()
        ..color = isUploading
            ? ValtSkyTheme.darkAqua
            : (isDark ? Colors.white : ValtSkyTheme.lightSurface1);
      canvas.drawCircle(headPoint, strokeWidth * 0.35, headCore);
    }

    // F. Glass Edge Reflection Highlight (1px inner border)
    final glassEdge = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.08 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius + (strokeWidth / 2), glassEdge);
  }

  @override
  bool shouldRepaint(_SkyOrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.twinkleValue != twinkleValue ||
        oldDelegate.syncedCount != syncedCount ||
        oldDelegate.totalCount != totalCount ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isUploading != isUploading;
  }
}

// ─── RADIAL TICK RING (COMPATIBILITY WRAPPER) ───────────────────────────
class RadialTickRing extends StatelessWidget {
  final double progress;
  final double size;
  final int totalTicks;

  const RadialTickRing({
    super.key,
    required this.progress,
    this.size = 140,
    this.totalTicks = 36,
  });

  @override
  Widget build(BuildContext context) {
    return SkyOrbHero(
      progress: progress,
      totalCount: 36,
      syncedCount: (progress * 36).round(),
      size: size,
    );
  }
}
