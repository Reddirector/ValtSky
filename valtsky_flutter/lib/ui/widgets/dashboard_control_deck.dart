import 'package:flutter/material.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

class DashboardControlDeck extends StatelessWidget {
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final bool isScanning;
  final VoidCallback onTogglePause;
  final VoidCallback onScanGallery;
  final VoidCallback onStopProcess;
  final VoidCallback onShowDiagnostics;

  const DashboardControlDeck({
    super.key,
    required this.isConfigured,
    required this.isMonitoring,
    required this.isPaused,
    required this.isScanning,
    required this.onTogglePause,
    required this.onScanGallery,
    required this.onStopProcess,
    required this.onShowDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: mutedText,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: isPaused ? 'Resume' : 'Pause',
                    icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    accentColor: isPaused ? secondaryColor : ValtSkyTheme.warning,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    isEnabled: isConfigured,
                    onTap: isConfigured ? onTogglePause : null,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildActionCard(
                    title: 'Scan Gallery',
                    icon: Icons.photo_camera_back_outlined,
                    accentColor: primaryColor,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    isLoading: isScanning,
                    onTap: isScanning ? null : onScanGallery,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: 'Stop Process',
                    icon: Icons.stop_circle_outlined,
                    accentColor: ValtSkyTheme.error,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: onStopProcess,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildActionCard(
                    title: 'Diagnostics',
                    icon: Icons.terminal_rounded,
                    accentColor: primaryColor.withAlpha(210),
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: onShowDiagnostics,
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
    required Color accentColor,
    required bool isDark,
    required bool isNarrow,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    final bg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final opacity = isEnabled ? 1.0 : 0.45;

    return Opacity(
      opacity: opacity,
      child: TactilePress(
        onTap: onTap,
        scaleDown: 0.96,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 16,
            vertical: isNarrow ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 28 : 6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isNarrow ? 8 : 10),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: isNarrow ? 18 : 20,
                        height: isNarrow ? 18 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      )
                    : Icon(
                        icon,
                        size: isNarrow ? 20 : 22,
                        color: accentColor,
                      ),
              ),
              SizedBox(width: isNarrow ? 10 : 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isNarrow ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
