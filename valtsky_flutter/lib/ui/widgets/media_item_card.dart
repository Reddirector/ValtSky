import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/models/media_item.dart';
import '../../data/db/database_helper.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';
import 'passive_elements.dart';

class MediaItemCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onChanged;
  final VoidCallback? onManualUpload;

  const MediaItemCard({
    super.key,
    required this.item,
    this.onChanged,
    this.onManualUpload,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _getStatusColor() {
    switch (item.status) {
      case MediaItem.statusDone:
        return ValtSkyTheme.success;
      case MediaItem.statusPending:
        return ValtSkyTheme.warning;
      case MediaItem.statusUploading:
        return ValtSkyTheme.info;
      case MediaItem.statusFailed:
        return ValtSkyTheme.error;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (item.status) {
      case MediaItem.statusDone:
        return Icons.check_circle_rounded;
      case MediaItem.statusPending:
        return Icons.schedule_rounded;
      case MediaItem.statusUploading:
        return Icons.cloud_upload_rounded;
      case MediaItem.statusFailed:
        return Icons.error_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  void _showDetailsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = item.mimeType.contains('video');
    final fileName = item.filePath.split('/').last;
    final statusColor = _getStatusColor();
    final fullDate = DateFormat('MMMM d, yyyy • h:mm:ss a').format(
      DateTime.fromMillisecondsSinceEpoch(item.dateTaken),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                      color: isDark ? Colors.white : Colors.black,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Captured Date & Time', fullDate, Icons.calendar_today_rounded, isDark),
              _buildDetailRow('Exact File Size', '${_formatFileSize(item.fileSize)} (${item.fileSize} bytes)', Icons.storage_rounded, isDark),
              _buildDetailRow('File Path', item.filePath, Icons.folder_open_rounded, isDark),
              _buildDetailRow('Media Type', item.mimeType, Icons.file_present_rounded, isDark),
              _buildDetailRow(
                'Upload Quality',
                'Bit-for-Bit Lossless (Original EXIF Preserved)',
                Icons.verified_rounded,
                isDark,
                highlightColor: ValtSkyTheme.success,
              ),
              if (item.errorReason != null)
                _buildDetailRow('Error Reason', item.errorReason!, Icons.error_outline_rounded, isDark, highlightColor: ValtSkyTheme.error),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (item.fileSize >= 2147483648 && item.status != MediaItem.statusDone) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: const Text('UPLOAD NOW', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () {
                          Navigator.pop(context);
                          onManualUpload?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else if (item.status == MediaItem.statusFailed) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ValtSkyTheme.primaryAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('RETRY UPLOAD', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          await DatabaseHelper.instance.retrySingle(item.filePath);
                          nav.pop();
                          onChanged?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy File Path'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.filePath));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('File path copied to clipboard')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: highlightColor ?? (isDark ? Colors.grey[500] : Colors.grey[600])),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: highlightColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = item.mimeType.contains('video');
    final fileName = item.filePath.split('/').last;
    final statusColor = _getStatusColor();
    final dateStr = DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(item.dateTaken));

    return TactilePress(
      onTap: () => _showDetailsBottomSheet(context),
      scaleDown: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                color: isDark ? Colors.white : Colors.black,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _formatFileSize(item.fileSize),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (item.errorReason != null && item.status == MediaItem.statusFailed) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.errorReason!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ValtSkyTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.fileSize >= 2147483648 && item.status != MediaItem.statusDone) ...[
              TactilePress(
                onTap: onManualUpload,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: isDark ? Colors.black : Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'UPLOAD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.black : Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.status == MediaItem.statusUploading) ...[
                      PassiveTransferWave(color: statusColor, isLive: true),
                      const SizedBox(width: 5),
                    ] else ...[
                      Icon(_getStatusIcon(), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
