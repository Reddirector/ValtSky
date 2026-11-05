import 'package:flutter/material.dart';
import '../../util/theme.dart';

class DashboardControlDeck extends StatelessWidget {
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final bool isScanning;
  final bool isRestarting;
  final VoidCallback onTogglePause;
  final VoidCallback onScanGallery;
  final VoidCallback onRestartEngine;
  final VoidCallback onShowDiagnostics;

  const DashboardControlDeck({
    super.key,
    required this.isConfigured,
    required this.isMonitoring,
    required this.isPaused,
    required this.isScanning,
    required this.isRestarting,
    required this.onTogglePause,
    required this.onScanGallery,
    required this.onRestartEngine,
    required this.onShowDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: isPaused ? 'Resume' : 'Pause',
                subtitle: isPaused ? 'Continue upload' : 'Halt workers',
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                accentColor: isPaused ? ValtSkyTheme.success : ValtSkyTheme.warning,
                isDark: isDark,
                isEnabled: isMonitoring,
                onTap: isMonitoring ? onTogglePause : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Scan Gallery',
                subtitle: isScanning ? 'Indexing...' : 'Check captures',
                icon: Icons.photo_camera_back_outlined,
                accentColor: const Color(0xFF06B6D4),
                isDark: isDark,
                isLoading: isScanning,
                onTap: isScanning ? null : onScanGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Restart Engine',
                subtitle: isRestarting ? 'Healing...' : 'Reset sockets',
                icon: Icons.sync_problem_rounded,
                accentColor: const Color(0xFF8B5CF6),
                isDark: isDark,
                isLoading: isRestarting,
                onTap: isRestarting ? null : onRestartEngine,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Diagnostics',
                subtitle: 'Health & state',
                icon: Icons.terminal_rounded,
                accentColor: const Color(0xFF10B981),
                isDark: isDark,
                onTap: onShowDiagnostics,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    final bg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final opacity = isEnabled ? 1.0 : 0.45;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 6),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        )
                      : Icon(icon, size: 20, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
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
