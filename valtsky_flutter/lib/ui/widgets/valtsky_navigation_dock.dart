import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../util/theme.dart';

// ─── VALTSKY FLOATING INK NAVIGATION DOCK ──────────────────────────────────
/// Floating Ink Pill Navigation Dock with White Active Circle Indicator,
/// Editorial minimalism, responsive constraints, and full semantics support.
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

    final dockBg = ValtSkyTheme.navDockBackground(isDark);
    final dockBorder = ValtSkyTheme.navDockBorder(isDark);

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
        border: Border.all(color: dockBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : ValtSkyTheme.coffeeBeigeTextPrimary.withValues(alpha: 0.12),
            blurRadius: isDark ? 20 : 16,
            offset: const Offset(0, 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Active Circle for the selected icon
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 36 : 28,
                            height: isSelected ? 36 : 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? ValtSkyTheme.navDockActiveIndicator(isDark)
                                  : Colors.transparent,
                              boxShadow: isSelected && !isDark
                                  ? [
                                      BoxShadow(
                                        color: ValtSkyTheme.coffeeBeigeTextPrimary.withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isSelected ? item.$2 : item.$1,
                              size: 19,
                              color: isSelected
                                  ? ValtSkyTheme.navDockActiveIcon(isDark)
                                  : ValtSkyTheme.navDockInactiveIcon(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.$3,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyBody,
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? ValtSkyTheme.navDockActiveText(isDark)
                                    : ValtSkyTheme.navDockInactiveText(isDark),
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
