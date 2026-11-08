import 'package:flutter/material.dart';
import '../../util/theme.dart';

/// Quick Controls Outlined Cards (Min 64pt tall)
/// Leading icon circle + full label. Stop Process has a failed-color icon only.
/// Houses Pause (or Resume) and Stop Process side-by-side.
class DashboardControlDeck extends StatelessWidget {
  final bool isConfigured;
  final bool isPaused;
  final VoidCallback onTogglePause;
  final VoidCallback onStopProcess;

  const DashboardControlDeck({
    super.key,
    required this.isConfigured,
    required this.isPaused,
    required this.onTogglePause,
    required this.onStopProcess,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final spacing = isNarrow ? 8.0 : 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'QUICK CONTROLS',
                style: ValtSkyTheme.capsLabel(isDark: isDark, color: mutedText),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: isPaused ? 'Resume' : 'Pause',
                    icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    iconColor: ValtSkyTheme.textPrimary(isDark),
                    isDark: isDark,
                    isNarrow: isNarrow,
                    isEnabled: isConfigured,
                    onTap: isConfigured ? onTogglePause : null,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildActionCard(
                    title: 'Stop Process',
                    icon: Icons.stop_circle_outlined,
                    iconColor: ValtSkyTheme.failed(isDark), // Failed-color icon only
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: onStopProcess,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required bool isNarrow,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    final bg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final opacity = isEnabled ? 1.0 : 0.40;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64.0),
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ValtSkyTheme.surface(isDark, level: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  SizedBox(width: isNarrow ? 10 : 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: isNarrow ? 12.5 : 13.5,
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
      ),
    );
  }
}
