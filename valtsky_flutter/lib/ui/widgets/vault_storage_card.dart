import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

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
    final isUploading = !isPaused && (engineStatus == SyncEngineStatus.active || SyncEngine.isPhotoWorkerActive || SyncEngine.isVideoWorkerActive);

    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    final percentInt = (progress * 100).toInt();

    final Color statusDotColor = !isConfigured
        ? mutedText
        : (isPaused
            ? ValtSkyTheme.warning
            : (isUploading ? secondaryColor : (isMonitoring ? primaryColor : mutedText)));

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
        final horizontalPadding = isNarrow ? 14.0 : 18.0;

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 35 : 8),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Regulatory Static Header Row (Fixed 28px height to eliminate any header shift)
              SizedBox(
                height: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: statusDotColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: trackBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 13, color: secondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Lossless',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Redesigned Uploading Progress Header & Percentage Placement
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isUploading ? Colors.white : (isPaused ? ValtSkyTheme.warning : mutedText),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isUploading ? 'UPLOADING TO VAULT' : (isPaused ? 'UPLOADS PAUSED' : 'VAULT SYNC STATUS'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isUploading ? Colors.white.withValues(alpha: 0.9) : mutedText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$uploadedCount of $totalCount synced',
                            style: TextStyle(
                              fontSize: isNarrow ? 15 : 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Modern Percentage Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF0F172A),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$percentInt',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 1),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. Crisp Pure White Linear Progress Bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 4. PERMANENT REGULATORY TELEMETRY BAR
              // Strictly fixed 48px height that NEVER collapses or appears/disappears,
              // completely eliminating UI fluctuation and screen jumps!
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: trackBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    // Transfer State Icon
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: secondaryColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUploading
                            ? Icons.arrow_upward_rounded
                            : (isPaused ? Icons.pause_rounded : Icons.cloud_done_rounded),
                        size: 16,
                        color: isPaused ? ValtSkyTheme.warning : secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Active File / Connection Info
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Regulatory Speed Meter Badge (Fixed 86x30px size)
                    Container(
                      width: 86,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: secondaryColor.withAlpha(isDark ? 28 : 18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: secondaryColor.withAlpha(50)),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                size: 12,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  displaySpeed,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: secondaryColor,
                                    letterSpacing: -0.2,
                                  ),
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

              const SizedBox(height: 16),

              // 5. Master Control CTA Button (Primary Blue CTA with Tactile Press)
              TactilePress(
                onTap: onToggleMonitoring,
                scaleDown: 0.97,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: !isConfigured
                        ? primaryColor
                        : (isMonitoring ? ValtSkyTheme.error : primaryColor),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !isConfigured
                            ? Icons.tune_rounded
                            : (isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          !isConfigured
                              ? 'CONFIGURE TELEGRAM BACKUP'
                              : (isMonitoring ? 'STOP MONITORING' : 'START MONITORING'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
