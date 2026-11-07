import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import 'valtsky_components.dart';

class VaultStorageCard extends StatelessWidget {
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final int uploadedCount;
  final int totalCount;
  final double progress;
  final VoidCallback onToggleMonitoring;

  const VaultStorageCard({
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
    final isUploading = !isPaused &&
        (engineStatus == SyncEngineStatus.active ||
            SyncEngine.isPhotoWorkerActive ||
            SyncEngine.isVideoWorkerActive);

    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final trackBg = ValtSkyTheme.raised(isDark);
    final secondaryColor = ValtSkyTheme.accentText(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    final percentInt = (progress.clamp(0.0, 1.0) * 100).toInt();

    final Color statusDotColor = !isConfigured
        ? mutedText
        : (isPaused
            ? ValtSkyTheme.warning
            : (isUploading ? ValtSkyTheme.amber : (isMonitoring ? ValtSkyTheme.statusSynced : mutedText)));

    final String statusText = !isConfigured
        ? 'SETUP'
        : (isPaused
            ? 'PAUSED'
            : (isUploading
                ? (isMonitoring ? 'UPLOADING' : 'QUEUE UPLOAD')
                : (isMonitoring ? 'MONITORING' : 'STANDBY')));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return HeroCutoutContainer(
          backgroundColor: cardBg,
          borderColor: borderColor,
          radius: ValtSkyTheme.radiusCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── UPPER HERO CARD SECTION ──────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 16 : 22,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Status Dot + Tag & Lossless Pill
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
                                fontFamily: ValtSkyTheme.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: statusDotColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 13, color: secondaryColor),
                              const SizedBox(width: 5),
                              Text(
                                'Lossless',
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Row 2: Radial Tick Ring & Live Sync Metrics
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Radial Tick-Mark Ring with Real Percentage (36 Ticks)
                        RadialTickRing(
                          progress: progress,
                          size: isNarrow ? 110 : 124,
                          totalTicks: 36,
                        ),

                        SizedBox(width: isNarrow ? 16 : 22),

                        // Backup Progress Numbers & Labels
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isUploading
                                          ? ValtSkyTheme.amber
                                          : (isPaused ? ValtSkyTheme.warning : mutedText),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isUploading
                                          ? 'UPLOADING TO VAULT'
                                          : (isPaused ? 'UPLOADS PAUSED' : 'VAULT SYNC STATUS'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ValtSkyTheme.capsLabel(
                                        isDark: isDark,
                                        color: isUploading ? ValtSkyTheme.amber : mutedText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '$uploadedCount of $totalCount synced',
                                  style: TextStyle(
                                    fontFamily: ValtSkyTheme.fontFamily,
                                    fontSize: isNarrow ? 16 : 19,
                                    fontWeight: FontWeight.w800,
                                    color: ValtSkyTheme.textPrimary(isDark),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Percentage Pill Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: trackBg,
                                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$percentInt',
                                      style: TextStyle(
                                        fontFamily: ValtSkyTheme.fontFamily,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: ValtSkyTheme.textPrimary(isDark),
                                      ),
                                    ),
                                    Text(
                                      '%',
                                      style: TextStyle(
                                        fontFamily: ValtSkyTheme.fontFamily,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: ValtSkyTheme.accentText(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Row 3: Regulatory Telemetry Strip
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
                                  title = 'TRANSFERRING MEDIA';
                                  subtitle = fileName;
                                } else if (isUploading) {
                                  title = 'QUEUE SYNC ACTIVE';
                                  subtitle = 'Uploading pending items...';
                                } else if (isMonitoring) {
                                  title = 'MONITORING STANDBY';
                                  subtitle = 'All captured media synchronized';
                                } else {
                                  title = 'ENGINE IDLE';
                                  subtitle = 'Press Start Monitoring to scan';
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
                                        fontFamily: ValtSkyTheme.fontFamily,
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
                                        fontFamily: ValtSkyTheme.fontFamily,
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
                          // Speed / Mode Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: secondaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                            ),
                            child: ValueListenableBuilder<String>(
                              valueListenable: SyncEngine.uploadSpeedNotifier,
                              builder: (context, currentSpeed, _) {
                                String displaySpeed;
                                if (!isConfigured) {
                                  displaySpeed = 'Setup';
                                } else if (isPaused) {
                                  displaySpeed = 'Paused';
                                } else if (currentSpeed.isNotEmpty && isUploading) {
                                  displaySpeed = currentSpeed;
                                } else if (isMonitoring) {
                                  displaySpeed = '0.0 MB/s';
                                } else {
                                  displaySpeed = 'Standby';
                                }

                                return Row(
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
                                        fontFamily: ValtSkyTheme.fontFamily,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: secondaryColor,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── BOTTOM CTA SHEET PANEL (SIGNATURE CUT-OUT JUNCTION) ────────
              Container(
                decoration: BoxDecoration(
                  color: ValtSkyTheme.ctaPanelBackground(isDark),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? borderColor : ValtSkyTheme.darkHairline,
                      width: 1.0,
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 16 : 22,
                  vertical: 16,
                ),
                child: PillButton(
                  height: 50,
                  label: !isConfigured
                      ? 'CONFIGURE TELEGRAM BACKUP'
                      : (isMonitoring ? 'STOP MONITORING' : 'START MONITORING'),
                  icon: !isConfigured
                      ? Icons.tune_rounded
                      : (isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  variant: isMonitoring ? PillButtonVariant.destructive : PillButtonVariant.primary,
                  onPressed: onToggleMonitoring,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
