import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../util/theme.dart';

// ─── 1. RADIAL TICK-MARK RING ───────────────────────────────────────────────
/// A circular ring of 36 radial tick marks.
/// Lit ticks = round(progress * 36) in amber (#F2B10F).
/// Unlit ticks = hairline (#2A2A2D Dark / #D0C8BA Light).
/// Center displays the real percentage with a large light-weight numeral.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentInt = (clampedProgress * 100).toInt();

    final unlitColor = ValtSkyTheme.hairline(isDark);
    final litColor = ValtSkyTheme.amber;

    return Semantics(
      label: '$percentInt percent complete',
      value: '$percentInt%',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            reduceMotion
                ? CustomPaint(
                    size: Size(size, size),
                    painter: _RadialTickPainter(
                      progress: clampedProgress,
                      totalTicks: totalTicks,
                      litColor: litColor,
                      unlitColor: unlitColor,
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: clampedProgress),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) {
                      return CustomPaint(
                        size: Size(size, size),
                        painter: _RadialTickPainter(
                          progress: val,
                          totalTicks: totalTicks,
                          litColor: litColor,
                          unlitColor: unlitColor,
                        ),
                      );
                    },
                  ),
            // Percentage readout in the center
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$percentInt',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamily,
                        fontSize: size * 0.28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.5,
                        color: ValtSkyTheme.textPrimary(isDark),
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamily,
                        fontSize: size * 0.12,
                        fontWeight: FontWeight.w500,
                        color: ValtSkyTheme.accentText(isDark),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialTickPainter extends CustomPainter {
  final double progress;
  final int totalTicks;
  final Color litColor;
  final Color unlitColor;

  _RadialTickPainter({
    required this.progress,
    required this.totalTicks,
    required this.litColor,
    required this.unlitColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final tickLength = radius * 0.14;
    final innerRadius = radius - tickLength;
    final litCount = (progress * totalTicks).round();

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, size.width * 0.022);

    for (int i = 0; i < totalTicks; i++) {
      // Start from top (-90 degrees)
      final angle = (2 * math.pi * i / totalTicks) - (math.pi / 2);
      final isLit = i < litCount;

      tickPaint.color = isLit ? litColor : unlitColor;

      final p1 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 2) * math.cos(angle),
        center.dy + (radius - 2) * math.sin(angle),
      );

      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialTickPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.litColor != litColor ||
        oldDelegate.unlitColor != unlitColor;
  }
}

// ─── 2. SIGNATURE CONCAVE HERO CUT-OUT CARD ────────────────────────────────
/// Hero card featuring a signature organic concave curved corner cut-out
/// where the hero panel seamlessly meets the CTA bottom sheet panel.
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
    this.radius = 26.0,
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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
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

// ─── 3. PILL BUTTONS ────────────────────────────────────────────────────────
/// Accessible Pill Button with minimum 48x48 hit area, distinct tactile states,
/// keyboard focus ring, and four distinct visual variants.
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

class _PillButtonState extends State<PillButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (widget.variant) {
      case PillButtonVariant.primary:
        bg = isEnabled
            ? (_isPressed ? const Color(0xFF2EBEAF) : ValtSkyTheme.accentColor)
            : ValtSkyTheme.accentColor.withValues(alpha: 0.40);
        fg = ValtSkyTheme.ink;
        break;
      case PillButtonVariant.secondary:
        bg = isEnabled
            ? (_isPressed ? ValtSkyTheme.hairline(isDark) : ValtSkyTheme.raised(isDark))
            : ValtSkyTheme.raised(isDark).withValues(alpha: 0.45);
        fg = ValtSkyTheme.textPrimary(isDark);
        border = BorderSide(color: ValtSkyTheme.hairline(isDark), width: 1.0);
        break;
      case PillButtonVariant.outline:
        bg = _isPressed ? ValtSkyTheme.hairline(isDark).withValues(alpha: 0.3) : Colors.transparent;
        fg = isEnabled ? ValtSkyTheme.textPrimary(isDark) : ValtSkyTheme.textSecondary(isDark);
        border = BorderSide(
          color: isEnabled ? ValtSkyTheme.hairline(isDark) : ValtSkyTheme.hairline(isDark).withValues(alpha: 0.4),
          width: 1.0,
        );
        break;
      case PillButtonVariant.destructive:
        bg = _isPressed ? ValtSkyTheme.statusFailed.withValues(alpha: 0.20) : Colors.transparent;
        fg = isEnabled ? ValtSkyTheme.statusFailed : ValtSkyTheme.statusFailed.withValues(alpha: 0.40);
        border = BorderSide(
          color: isEnabled ? ValtSkyTheme.statusFailed.withValues(alpha: 0.50) : ValtSkyTheme.statusFailed.withValues(alpha: 0.25),
          width: 1.0,
        );
        break;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 48.0,
        minWidth: 48.0,
        maxWidth: widget.width ?? double.infinity,
      ),
      child: FocusableActionDetector(
        onShowHoverHighlight: (v) => setState(() => _isHovered = v),
        child: GestureDetector(
          onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
          onTap: isEnabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
              border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
              boxShadow: widget.variant == PillButtonVariant.primary && isEnabled
                  ? [
                      BoxShadow(
                        color: ValtSkyTheme.amber.withValues(alpha: isDark ? 0.22 : 0.15),
                        blurRadius: _isHovered ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
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
                            fontFamily: ValtSkyTheme.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
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
    );
  }
}

// ─── 4. SEGMENTED PILL CONTROL ─────────────────────────────────────────────
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
        color: ValtSkyTheme.raised(isDark),
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
        border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1.0),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.value == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? ValtSkyTheme.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? ValtSkyTheme.ink : ValtSkyTheme.textSecondary(isDark),
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

class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption({required this.value, required this.label});
}

// ─── 5. FILTER PILL ────────────────────────────────────────────────────────
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

    final bg = isSelected ? ValtSkyTheme.amber : Colors.transparent;
    final fg = isSelected ? ValtSkyTheme.ink : ValtSkyTheme.textSecondary(isDark);
    final border = isSelected
        ? BorderSide.none
        : BorderSide(color: ValtSkyTheme.hairline(isDark), width: 1.0);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
              border: border != BorderSide.none ? Border.fromBorderSide(border) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ValtSkyTheme.ink.withValues(alpha: 0.14)
                          : ValtSkyTheme.raised(isDark),
                      borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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

// ─── 6. STAT TILE (BIG LIGHT NUMERAL) ──────────────────────────────────────
class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool hasAlert;

  const StatTile({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.onTap,
    this.hasAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = ValtSkyTheme.surface(isDark);
    final borderColor = hasAlert
        ? ValtSkyTheme.statusFailed.withValues(alpha: 0.6)
        : ValtSkyTheme.hairline(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (icon != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: hasAlert ? ValtSkyTheme.statusFailed : ValtSkyTheme.textSecondary(isDark),
                    ),
                    if (hasAlert)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ValtSkyTheme.statusFailed,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.5,
                    color: hasAlert ? ValtSkyTheme.statusFailed : ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ValtSkyTheme.capsLabel(
                  isDark: isDark,
                  color: hasAlert ? ValtSkyTheme.statusFailed : ValtSkyTheme.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 7. SECTION CARD CONTAINER ─────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool isDestructive;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = ValtSkyTheme.surface(isDark);
    final borderColor = isDestructive
        ? ValtSkyTheme.statusFailed.withValues(alpha: 0.4)
        : ValtSkyTheme.hairline(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ValtSkyTheme.capsLabel(
              isDark: isDark,
              color: isDestructive ? ValtSkyTheme.statusFailed : ValtSkyTheme.textSecondary(isDark),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamily,
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

// ─── 8. FLOATING BOTTOM DOCK / DESKTOP NAV RAIL ────────────────────────────
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
        color: ValtSkyTheme.surface(isDark).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
        border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
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
                onTap: () => onDestinationSelected(idx),
                borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? ValtSkyTheme.amber : Colors.transparent,
                    borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.$2 : item.$1,
                        size: 20,
                        color: isSelected ? ValtSkyTheme.ink : ValtSkyTheme.textSecondary(isDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? ValtSkyTheme.ink : ValtSkyTheme.textSecondary(isDark),
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
