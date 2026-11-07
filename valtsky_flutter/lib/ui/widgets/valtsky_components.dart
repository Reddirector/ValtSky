import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../util/theme.dart';

// ─── 1. SKY ORB HERO WIDGET ────────────────────────────────────────────────
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

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _generateStarfield();
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

// ─── 2. RADIAL TICK RING (COMPATIBILITY WRAPPER) ───────────────────────────
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

// ─── 3. PILL BUTTON ────────────────────────────────────────────────────────
/// Tactile Pill Button with Spring Scale (0.96), Light Haptic feedback on mobile,
/// Focus ring for keyboard, and min 48x48 hit area.
enum PillButtonVariant { primary, secondary, outline, destructive }

class PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final bool isLoading;
  final double height;
  final double? width;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Color bg = Colors.transparent;
    Color fg = ValtSkyTheme.textPrimary(isDark);
    Gradient? gradient;
    BorderSide border = BorderSide.none;

    switch (widget.variant) {
      case PillButtonVariant.primary:
        if (isEnabled) {
          gradient = ValtSkyTheme.primaryCtaGradient(isDark);
          fg = isDark ? ValtSkyTheme.ink : Colors.white;
        } else {
          bg = ValtSkyTheme.darkAccent.withValues(alpha: 0.35);
          fg = isDark ? ValtSkyTheme.ink : Colors.white70;
        }
        break;

      case PillButtonVariant.secondary:
        bg = isEnabled
            ? (_isPressed ? ValtSkyTheme.surface(isDark, level: 3) : ValtSkyTheme.surface(isDark, level: 2))
            : ValtSkyTheme.surface(isDark, level: 2).withValues(alpha: 0.45);
        fg = ValtSkyTheme.textPrimary(isDark);
        border = BorderSide(color: ValtSkyTheme.hairline(isDark), width: 1.0);
        break;

      case PillButtonVariant.outline:
        bg = _isPressed ? ValtSkyTheme.surface(isDark, level: 2).withValues(alpha: 0.35) : Colors.transparent;
        fg = isEnabled ? ValtSkyTheme.textPrimary(isDark) : ValtSkyTheme.textSecondary(isDark);
        border = BorderSide(
          color: isEnabled ? ValtSkyTheme.hairline(isDark) : ValtSkyTheme.hairline(isDark).withValues(alpha: 0.35),
          width: 1.0,
        );
        break;

      case PillButtonVariant.destructive:
        bg = _isPressed ? ValtSkyTheme.statusFailed.withValues(alpha: 0.20) : Colors.transparent;
        fg = isEnabled ? ValtSkyTheme.statusFailed : ValtSkyTheme.statusFailed.withValues(alpha: 0.40);
        border = BorderSide(
          color: isEnabled ? ValtSkyTheme.statusFailed.withValues(alpha: 0.60) : ValtSkyTheme.statusFailed.withValues(alpha: 0.25),
          width: 1.0,
        );
        break;
    }

    final scale = (reduceMotion || !_isPressed) ? 1.0 : 0.96;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 48.0,
        minWidth: 48.0,
        maxWidth: widget.width ?? double.infinity,
      ),
      child: FocusableActionDetector(
        onShowFocusHighlight: (f) => setState(() => _isFocused = f),
        onShowHoverHighlight: (h) => setState(() => _isHovered = h),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: isEnabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: widget.height,
              width: widget.width,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: gradient == null ? bg : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                border: border != BorderSide.none
                    ? Border.fromBorderSide(border)
                    : (_isFocused
                        ? Border.all(color: ValtSkyTheme.darkAccent, width: 2.0)
                        : null),
                boxShadow: [
                  if (widget.variant == PillButtonVariant.primary && isEnabled)
                    BoxShadow(
                      color: ValtSkyTheme.darkAccent.withValues(alpha: isDark ? 0.30 : 0.22),
                      blurRadius: _isHovered ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 18, color: fg),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyBody,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: fg,
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

// ─── 4. CUSTOM MORPHING TOGGLE ROW ─────────────────────────────────────────
/// Pill track with thumb that stretches slightly on press and spring animates.
class MorphingToggleRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const MorphingToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<MorphingToggleRow> createState() => _MorphingToggleRowState();
}

class _MorphingToggleRowState extends State<MorphingToggleRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      toggled: widget.value,
      label: widget.title,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onChanged(!widget.value);
        },
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: ValtSkyTheme.textPrimary(isDark),
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 12.0,
                          color: ValtSkyTheme.textSecondary(isDark),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Morphing Toggle Pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  color: widget.value
                      ? (isDark ? ValtSkyTheme.darkAccent : ValtSkyTheme.lightAccentFill)
                      : ValtSkyTheme.surface(isDark, level: 3),
                  border: Border.all(
                    color: ValtSkyTheme.hairline(isDark),
                    width: 1.0,
                  ),
                ),
                child: Align(
                  alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _isPressed ? 30 : 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                      color: widget.value
                          ? (isDark ? ValtSkyTheme.ink : Colors.white)
                          : ValtSkyTheme.textSecondary(isDark),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 5. SLIDING SEGMENTED CONTROL ──────────────────────────────────────────
class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption({required this.value, required this.label});
}

class SegmentedPillControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  const SegmentedPillControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ValtSkyTheme.surface(isDark, level: 3),
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
        border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1.0),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.value == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(opt.value);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? ValtSkyTheme.darkAccent : ValtSkyTheme.lightAccentFill)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 12.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? ValtSkyTheme.ink : Colors.white)
                        : ValtSkyTheme.textSecondary(isDark),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 6. FILTER PILL ────────────────────────────────────────────────────────
class FilterPill extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterPill({
    super.key,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isSelected
        ? (isDark ? ValtSkyTheme.darkAccent : ValtSkyTheme.lightAccentFill)
        : ValtSkyTheme.surface(isDark, level: 2);
    final fg = isSelected
        ? (isDark ? ValtSkyTheme.ink : Colors.white)
        : ValtSkyTheme.textSecondary(isDark);
    final border = isSelected
        ? BorderSide.none
        : BorderSide(color: ValtSkyTheme.hairline(isDark), width: 1.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
              border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ValtSkyTheme.darkAccent.withValues(alpha: isDark ? 0.28 : 0.16),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 12.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? Colors.black.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.25))
                          : ValtSkyTheme.surface(isDark, level: 3),
                      borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyDisplay,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 7. BENTO STAT TILE ────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isTall;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.accentColor,
    this.isTall = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color numeralColor = ValtSkyTheme.textPrimary(isDark);
    if (accentColor != null && value > 0) {
      numeralColor = accentColor!;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusTile),
        child: Container(
          padding: EdgeInsets.all(isTall ? 18 : 14),
          decoration: ValtSkyTheme.cardDecoration(
            isDark: isDark,
            surfaceLevel: 1,
            radius: ValtSkyTheme.radiusTile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ValtSkyTheme.capsLabel(isDark: isDark),
                    ),
                  ),
                  Icon(icon, size: 16, color: ValtSkyTheme.textTertiary(isDark)),
                ],
              ),
              SizedBox(height: isTall ? 24 : 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: value),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, animatedVal, _) {
                  return Text(
                    '$animatedVal',
                    style: isTall
                        ? ValtSkyTheme.heroNumeral(isDark: isDark, color: numeralColor)
                        : ValtSkyTheme.statNumeral(isDark: isDark, color: numeralColor),
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

// ─── 8. SECTION CARD ───────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.surface(isDark, level: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: ValtSkyTheme.accent(isDark)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyDisplay,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamilyBody,
                fontSize: 12.5,
                color: ValtSkyTheme.textSecondary(isDark),
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── 9. FLOATING GLASS DOCK (COMPACT & MEDIUM) ─────────────────────────────
class ValtSkyNavigationDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const ValtSkyNavigationDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final destinations = [
      (Icons.cloud_outlined, Icons.cloud_rounded, 'Dashboard'),
      (Icons.format_list_bulleted_rounded, Icons.fact_check_rounded, 'Queue & Activity'),
      (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
    ];

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? ValtSkyTheme.darkOverlay.withValues(alpha: 0.92)
            : ValtSkyTheme.lightSurface1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
        border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(destinations.length, (idx) {
          final item = destinations[idx];
          final isSelected = selectedIndex == idx;

          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDestinationSelected(idx);
                },
                borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? ValtSkyTheme.activeDockGradient(isDark) : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.$2 : item.$1,
                        size: 20,
                        color: isSelected
                            ? (isDark ? ValtSkyTheme.ink : Colors.white)
                            : ValtSkyTheme.textSecondary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? ValtSkyTheme.ink : Colors.white)
                              : ValtSkyTheme.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── 10. HERO CUT-OUT CONTAINER (COMPATIBILITY) ────────────────────────────
class HeroCutoutContainer extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

  const HeroCutoutContainer({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.radius = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
