import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

class DashboardHeroCard extends StatelessWidget {
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final int uploadedCount;
  final int totalCount;
  final double progress;
  final VoidCallback onToggleMonitoring;

  const DashboardHeroCard({
    super.key,
    required this.isConfigured,
    required this.isMonitoring,
    required this.isPaused,
    required this.uploadedCount,
    required this.totalCount,
    required this.progress,
    required this.onToggleMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engineStatus = SyncEngine.engineStatusNotifier.value;

    final isUploading = !isPaused && (engineStatus == SyncEngineStatus.active || SyncEngine.isPhotoWorkerActive || SyncEngine.isVideoWorkerActive);
    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final percentInt = (progress * 100).toInt();

    // Clean, solid status dot & label
    final Color statusColor = !isConfigured
        ? Colors.grey.shade500
        : (isPaused
            ? ValtSkyTheme.warning
            : (isUploading
                ? const Color(0xFF10B981)
                : (isMonitoring ? const Color(0xFF0EA5E9) : Colors.grey.shade500)));

    final String statusText = !isConfigured
        ? 'SETUP REQUIRED'
        : (isPaused
            ? 'UPLOADS PAUSED'
            : (isUploading
                ? (isMonitoring ? 'MONITORING & UPLOADING' : 'UPLOADING QUEUE')
                : (isMonitoring ? 'MONITORING ACTIVE' : 'IDLE')));

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Clean Status Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<String>(
                valueListenable: SyncEngine.uploadSpeedNotifier,
                builder: (context, currentSpeed, _) {
                  if (!isUploading) return const SizedBox.shrink();
                  final display = currentSpeed.isNotEmpty ? currentSpeed : 'Syncing...';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF06B6D4).withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: Color(0xFF06B6D4),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          display,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Middle Row: Progress Counts & Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$uploadedCount of $totalCount files',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Text(
                '$percentInt%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isPaused
                    ? ValtSkyTheme.warning
                    : (isUploading ? const Color(0xFF10B981) : const Color(0xFF0EA5E9)),
              ),
            ),
          ),

          // Current active upload item
          ValueListenableBuilder<String>(
            valueListenable: SyncEngine.currentItemNotifier,
            builder: (context, activeFile, _) {
              if (activeFile.isEmpty || !isUploading) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        activeFile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // Master Control Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onToggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: !isConfigured
                    ? ValtSkyTheme.telegramBlue
                    : (isMonitoring ? ValtSkyTheme.error : const Color(0xFF10B981)),
                foregroundColor: Colors.white,
                elevation: isMonitoring ? 2 : 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !isConfigured
                        ? Icons.tune_rounded
                        : (isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !isConfigured
                        ? 'CONFIGURE TELEGRAM BACKUP'
                        : (isMonitoring ? 'STOP MONITORING' : 'START MONITORING'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
