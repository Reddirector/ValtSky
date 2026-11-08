import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../util/theme.dart';

// Re-export modular components for complete backwards compatibility
export 'sky_orb_hero.dart';
export 'valtsky_navigation_dock.dart';

// ─── 1. CAP SLAB (SOLID INK HEADER SLAB WITH R=40) ─────────────────────────
/// Solid ink cap slab positioned at the top of every screen
class CapSlab extends StatelessWidget {
  final Widget child;
  final double bottomRadius;
  final EdgeInsetsGeometry padding;

  const CapSlab({
    super.key,
    required this.child,
    this.bottomRadius = ValtSkyTheme.radiusCapSlab,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 36),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slabColor = ValtSkyTheme.capSlab(isDark);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: slabColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
        border: isDark
            ? Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: ValtSkyTheme.capSlabText(isDark),
          fontFamily: ValtSkyTheme.fontFamilyBody,
        ),
        child: child,
      ),
    );
  }
}

// ─── 2. STRADDLE HERO CARD ─────────────────────────────────────────────────
/// Surface/white card straddling the cap slab edge (overlapping)
class StraddleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const StraddleCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      child: child,
    );
  }
}

// ─── 3. PILL BUTTON ────────────────────────────────────────────────────────
/// Tactile Pill Button with Spring Scale (0.97), Light Haptic feedback on mobile,
/// Trailing circular arrow support, Focus ring for keyboard, and min 48x48 hit area.
enum PillButtonVariant { primary, secondary, outline, destructive }

class PillButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final bool isLoading;
  final double height;
  final double? width;
  final bool showTrailingArrow;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.isLoading = false,
    this.height = 48.0,
    this.width,
    this.showTrailingArrow = false,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
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
    BorderSide border = BorderSide.none;

    switch (widget.variant) {
      case PillButtonVariant.primary:
        if (isEnabled) {
          bg = ValtSkyTheme.primaryCtaFill(isDark);
          fg = ValtSkyTheme.primaryCtaText(isDark);
        } else {
          bg = ValtSkyTheme.primaryCtaFill(isDark).withValues(alpha: 0.35);
          fg = ValtSkyTheme.primaryCtaText(isDark).withValues(alpha: 0.45);
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
        bg = _isPressed ? ValtSkyTheme.failed(isDark).withValues(alpha: 0.20) : Colors.transparent;
        fg = isEnabled ? ValtSkyTheme.failed(isDark) : ValtSkyTheme.failed(isDark).withValues(alpha: 0.40);
        border = BorderSide(
          color: isEnabled ? ValtSkyTheme.failed(isDark).withValues(alpha: 0.60) : ValtSkyTheme.failed(isDark).withValues(alpha: 0.25),
          width: 1.0,
        );
        break;
    }

    final scale = (reduceMotion || !_isPressed) ? 1.0 : 0.97;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.label,
      child: ConstrainedBox(
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
                  color: bg,
                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  border: border != BorderSide.none
                      ? Border.fromBorderSide(border)
                      : (_isFocused
                          ? Border.all(color: ValtSkyTheme.accent(isDark), width: 2.0)
                          : null),
                  boxShadow: [
                    if (widget.variant == PillButtonVariant.primary && isEnabled)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: fg,
                              ),
                            ),
                          ),
                          if (widget.showTrailingArrow) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.20)
                                    : Colors.white.withValues(alpha: 0.22),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: fg),
                            ),
                          ],
                        ],
                      ),
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

    final trackBg = widget.value
        ? (isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk)
        : Colors.transparent;
    final trackBorder = Border.all(
      color: widget.value ? Colors.transparent : ValtSkyTheme.hairline(isDark),
      width: 1.5,
    );
    final thumbColor = widget.value
        ? (isDark ? ValtSkyTheme.darkCanvas : Colors.white)
        : ValtSkyTheme.textTertiary(isDark);

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
                  color: trackBg,
                  border: trackBorder,
                ),
                child: Align(
                  alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _isPressed ? 30 : 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                      color: thumbColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
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
                      ? (isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
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
                        ? (isDark ? ValtSkyTheme.darkCanvas : ValtSkyTheme.paper)
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
        ? (isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk)
        : Colors.transparent;
    final fg = isSelected
        ? (isDark ? ValtSkyTheme.darkCanvas : ValtSkyTheme.paper)
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
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
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
                          ? (isDark ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.20))
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

// ─── 7. BENTO STAT TILE (ICONIC EDITORIAL MEDIA REDESIGN) ────────────────────
/// Redesigned to showcase media with an enlarged formatted logo,
/// bold grayish background watermark numeral on the right side,
/// and iconic ambient geometry filling the tab.
class StatTile extends StatelessWidget {
  final String? label;
  final String? title;
  final dynamic value;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool hasAlert;
  final bool isTall;

  const StatTile({
    super.key,
    this.label,
    this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.accentColor,
    this.hasAlert = false,
    this.isTall = false,
  });

  String get effectiveLabel => label ?? title ?? '';
  int get intValue => value is int ? value : (int.tryParse('$value') ?? 0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color effectiveAccent = accentColor ?? (isDark ? Colors.white : ValtSkyTheme.lightInk);
    if (hasAlert && intValue > 0) {
      effectiveAccent = ValtSkyTheme.failed(isDark);
    } else if (effectiveLabel.contains('SYNCED') && intValue > 0) {
      effectiveAccent = ValtSkyTheme.synced(isDark);
    } else if (effectiveLabel.contains('QUEUE') && intValue > 0) {
      effectiveAccent = ValtSkyTheme.warning;
    } else if (effectiveLabel.contains('TOTAL') && intValue > 0) {
      effectiveAccent = ValtSkyTheme.accent(isDark);
    }

    final cardMinHeight = isTall ? 140.0 : 116.0;

    return Semantics(
      label: '$effectiveLabel: $intValue',
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: ValtSkyTheme.cardDecoration(
            isDark: isDark,
            surfaceLevel: 1,
            radius: ValtSkyTheme.radiusTile,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusTile),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ValtSkyTheme.radiusTile),
              child: Container(
                constraints: BoxConstraints(minHeight: cardMinHeight),
                child: Stack(
                  children: [
                    // 1. Ambient Formatted Watermark covering the tab background
                    Positioned(
                      right: -8,
                      bottom: -10,
                      child: Icon(
                        icon,
                        size: isTall ? 92 : 80,
                        color: effectiveAccent.withValues(
                          alpha: isDark ? 0.06 : 0.04,
                        ),
                      ),
                    ),

                    // 2. Bold Grayish Faded Number on the Right Side
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 82),
                            child: TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: intValue),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedVal, _) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '$animatedVal',
                                    style: TextStyle(
                                      fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                      fontSize: isTall ? 60 : 48,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.5,
                                      color: isDark
                                          ? const Color(0xFF8E95A5).withValues(alpha: 0.22)
                                          : const Color(0xFF4A5478).withValues(alpha: 0.18),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Foreground Content: Formatted Logo + Dash + Small-Caps Label
                    Padding(
                      padding: EdgeInsets.all(isTall ? 16 : 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Enlarged & Formatted Logo Container (Quite big, iconic showcase)
                          Container(
                            width: isTall ? 54 : 46,
                            height: isTall ? 54 : 46,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (intValue > 0 && effectiveAccent != Colors.white
                                      ? effectiveAccent.withValues(alpha: 0.14)
                                      : ValtSkyTheme.darkSurface2)
                                  : (intValue > 0 && effectiveAccent != ValtSkyTheme.lightInk
                                      ? effectiveAccent.withValues(alpha: 0.10)
                                      : ValtSkyTheme.lightInk),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (intValue > 0 && effectiveAccent != (isDark ? Colors.white : ValtSkyTheme.lightInk)
                                    ? effectiveAccent.withValues(alpha: isDark ? 0.45 : 0.6)
                                    : ValtSkyTheme.hairline(isDark)),
                                width: 0.9,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              icon,
                              size: isTall ? 30 : 25,
                              color: intValue > 0 && effectiveAccent != (isDark ? Colors.white : ValtSkyTheme.lightInk)
                                  ? effectiveAccent
                                  : Colors.white,
                            ),
                          ),

                          SizedBox(height: isTall ? 16 : 10),

                          // 16x2.5 Capsule Dash Divider
                          Container(
                            width: 16,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: (intValue > 0 && effectiveAccent != (isDark ? Colors.white : ValtSkyTheme.lightInk)
                                  ? effectiveAccent
                                  : ValtSkyTheme.hairline(isDark)),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),

                          const SizedBox(height: 5),

                          // Small-Caps Label
                          Text(
                            effectiveLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ValtSkyTheme.capsLabel(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 8. QUICK CONTROL CARD (2x2 OUTLINED, MIN 64PT TALL) ───────────────────
class QuickControlCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isSecondary;
  final bool disabled;

  const QuickControlCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.isSecondary = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onTap != null && !disabled;

    Color iconCol;
    if (isDestructive) {
      iconCol = ValtSkyTheme.failed(isDark);
    } else if (!isEnabled) {
      iconCol = ValtSkyTheme.textTertiary(isDark);
    } else {
      iconCol = ValtSkyTheme.textPrimary(isDark);
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: isEnabled
              ? ValtSkyTheme.surface(isDark, level: 1)
              : ValtSkyTheme.surface(isDark, level: 1).withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
          border: Border.all(
            color: isDestructive && isEnabled
                ? ValtSkyTheme.failed(isDark).withValues(alpha: 0.35)
                : ValtSkyTheme.hairline(isDark),
            width: 1.0,
          ),
        ),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Leading Icon Circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ValtSkyTheme.surface(isDark, level: 2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconCol),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ValtSkyTheme.fontFamilyBody,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? ValtSkyTheme.textPrimary(isDark)
                          : ValtSkyTheme.textTertiary(isDark),
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

// ─── 9. SECTION CARD ───────────────────────────────────────────────────────
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? ValtSkyTheme.darkSurface2 : ValtSkyTheme.lightInk,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: ValtSkyTheme.capsLabel(isDark: isDark, color: ValtSkyTheme.textPrimary(isDark)),
                    ),
                    const SizedBox(height: 6),
                    // 16x2 Dash Divider
                    Container(
                      width: 16,
                      height: 2,
                      decoration: BoxDecoration(
                        color: ValtSkyTheme.hairline(isDark),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamilyBody,
                fontSize: 12.5,
                color: ValtSkyTheme.textSecondary(isDark),
                height: 1.35,
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
            color: Colors.black.withValues(alpha: 0.16),
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
