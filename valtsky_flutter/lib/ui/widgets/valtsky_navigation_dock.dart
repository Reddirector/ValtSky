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

    final dockBg = isDark ? ValtSkyTheme.darkSurface2 : ValtSkyTheme.lightInk;
    final dockBorder = isDark ? ValtSkyTheme.darkHairline : const Color(0xFF2C2C30);

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
        border: Border.all(color: dockBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
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
                          // White/Paper Active Circle for the selected icon
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 36 : 28,
                            height: isSelected ? 36 : 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? ValtSkyTheme.paper : Colors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isSelected ? item.$2 : item.$1,
                              size: 19,
                              color: isSelected ? ValtSkyTheme.ink : const Color(0xFFA3A3A8),
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
                                color: isSelected ? ValtSkyTheme.paper : const Color(0xFFA3A3A8),
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
