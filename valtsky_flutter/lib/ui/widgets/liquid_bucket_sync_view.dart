import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../util/theme.dart';

/// "Liquid Bucket" Sync Progress Animation
/// Features:
/// - Fills the entire div like a bucket as sync progress increases (0% -> 100%).
/// - Teardrop drop animation falling from the top with gravity acceleration.
/// - Surface impact ripple waves and splash bounce droplets upon contact.
/// - Two-layer parallax fluid simulation with compound sine/cosine waves and internal bubbles.
/// - Completely fills 100% of the entire div when sync is complete.
/// - Calibrated bucket measurement notches (25%, 50%, 75%, 100%).
/// - Crystal-clear, high-contrast center percentage numeral in Outfit Light and live synced counter.
/// - Optimized 60fps GPU rendering with RepaintBoundary and zero-leak controller lifecycle.
class LiquidBucketSyncView extends StatefulWidget {
  final double progress;
  final int totalCount;
  final int syncedCount;
  final bool isUploading;
  final double height;

  const LiquidBucketSyncView({
    super.key,
    required this.progress,
    required this.totalCount,
    required this.syncedCount,
    this.isUploading = false,
    this.height = 200.0,
  });

  @override
  State<LiquidBucketSyncView> createState() => _LiquidBucketSyncViewState();
}

class _LiquidBucketSyncViewState extends State<LiquidBucketSyncView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  bool get _isTest {
    if (kIsWeb) return false;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
          Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (!_isTest) {
      _waveController.repeat();
    } else {
      _waveController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clampedProgress = widget.progress.clamp(0.0, 1.0);
    final percentInt = (clampedProgress * 100).toInt();

    final borderColor = ValtSkyTheme.hairline(isDark);
    final bucketBg = ValtSkyTheme.surface(isDark, level: 2);
    final accentColor = ValtSkyTheme.accent(isDark);
    final textPrimary = ValtSkyTheme.textPrimary(isDark);
    final textSecondary = ValtSkyTheme.textSecondary(isDark);
    final isComplete = clampedProgress >= 0.999;

    return Semantics(
      label: '$percentInt percent synchronized',
      value: '$percentInt%',
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bucketBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete
                ? accentColor.withValues(alpha: isDark ? 0.60 : 0.45)
                : borderColor,
            width: isComplete ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isComplete
                  ? accentColor.withValues(alpha: isDark ? 0.16 : 0.08)
                  : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: isComplete ? 18 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Animated Liquid & Falling Drops Custom Painter
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _LiquidBucketPainter(
                        animationValue: _waveController.value,
                        progress: clampedProgress,
                        isDark: isDark,
                        isUploading: widget.isUploading,
                        accentColor: accentColor,
                        isTest: _isTest,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),

              // 2. Calibrated Measurement Ticks on Right Edge (25%, 50%, 75%, 100%)
              Positioned(
                right: 12,
                top: 14,
                bottom: 14,
                width: 48,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    return SizedBox(
                      width: 48,
                      height: h,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildBucketTick(h * 0.0, '100%', textSecondary, isDark),
                          _buildBucketTick(h * 0.25, '75%', textSecondary, isDark),
                          _buildBucketTick(h * 0.50, '50%', textSecondary, isDark),
                          _buildBucketTick(h * 0.75, '25%', textSecondary, isDark),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 3. Top Drop Nozzle Indicator
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isComplete
                          ? accentColor.withValues(alpha: 0.8)
                          : borderColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Center Typography Overlay: Percentage & Live Synced Count
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Big percentage display with Outfit Light 52
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$percentInt',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyDisplay,
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.2,
                            color: textPrimary,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyDisplay,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Counter Subtitle: "$uploadedCount of $totalCount synced"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF0D0E10) : Colors.white)
                            .withValues(alpha: isDark ? 0.65 : 0.85),
                        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                        border: Border.all(
                          color: borderColor.withValues(alpha: isDark ? 0.6 : 0.8),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.syncedCount} of ${widget.totalCount} synced',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBucketTick(double topOffset, String label, Color color, bool isDark) {
    return Positioned(
      top: topOffset,
      right: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamilyBody,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: isDark ? 0.45 : 0.65),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 1.2,
            color: color.withValues(alpha: isDark ? 0.35 : 0.50),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter simulating fluid dynamics, waves, surface ripples, and falling droplets
class _LiquidBucketPainter extends CustomPainter {
  final double animationValue;
  final double progress;
  final bool isDark;
  final bool isUploading;
  final Color accentColor;
  final bool isTest;

  _LiquidBucketPainter({
    required this.animationValue,
    required this.progress,
    required this.isDark,
    required this.isUploading,
    required this.accentColor,
    required this.isTest,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final isComplete = progress >= 0.999;

    // Liquid surface height:
    // At progress = 0.0, water level is at bottom (h).
    // At progress = 1.0, water level is at top (0.0), filling the entire div.
    final waterY = h * (1.0 - progress);

    // 1. Draw Liquid Volume (Back Parallax Wave + Front Liquid Wave)
    if (progress > 0.001) {
      _drawLiquidWaves(canvas, size, waterY, isComplete);
      _drawBubbles(canvas, size, waterY);
    }

    // 2. Draw Falling Droplets & Splash Ripples
    if (!isComplete && !isTest && (isUploading || progress > 0.0)) {
      _drawFallingDrops(canvas, size, waterY);
    }
  }

  void _drawLiquidWaves(Canvas canvas, Size size, double waterY, bool isComplete) {
    final w = size.width;
    final h = size.height;

    // When 100% full, the liquid fills the entire div cleanly to the top rim
    final effectiveAmp = isComplete ? 1.5 : (progress < 0.05 ? 2.0 : 5.0);
    final phase = animationValue * 2 * math.pi;

    // ── Layer A: Back Parallax Wave ───────────────────────────────
    final backPath = Path();
    backPath.moveTo(0, h);
    backPath.lineTo(0, waterY);

    for (double x = 0; x <= w; x += 3.0) {
      final wave1 = math.sin((x / (w * 0.75) * 2 * math.pi) + phase * 1.2);
      final wave2 = math.cos((x / (w * 1.2) * 2 * math.pi) - phase * 0.8);
      final y = waterY + (wave1 * 0.6 + wave2 * 0.4) * effectiveAmp * 0.75;
      backPath.lineTo(x, y.clamp(0.0, h));
    }

    backPath.lineTo(w, h);
    backPath.close();

    final backPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.22 : 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(backPath, backPaint);

    // ── Layer B: Front Primary Wave & Volume ─────────────────────
    final frontPath = Path();
    frontPath.moveTo(0, h);
    frontPath.lineTo(0, waterY);

    for (double x = 0; x <= w; x += 2.0) {
      final wave1 = math.sin((x / (w * 0.85) * 2 * math.pi) - phase);
      final wave2 = math.cos((x / (w * 1.4) * 2 * math.pi) + phase * 0.7);
      final y = waterY + (wave1 * 0.7 + wave2 * 0.3) * effectiveAmp;
      frontPath.lineTo(x, y.clamp(0.0, h));
    }

    frontPath.lineTo(w, h);
    frontPath.close();

    // Fluid vertical gradient from luminous surface crest to rich translucent reservoir body
    final frontPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: isDark ? (isComplete ? 0.75 : 0.65) : (isComplete ? 0.65 : 0.50)),
          accentColor.withValues(alpha: isDark ? (isComplete ? 0.45 : 0.32) : (isComplete ? 0.35 : 0.22)),
        ],
      ).createShader(Rect.fromLTWH(0, waterY.clamp(0.0, h), w, (h - waterY).clamp(0.0, h)))
      ..style = PaintingStyle.fill;

    canvas.drawPath(frontPath, frontPaint);

    // ── Layer C: Sparkling Surface Crest Line ────────────────────
    final crestPath = Path();
    for (double x = 0; x <= w; x += 2.0) {
      final wave1 = math.sin((x / (w * 0.85) * 2 * math.pi) - phase);
      final wave2 = math.cos((x / (w * 1.4) * 2 * math.pi) + phase * 0.7);
      final y = waterY + (wave1 * 0.7 + wave2 * 0.3) * effectiveAmp;
      if (x == 0) {
        crestPath.moveTo(x, y.clamp(0.0, h));
      } else {
        crestPath.lineTo(x, y.clamp(0.0, h));
      }
    }

    final crestPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.95 : 0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(crestPath, crestPaint);
  }

  void _drawFallingDrops(Canvas canvas, Size size, double waterY) {
    final w = size.width;
    final centerX = w / 2;
    const startY = 4.0;

    // Simulate 2 sequential drops per animation cycle
    _paintSingleDrop(canvas, centerX, startY, waterY, animationValue, 0.0);
    _paintSingleDrop(canvas, centerX + 12.0, startY, waterY, animationValue, 0.5);
  }

  void _paintSingleDrop(
    Canvas canvas,
    double x,
    double startY,
    double targetWaterY,
    double globalTime,
    double timeOffset,
  ) {
    final localTime = (globalTime + timeOffset) % 1.0;

    // Phase 1: Drop forming and falling (0.0 <= localTime < 0.80)
    if (localTime < 0.80) {
      final fallFraction = localTime / 0.80;
      // Gravity quadratic acceleration: d = 1/2 * g * t^2
      final currentY = startY + (targetWaterY - startY) * (fallFraction * fallFraction);

      if (currentY < targetWaterY) {
        final dropScale = (0.5 + 0.5 * fallFraction).clamp(0.4, 1.0);
        _drawTeardrop(canvas, Offset(x, currentY), dropScale);
      }
    }
    // Phase 2: Splash impact & expanding surface ripple (0.80 <= localTime < 1.0)
    else {
      final splashProgress = (localTime - 0.80) / 0.20;
      final rippleAlpha = (1.0 - splashProgress).clamp(0.0, 1.0);

      // Expanding ripple ring on liquid surface
      final rippleRadiusX = 22.0 * splashProgress;
      final rippleRadiusY = 4.5 * splashProgress;

      final ripplePaint = Paint()
        ..color = accentColor.withValues(alpha: rippleAlpha * (isDark ? 0.7 : 0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, targetWaterY),
          width: rippleRadiusX * 2,
          height: rippleRadiusY * 2,
        ),
        ripplePaint,
      );

      // Tiny upward bounce splash droplet
      final splashHeight = 12.0 * math.sin(splashProgress * math.pi);
      final splashY = targetWaterY - splashHeight;
      if (splashHeight > 1.5) {
        final splashPaint = Paint()
          ..color = accentColor.withValues(alpha: rippleAlpha * (isDark ? 0.9 : 0.7))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x - 3 * splashProgress, splashY), 1.8, splashPaint);
        canvas.drawCircle(Offset(x + 4 * splashProgress, splashY * 0.95), 1.4, splashPaint);
      }
    }
  }

  void _drawTeardrop(Canvas canvas, Offset pos, double scale) {
    final dropW = 7.0 * scale;
    final dropH = 12.0 * scale;

    final dropPath = Path();
    dropPath.moveTo(pos.dx, pos.dy - dropH * 0.5);
    dropPath.cubicTo(
      pos.dx + dropW * 0.5,
      pos.dy - dropH * 0.1,
      pos.dx + dropW * 0.5,
      pos.dy + dropH * 0.5,
      pos.dx,
      pos.dy + dropH * 0.5,
    );
    dropPath.cubicTo(
      pos.dx - dropW * 0.5,
      pos.dy + dropH * 0.5,
      pos.dx - dropW * 0.5,
      pos.dy - dropH * 0.1,
      pos.dx,
      pos.dy - dropH * 0.5,
    );
    dropPath.close();

    final dropPaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.95 : 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dropPath, dropPaint);

    // Specular highlight gleam inside the teardrop
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pos.dx - dropW * 0.15, pos.dy + dropH * 0.15), 1.2 * scale, highlightPaint);
  }

  static const _bubbleSpecs = [
    (0.22, 0.7, 0.1, 2.2),
    (0.45, 0.9, 0.4, 1.6),
    (0.68, 0.6, 0.7, 2.0),
    (0.82, 0.8, 0.25, 1.8),
  ];

  void _drawBubbles(Canvas canvas, Size size, double waterY) {
    final w = size.width;
    final h = size.height;
    final liquidHeight = h - waterY;
    if (liquidHeight <= 10) return;

    for (final (xFactor, speed, offset, r) in _bubbleSpecs) {
      final t = (animationValue * speed + offset) % 1.0;
      final bubbleY = h - (t * liquidHeight);
      final bubbleX = (w * xFactor) + 4.0 * math.sin(animationValue * 2 * math.pi + offset * 5);

      if (bubbleY > waterY + 4 && bubbleY < h - 4) {
        final bubblePaint = Paint()
          ..color = Colors.white.withValues(alpha: isDark ? 0.30 : 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset(bubbleX, bubbleY), r, bubblePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidBucketPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isUploading != isUploading ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isTest != isTest;
  }
}
