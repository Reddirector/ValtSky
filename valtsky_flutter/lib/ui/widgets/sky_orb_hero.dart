import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../util/theme.dart';

// ─── 1. INK & PAPER SYNC RING ──────────────────────────────────────────────
/// Circular Progress Ring in Editorial Monochrome Minimalism
/// Features:
/// - 120pt diameter, 6pt stroke
/// - Hairline background track
/// - Solid ink arc (paper white in dark mode)
/// - Restrained accent glowing head dot (pulses only while actively transferring)
/// - Center percentage numeral in Outfit Light 56
/// - RepaintBoundary for 60fps GPU caching
class InkPaperSyncRing extends StatelessWidget {
  final double progress;
  final int totalCount;
  final int syncedCount;
  final double size;
  final bool isUploading;

  const InkPaperSyncRing({
    super.key,
    required this.progress,
    required this.totalCount,
    required this.syncedCount,
    this.size = 120.0,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentInt = (clampedProgress * 100).toInt();

    return RepaintBoundary(
      child: Semantics(
        label: '$percentInt percent synchronized',
        value: '$percentInt%',
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Progress Arc Ring Painter
              CustomPaint(
                size: Size(size, size),
                painter: _InkPaperRingPainter(
                  progress: clampedProgress,
                  isDark: isDark,
                  isUploading: isUploading,
                ),
              ),

              // 2. Big % in Outfit Light 56
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: percentInt),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, animatedVal, _) {
                  final fontSize = size >= 120 ? 44.0 : 32.0;
                  final percentSize = size >= 120 ? 18.0 : 14.0;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$animatedVal',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyDisplay,
                          fontSize: fontSize,
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
                          fontSize: percentSize,
                          fontWeight: FontWeight.w400,
                          color: ValtSkyTheme.textSecondary(isDark),
                          height: 1.0,
                        ),
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

class _InkPaperRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final bool isUploading;

  _InkPaperRingPainter({
    required this.progress,
    required this.isDark,
    required this.isUploading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 6.0;
    final radius = (size.width - strokeWidth) / 2;

    // 1. Hairline Track
    final trackPaint = Paint()
      ..color = ValtSkyTheme.surface(isDark, level: 3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. High-Contrast Ink Arc
    if (progress > 0.005) {
      final sweepAngle = 2 * math.pi * progress;
      final rect = Rect.fromCircle(center: center, radius: radius);

      final arcPaint = Paint()
        ..color = isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, arcPaint);

      // 3. Glowing Accent Head Dot
      final headAngle = -math.pi / 2 + sweepAngle;
      final headPoint = Offset(
        center.dx + radius * math.cos(headAngle),
        center.dy + radius * math.sin(headAngle),
      );

      final accentCol = ValtSkyTheme.accent(isDark);

      if (isUploading) {
        final glowPaint = Paint()
          ..color = accentCol.withValues(alpha: isDark ? 0.65 : 0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(headPoint, strokeWidth * 0.9, glowPaint);
      }

      final headCore = Paint()
        ..color = accentCol
        ..style = PaintingStyle.fill;
      canvas.drawCircle(headPoint, strokeWidth * 0.5, headCore);
    }
  }

  @override
  bool shouldRepaint(_InkPaperRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isUploading != isUploading;
  }
}

// ─── 2. THIN LINE-ART SWIRL (CUSTOMPAINTER) ─────────────────────────────────
/// Decorative organic hairline curve (~6% opacity, drawn in code, never over text).
/// Static GPU-cached CustomPainter with zero animation/frame overhead.
class LineArtSwirl extends StatelessWidget {
  final double opacity;
  const LineArtSwirl({super.key, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SwirlPainter(
            isDark: isDark,
            progress: 1.0,
            opacity: opacity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  final bool isDark;
  final double progress;
  final double opacity;

  _SwirlPainter({
    required this.isDark,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = ValtSkyTheme.textPrimary(isDark).withValues(alpha: opacity);
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Organic editorial wave swooshes
    path.moveTo(w * 0.85, 0);
    path.cubicTo(w * 0.95, h * 0.25, w * 0.15, h * 0.45, w * 0.80, h * 0.70);
    path.cubicTo(w * 0.95, h * 0.78, w * 0.65, h * 0.90, w * 0.30, h);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SwirlPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.opacity != opacity;
  }
}

// ─── 3. COMPATIBILITY ALIASES ──────────────────────────────────────────────
class SkyOrbHero extends StatelessWidget {
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
    this.size = 120.0,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkPaperSyncRing(
      progress: progress,
      totalCount: totalCount,
      syncedCount: syncedCount,
      size: size,
      isUploading: isUploading,
    );
  }
}

class RadialTickRing extends StatelessWidget {
  final double progress;
  final double size;
  final int totalTicks;

  const RadialTickRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.totalTicks = 36,
  });

  @override
  Widget build(BuildContext context) {
    return InkPaperSyncRing(
      progress: progress,
      totalCount: 36,
      syncedCount: (progress * 36).round(),
      size: size,
    );
  }
}
