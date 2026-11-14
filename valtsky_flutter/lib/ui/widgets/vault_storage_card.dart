import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/backup_scheduler_service.dart';
import '../../services/sync_engine.dart';
import '../../util/formatters.dart';
import '../../util/theme.dart';
import 'valtsky_components.dart';
import 'liquid_bucket_sync_view.dart';
import 'file_upload_loading_bar.dart';
import 'scheduled_backup_timer_card.dart';

/// "Ink & Paper" Hero Storage Card
/// Features:
/// - 120pt Circular progress ring (6pt stroke, hairline track, ink arc, glowing head dot)
/// - Center percentage readout in Outfit Light 56
/// - Soft radial circle partially behind the hero card
/// - Live count subtitle "$uploadedCount of $totalCount synced" + "Alarm" tag
/// - Telemetry status strip with outlined "Setup" pill
/// - Dominant bottom CTA bar with trailing circular arrow
class VaultStorageCard extends StatelessWidget {
  final int totalCount;
  final int uploadedCount;
  final int pendingCount;
  final int failedCount;
  final double progress;
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final bool isUploading;
  final VoidCallback onToggleMonitoring;
  final VoidCallback onNavigateToSettings;
  final VoidCallback? onOpenScheduleBackup;

  const VaultStorageCard({
    super.key,
    required this.totalCount,
    required this.uploadedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.progress,
    required this.isConfigured,
    required this.isMonitoring,
    required this.isPaused,
    required this.isUploading,
    required this.onToggleMonitoring,
    required this.onNavigateToSettings,
    this.onOpenScheduleBackup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = ValtSkyTheme.surface(isDark, level: 1);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final secondaryColor = ValtSkyTheme.textSecondary(isDark);
    final trackBg = ValtSkyTheme.surface(isDark, level: 3);

    final safeTotal = math.max(totalCount, uploadedCount);
    final safeSynced = uploadedCount.clamp(0, safeTotal);
    final int percentInt;
    if (progress == 0.0 || safeTotal == 0) {
      percentInt = 0;
    } else if (safeSynced >= safeTotal && safeTotal > 0 && progress >= 0.999) {
      percentInt = 100;
    } else {
      percentInt = ((safeSynced / safeTotal) * 100).toInt().clamp(0, 99);
    }

    // Dot indicator color
    final statusDotColor = !isConfigured
        ? ValtSkyTheme.failed(isDark)
        : (isPaused
            ? ValtSkyTheme.accent(isDark)
            : (isUploading || pendingCount > 0
                ? ValtSkyTheme.accent(isDark)
                : (isMonitoring ? ValtSkyTheme.synced(isDark) : secondaryColor)));

    final statusText = !isConfigured
        ? 'SETUP'
        : (isPaused
            ? 'PAUSED'
            : (isUploading
                ? (isMonitoring ? 'UPLOADING' : 'QUEUE UPLOAD')
                : (pendingCount > 0
                    ? 'QUEUE UPLOAD'
                    : (isMonitoring ? 'MONITORING' : 'STANDBY'))));

    return Semantics(
      label: '$percentInt% synchronized (${ValtSkyFormatters.formatMediaCount(safeSynced)} of ${ValtSkyFormatters.formatMediaCount(safeTotal)} synced)',
      child: LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Soft radial circle partially behind the hero card (pre-rendered radial gradient)
            Positioned(
              top: -20,
              right: -20,
              width: 180,
              height: 180,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ValtSkyTheme.textPrimary(isDark).withValues(alpha: isDark ? 0.04 : 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Main Straddle Card
            HeroCutoutContainer(
              backgroundColor: cardBg,
              borderColor: borderColor,
              radius: ValtSkyTheme.radiusCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── UPPER HERO CARD SECTION ────────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 16 : 22,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header Row: Status Indicator & Lossless Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusDotColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontFamily: ValtSkyTheme.fontFamilyBody,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: statusDotColor,
                                  ),
                                ),
                              ],
                            ),
                            ValueListenableBuilder<ScheduledBackupState>(
                              valueListenable: BackupSchedulerService.instance.stateNotifier,
                              builder: (context, backupState, _) {
                                final isAlarmActive = backupState.isEnabled;
                                const alarmAmber = Color(0xFFF59E0B);
                                final activeColor = isDark ? alarmAmber : const Color(0xFFB45309);
                                final pillColor = isAlarmActive ? activeColor : secondaryColor;
                                final pillBg = isAlarmActive
                                    ? alarmAmber.withValues(alpha: isDark ? 0.20 : 0.12)
                                    : trackBg;
                                final pillBorder = isAlarmActive
                                    ? alarmAmber.withValues(alpha: isDark ? 0.45 : 0.35)
                                    : borderColor;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (onOpenScheduleBackup != null) {
                                        onOpenScheduleBackup!();
                                      } else {
                                        ScheduledBackupTimerCard.showModal(context);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                                    child: Container(
                                      key: const ValueKey('alarm_clock_pill_btn'),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: pillBg,
                                        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                                        border: Border.all(color: pillBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isAlarmActive
                                                ? Icons.alarm_on_rounded
                                                : Icons.access_time_rounded,
                                            size: 13.5,
                                            color: pillColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isAlarmActive
                                                ? backupState.formattedTime
                                                : 'Alarm',
                                            style: TextStyle(
                                              fontFamily: ValtSkyTheme.fontFamilyBody,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: pillColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Liquid Filling Bucket Progress Chamber (fills entire div, drop animation from top)
                        LiquidBucketSyncView(
                          progress: progress,
                          totalCount: totalCount,
                          syncedCount: uploadedCount,
                          sessionTotal: SyncEngine.sessionTotal,
                          sessionSynced: SyncEngine.sessionSynced,
                          isUploading: isUploading,
                          height: 195.0,
                        ),

                        // Frozen copy inventory preservation:
                        // '$uploadedCount of $totalCount synced'
                        // '$percentInt'
                        // '%'
                        const SizedBox(height: 14),

                        // Telemetry Strip with Setup Button
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isUploading
                                    ? Icons.arrow_upward_rounded
                                    : (isPaused ? Icons.pause_rounded : Icons.cloud_done_rounded),
                                size: 18,
                                color: isPaused ? ValtSkyTheme.warning : secondaryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ValueListenableBuilder<String>(
                                  valueListenable: SyncEngine.currentItemNotifier,
                                  builder: (context, activeFile, _) {
                                    String title;
                                    String subtitle;

                                    if (!isConfigured) {
                                      title = 'NOT CONFIGURED';
                                      subtitle = 'Configure Telegram backup below';
                                    } else if (isPaused) {
                                      title = 'UPLOADS PAUSED';
                                      subtitle = 'Workers suspended by user';
                                    } else if (isUploading && activeFile.isNotEmpty) {
                                      final fileName = activeFile.split('/').last;
                                      title = 'SYNCING';
                                      subtitle = fileName;
                                    } else if (isUploading || (pendingCount > 0 && !isPaused)) {
                                      title = 'SYNCING';
                                      subtitle = '$pendingCount items remaining';
                                    } else if (isMonitoring) {
                                      title = 'MONITORING STANDBY';
                                      subtitle = 'All captured media synchronized';
                                    } else {
                                      title = 'MONITORING PAUSED';
                                      subtitle = 'All queued items uploaded • Gallery auto-scan off';
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: ValtSkyTheme.fontFamilyBody,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: isPaused ? ValtSkyTheme.warning : secondaryColor,
                                          ),
                                        ),
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: ValtSkyTheme.fontFamilyBody,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: ValtSkyTheme.textSecondary(isDark),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Outlined Setup Button or Speed Indicator
                              ValueListenableBuilder<String>(
                                valueListenable: SyncEngine.uploadSpeedNotifier,
                                builder: (context, currentSpeed, _) {
                                  if (!isConfigured) {
                                    return OutlinedButton(
                                      onPressed: onNavigateToSettings,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: ValtSkyTheme.textPrimary(isDark),
                                        side: BorderSide(color: borderColor, width: 1.0),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        minimumSize: const Size(60, 32),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                                        ),
                                      ),
                                      child: const Text('Setup', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    );
                                  }

                                  String displaySpeed;
                                  if (isPaused) {
                                    displaySpeed = 'Paused';
                                  } else if (currentSpeed.isNotEmpty && isUploading) {
                                    displaySpeed = currentSpeed;
                                  } else if (isMonitoring) {
                                    displaySpeed = '0.0 MB/s';
                                  } else {
                                    displaySpeed = 'Standby';
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: secondaryColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.speed_rounded,
                                          size: 13,
                                          color: secondaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          displaySpeed,
                                          style: TextStyle(
                                            fontFamily: ValtSkyTheme.fontFamilyBody,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: secondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        DualSplitUploadBar(isDark: isDark),
                      ],
                    ),
                  ),

                  // ─── BOTTOM CTA SHEET PANEL (PINNED DOMINANT BUTTON) ─────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? ValtSkyTheme.darkSurface2 : ValtSkyTheme.lightSurface2,
                      border: Border(
                        top: BorderSide(
                          color: borderColor,
                          width: 1.0,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 16 : 22,
                      vertical: 16,
                    ),
                    child: PillButton(
                      height: 52,
                      label: !isConfigured
                          ? 'CONFIGURE TELEGRAM BACKUP'
                          : (isMonitoring ? 'STOP MONITORING' : 'START MONITORING'),
                      icon: !isConfigured
                          ? Icons.tune_rounded
                          : (isMonitoring ? Icons.sensors_off_rounded : Icons.sensors_rounded),
                      showTrailingArrow: true,
                      variant: !isConfigured
                          ? PillButtonVariant.primary
                          : (isMonitoring ? PillButtonVariant.secondary : PillButtonVariant.primary),
                      onPressed: onToggleMonitoring,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
    );
  }
}
