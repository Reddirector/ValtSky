import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import 'valtsky_components.dart';

/// Night-Sky Vault Hero Storage Card
/// Features:
/// - Living Sky Orb Hero with cosmic starfield (lit stars proportional to synced items)
/// - Sora Light 56 center percentage readout
/// - Glowing head progress arc in surface-3 recessed track
/// - Live count subtitle "$uploadedCount of $totalCount synced" and "Lossless" pill
/// - Single dominant Master Action CTA with primary gradient fill
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
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = ValtSkyTheme.surface(isDark, level: 1);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final secondaryColor = ValtSkyTheme.textSecondary(isDark);
    final trackBg = ValtSkyTheme.surface(isDark, level: 3);

    final percentInt = (progress.clamp(0.0, 1.0) * 100).toInt();

    // Dot indicator color
    final statusDotColor = !isConfigured
        ? ValtSkyTheme.statusFailed
        : (isPaused
            ? ValtSkyTheme.darkAccent
            : (isUploading
                ? ValtSkyTheme.darkAqua
                : (isMonitoring ? ValtSkyTheme.statusSynced : secondaryColor)));

    final statusText = !isConfigured
        ? 'SETUP'
        : (isPaused
            ? 'PAUSED'
            : (isUploading
                ? (isMonitoring ? 'UPLOADING' : 'QUEUE UPLOAD')
                : (isMonitoring ? 'MONITORING' : 'STANDBY')));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final orbSize = (constraints.maxWidth * 0.46).clamp(150.0, 200.0);

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
                                  fontFamily: ValtSkyTheme.fontFamilyBody,
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

                    const SizedBox(height: 16),

                    // Living Sky Orb Hero (Cosmic Starfield & Progress Arc)
                    SkyOrbHero(
                      progress: progress,
                      totalCount: totalCount,
                      syncedCount: uploadedCount,
                      size: orbSize,
                      isUploading: isUploading,
                    ),

                    const SizedBox(height: 16),

                    // Counter & Tag Pill: "$uploadedCount of $totalCount synced" + "$percentInt%"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$uploadedCount of $totalCount synced',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyBody,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ValtSkyTheme.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: trackBg,
                            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            '$percentInt%',
                            style: TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyDisplay,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ValtSkyTheme.accentText(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Regulatory Telemetry Strip
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
                          // Speed / Setup Pill
                          ValueListenableBuilder<String>(
                            valueListenable: SyncEngine.uploadSpeedNotifier,
                            builder: (context, currentSpeed, _) {
                              if (!isConfigured) {
                                return ElevatedButton(
                                  onPressed: onNavigateToSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ValtSkyTheme.accent(isDark),
                                    foregroundColor: isDark ? ValtSkyTheme.ink : Colors.white,
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
                  ],
                ),
              ),

              // ─── BOTTOM CTA SHEET PANEL (PINNED DOMINANT BUTTON) ───────────
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
                  height: 52,
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
