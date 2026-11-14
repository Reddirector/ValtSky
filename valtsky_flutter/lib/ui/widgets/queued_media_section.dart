import 'package:flutter/material.dart';
import '../../data/models/media_item.dart';
import '../../services/sync_engine.dart';
import '../../util/formatters.dart';
import '../../util/theme.dart';
import 'file_upload_loading_bar.dart';

/// Interactive queue management section allowing users to remove items
/// and manually drag-and-drop reorder videos and photos to prioritize uploads.
class QueuedMediaSection extends StatelessWidget {
  final List<MediaItem> items;
  final bool isDark;
  final ValueChanged<MediaItem> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const QueuedMediaSection({
    super.key,
    required this.items,
    required this.isDark,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = ValtSkyTheme.accent(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);
    final hairline = ValtSkyTheme.hairline(isDark);

    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 14),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: ValtSkyTheme.surface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hairline),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.done_all_rounded, size: 36, color: ValtSkyTheme.synced(isDark)),
            const SizedBox(height: 8),
            Text(
              'Upload Queue Empty',
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamilyDisplay,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ValtSkyTheme.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All camera roll items are synced or paused.',
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamilyBody,
                fontSize: 12,
                color: mutedText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'QUEUE PRIORITY ORDER',
                  style: ValtSkyTheme.capsLabel(isDark: isDark, color: mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Hold & drag to arrange order',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: (int oldIndex, int newIndex) {
            onReorder(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            final fileName = item.filePath.split('/').last;
            final isVideo = item.isVideo;

            return ValueListenableBuilder<Map<String, FileUploadProgress>>(
              key: ValueKey(item.filePath),
              valueListenable: SyncEngine.activeUploadsNotifier,
              builder: (context, activeUploads, _) {
                final activeProgress = activeUploads[item.filePath];
                final isUploading = activeProgress != null;
                final activeBorderColor = isUploading
                    ? (isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8))
                    : hairline;

                return RepaintBoundary(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ValtSkyTheme.surface(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeBorderColor,
                        width: isUploading ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isVideo
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                    : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                                color: isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: TextStyle(
                                      fontFamily: ValtSkyTheme.fontFamilyBody,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ValtSkyTheme.textPrimary(isDark),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isUploading
                                        ? '⚡ Active Transfer • ${ValtSkyFormatters.formatBytes(item.fileSize)}'
                                        : '#${index + 1} in line • ${ValtSkyFormatters.formatBytes(item.fileSize)}',
                                    style: TextStyle(
                                      fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isUploading
                                          ? (isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8))
                                          : accentColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: ValtSkyTheme.error,
                              tooltip: 'Remove from Queue',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => onRemove(item),
                            ),
                            const SizedBox(width: 4),
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: mutedText,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isUploading) ...[
                          const SizedBox(height: 10),
                          FileUploadLoadingBar(
                            progress: activeProgress,
                            isDark: isDark,
                            compact: false,
                            showHeader: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
