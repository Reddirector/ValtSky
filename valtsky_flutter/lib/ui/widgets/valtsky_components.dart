import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../util/theme.dart';

// Re-export modular components for complete backwards compatibility
export 'sky_orb_hero.dart';
export 'valtsky_navigation_dock.dart';

// ─── 1. PILL BUTTON ────────────────────────────────────────────────────────
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
      ),
    );
  }
}

// ─── 2. CUSTOM MORPHING TOGGLE ROW ─────────────────────────────────────────
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

// ─── 3. SLIDING SEGMENTED CONTROL ──────────────────────────────────────────
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

// ─── 4. FILTER PILL ────────────────────────────────────────────────────────
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

// ─── 5. BENTO STAT TILE ────────────────────────────────────────────────────
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

    Color numeralColor = ValtSkyTheme.textPrimary(isDark);
    if (accentColor != null && intValue > 0) {
      numeralColor = accentColor!;
    } else if (hasAlert && intValue > 0) {
      numeralColor = ValtSkyTheme.statusFailed;
    }

    return Material(
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
          child: Padding(
            padding: EdgeInsets.all(isTall ? 18 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        effectiveLabel,
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
                  tween: IntTween(begin: 0, end: intValue),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedVal, _) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$animatedVal',
                        style: isTall
                            ? ValtSkyTheme.heroNumeral(isDark: isDark, color: numeralColor)
                            : ValtSkyTheme.statNumeral(isDark: isDark, color: numeralColor),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 6. SECTION CARD ───────────────────────────────────────────────────────
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

// ─── 7. HERO CUT-OUT CONTAINER (COMPATIBILITY) ────────────────────────────
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
