import 'package:flutter/material.dart';
import '../../data/models/media_breakdown.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

/// Permanent, dual-split upload bar:
/// - Left side (Blue): Images / Photos
/// - Right side (Purple): Videos
///
/// Clearly establishes the UI concept with explicit 'PHOTOS' and 'VIDEOS' labels:
/// - Active: shows live upload percentage and wire speed (PHOTOS • $percent% • $speed)
/// - Completed: shows full solid bar with explicit 'Completed' label (PHOTOS • Completed)
/// - Zero layout shift or flicker between active, idle, and completed states.
class DualSplitUploadBar extends StatefulWidget {
  final bool isDark;

  const DualSplitUploadBar({
    super.key,
    required this.isDark,
  });

  @override
  State<DualSplitUploadBar> createState() => _DualSplitUploadBarState();
}

class _DualSplitUploadBarState extends State<DualSplitUploadBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  static const Color photoBlue = Color(0xFF38BDF8);
  static const Color photoBlueEnd = Color(0xFF0284C7);
  static const Color videoPurple = Color(0xFF8B5CF6);
  static const Color videoPurpleEnd = Color(0xFFA855F7);

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return ValueListenableBuilder<MediaBreakdown>(
      valueListenable: SyncEngine.mediaBreakdownNotifier,
      builder: (context, breakdown, _) {
        return ValueListenableBuilder<Map<String, FileUploadProgress>>(
          valueListenable: SyncEngine.activeUploadsNotifier,
          builder: (context, activeUploads, _) {
            final photoUpload = activeUploads.values.where((p) => !p.isVideo).firstOrNull;
            final videoUpload = activeUploads.values.where((p) => p.isVideo).firstOrNull;

            final isPhotoActive = photoUpload != null;
            final isVideoActive = videoUpload != null;
            final isAnyActive = isPhotoActive || isVideoActive;

            // When done / idle: bar is NOT moving, animation controller is stopped
            if (isAnyActive) {
              if (!_shimmerController.isAnimating) {
                _shimmerController.repeat();
              }
            } else {
              if (_shimmerController.isAnimating) {
                _shimmerController.stop();
              }
            }

            final photoPercent = isPhotoActive
                ? (photoUpload.progress * 100).toInt().clamp(0, 100)
                : 100;
            final videoPercent = isVideoActive
                ? (videoUpload.progress * 100).toInt().clamp(0, 100)
                : 100;

            // Explicit labels establishing clear UI concept for user
            final String photoLabel;
            if (isPhotoActive) {
              photoLabel = 'PHOTOS • $photoPercent% • ${photoUpload.speedText}';
            } else if (breakdown.pendingPhotos > 0) {
              photoLabel = 'PHOTOS • In Queue';
            } else {
              photoLabel = 'PHOTOS • Completed';
            }

            final String videoLabel;
            if (isVideoActive) {
              videoLabel = 'VIDEOS • $videoPercent% • ${videoUpload.speedText}';
            } else if (breakdown.pendingVideos > 0) {
              videoLabel = 'VIDEOS • In Queue';
            } else {
              videoLabel = 'VIDEOS • Completed';
            }

            // Target fraction: dynamic during upload, 1.0 (full solid) when completed
            final double photoTargetFraction;
            if (isPhotoActive) {
              photoTargetFraction = photoUpload.progress.clamp(0.01, 1.0);
            } else if (breakdown.pendingPhotos > 0) {
              final totalPhotos = breakdown.syncedPhotos + breakdown.pendingPhotos;
              photoTargetFraction = totalPhotos > 0
                  ? (breakdown.syncedPhotos / totalPhotos).clamp(0.05, 0.95)
                  : 0.05;
            } else {
              photoTargetFraction = 1.0;
            }

            final double videoTargetFraction;
            if (isVideoActive) {
              videoTargetFraction = videoUpload.progress.clamp(0.01, 1.0);
            } else if (breakdown.pendingVideos > 0) {
              final totalVideos = breakdown.syncedVideos + breakdown.pendingVideos;
              videoTargetFraction = totalVideos > 0
                  ? (breakdown.syncedVideos / totalVideos).clamp(0.05, 0.95)
                  : 0.05;
            } else {
              videoTargetFraction = 1.0;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prominent Category & State Labels Row: Invariant 18px height (zero layout shift/flicker)
                SizedBox(
                  height: 18,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: PHOTOS (Blue)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isPhotoActive || breakdown.pendingPhotos == 0
                                    ? photoBlue
                                    : photoBlue.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                photoLabel,
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isPhotoActive || breakdown.pendingPhotos == 0
                                      ? photoBlue
                                      : photoBlue.withValues(alpha: 0.75),
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: VIDEOS (Purple)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                videoLabel,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isVideoActive || breakdown.pendingVideos == 0
                                      ? videoPurple
                                      : videoPurple.withValues(alpha: 0.75),
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isVideoActive || breakdown.pendingVideos == 0
                                    ? videoPurple
                                    : videoPurple.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Dual Split Progress Bar (Blue on Left, Purple on Right)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: Row(
                      children: [
                        // ─── LEFT HALF: PHOTO (BLUE) ───────────────────────────
                        Expanded(
                          child: Container(
                            height: 6,
                            color: trackBg,
                            child: Stack(
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                      width: constraints.maxWidth * photoTargetFraction,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [photoBlue, photoBlueEnd],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (isPhotoActive)
                                  AnimatedBuilder(
                                    animation: _shimmerController,
                                    builder: (context, child) {
                                      return Positioned.fill(
                                        child: FractionallySizedBox(
                                          alignment: Alignment(
                                            (_shimmerController.value * 2.6) - 1.3,
                                            0,
                                          ),
                                          widthFactor: 0.4,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.0),
                                                  Colors.white.withValues(alpha: 0.40),
                                                  Colors.white.withValues(alpha: 0.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Central Divider Gap
                        Container(
                          width: 2,
                          height: 6,
                          color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                        ),

                        // ─── RIGHT HALF: VIDEO (PURPLE) ────────────────────────
                        Expanded(
                          child: Container(
                            height: 6,
                            color: trackBg,
                            child: Stack(
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                      width: constraints.maxWidth * videoTargetFraction,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [videoPurple, videoPurpleEnd],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (isVideoActive)
                                  AnimatedBuilder(
                                    animation: _shimmerController,
                                    builder: (context, child) {
                                      return Positioned.fill(
                                        child: FractionallySizedBox(
                                          alignment: Alignment(
                                            (_shimmerController.value * 2.6) - 1.3,
                                            0,
                                          ),
                                          widthFactor: 0.4,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.0),
                                                  Colors.white.withValues(alpha: 0.40),
                                                  Colors.white.withValues(alpha: 0.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Minimalist, high-performance per-file upload loading bar:
/// Displays only `$percent% • $speedText` and animated progress without redundant messages.
class FileUploadLoadingBar extends StatefulWidget {
  final FileUploadProgress progress;
  final bool isDark;
  final bool compact;
  final bool showHeader;

  const FileUploadLoadingBar({
    super.key,
    required this.progress,
    required this.isDark,
    this.compact = false,
    this.showHeader = true,
  });

  @override
  State<FileUploadLoadingBar> createState() => _FileUploadLoadingBarState();
}

class _FileUploadLoadingBarState extends State<FileUploadLoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.progress.isVideo;
    final primaryAccent = isVideo
        ? const Color(0xFF8B5CF6) // Vivid Purple
        : const Color(0xFF38BDF8); // Cyan
    final secondaryAccent = isVideo
        ? const Color(0xFFA855F7)
        : const Color(0xFF0284C7);

    final trackColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final percent = (widget.progress.progress * 100).toInt().clamp(0, 100);
    final barHeight = widget.compact ? 4.0 : 6.0;

    final isDone = widget.progress.progress >= 1.0;
    if (!isDone) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat();
      }
    } else {
      if (_shimmerController.isAnimating) {
        _shimmerController.stop();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHeader) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyDisplay,
                    fontSize: widget.compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: primaryAccent,
                  ),
                ),
                Text(
                  widget.progress.speedText,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyDisplay,
                    fontSize: widget.compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: ValtSkyTheme.textSecondary(widget.isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
        // The Shimmering Animated Loading Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(barHeight / 2),
          child: Container(
            height: barHeight,
            width: double.infinity,
            color: trackColor,
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final targetWidth = constraints.maxWidth *
                        widget.progress.progress.clamp(0.01, 1.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: targetWidth,
                      height: barHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        gradient: LinearGradient(
                          colors: [primaryAccent, secondaryAccent],
                        ),
                      ),
                    );
                  },
                ),
                if (!isDone)
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment(
                            (_shimmerController.value * 2.6) - 1.3,
                            0,
                          ),
                          widthFactor: 0.35,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.40),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
