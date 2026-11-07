import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../util/theme.dart';

// ─── VALTSKY FLOATING NAVIGATION DOCK ──────────────────────────────────────
/// Floating Glass Pill Navigation Dock with Indigo Glow Indicator,
/// Responsive constraints, and full semantics support.
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

    final destinations = const [
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

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: item.$3,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected ? ValtSkyTheme.activeDockGradient(isDark) : null,
                        color: isSelected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.$2 : item.$1,
                            size: 20,
                            color: isSelected
                                ? (isDark ? ValtSkyTheme.ink : Colors.white)
                                : ValtSkyTheme.textSecondary(isDark),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.$3,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyBody,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? ValtSkyTheme.ink : Colors.white)
                                    : ValtSkyTheme.textSecondary(isDark),
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
        }),
      ),
    );
  }
}
