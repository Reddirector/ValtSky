import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/media_item.dart';
import '../../util/theme.dart';
import 'media_item_detail_sheet.dart';

class VaultRecentActivity extends StatelessWidget {
  final List<MediaItem> items;
  final VoidCallback onNavigateToActivity;
  final VoidCallback onDataChanged;

  const VaultRecentActivity({
    super.key,
    required this.items,
    required this.onNavigateToActivity,
    required this.onDataChanged,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clean Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT MEDIA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: mutedText,
                    ),
                  ),
                  InkWell(
                    onTap: onNavigateToActivity,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: secondaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Static List of Recent Files
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 28 : 6),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: borderColor.withAlpha(70),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isVideo = item.mimeType.contains('video');
                  final isDone = item.status == MediaItem.statusDone;
                  final isFailed = item.status == MediaItem.statusFailed;
                  final fileName = item.filePath.split('/').last;
                  final dateStr = DateFormat('MMM d, h:mm a').format(
                    DateTime.fromMillisecondsSinceEpoch(item.dateTaken),
                  );

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: cardBg,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => MediaItemDetailSheet(
                            item: item,
                            onChanged: onDataChanged,
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 12 : 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // File Icon Thumbnail
                            Container(
                              width: isNarrow ? 36 : 40,
                              height: isNarrow ? 36 : 40,
                              decoration: BoxDecoration(
                                color: trackBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                                size: isNarrow ? 18 : 20,
                                color: secondaryColor,
                              ),
                            ),
                            SizedBox(width: isNarrow ? 10 : 12),

                            // Title & Subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isNarrow ? 12.5 : 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dateStr • ${_formatSize(item.fileSize)}',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 10.5 : 11.5,
                                      color: mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? secondaryColor.withAlpha(20)
                                    : (isFailed
                                        ? ValtSkyTheme.error.withAlpha(20)
                                        : primaryColor.withAlpha(20)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.cloud_done_rounded
                                        : (isFailed
                                            ? Icons.error_outline_rounded
                                            : Icons.schedule_rounded),
                                    size: 12,
                                    color: isDone
                                        ? secondaryColor
                                        : (isFailed
                                            ? ValtSkyTheme.error
                                            : primaryColor),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDone ? 'Synced' : (isFailed ? 'Failed' : 'Queued'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isDone
                                          ? secondaryColor
                                          : (isFailed
                                              ? ValtSkyTheme.error
                                              : primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
