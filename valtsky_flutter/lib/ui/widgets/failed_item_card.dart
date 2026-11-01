import 'package:flutter/material.dart';
import '../../data/models/media_item.dart';
import '../../data/db/database_helper.dart';
import '../../data/prefs.dart';
import '../../util/theme.dart';

class FailedItemCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onRetry;

  const FailedItemCard({super.key, required this.item, this.onRetry});

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showTroubleshootDialog(BuildContext context) {
    final error = item.errorReason ?? 'Unknown error';
    final isLarge = error.contains('50MB') || error.contains('large') || item.fileSize > 50 * 1024 * 1024;
    final isAuth = error.contains('401') || error.contains('Unauthorized');
    final isChannel = error.contains('403') || error.contains('Forbidden') || error.contains('permission') || error.contains('chat not found');

    String title;
    String cause;
    String solution;
    String actionBtn;
    VoidCallback onAction;

    if (isLarge) {
      title = 'File Exceeds 50MB Bot Limit';
      cause = 'Standard Telegram bots reject single files over 50MB.';
      solution = 'Enable Smart Multi-Part Chunking. ValtSky will split this video into lossless 48MB parts with SHA-256 integrity checks, uploading it without losing any quality.';
      actionBtn = 'Enable Chunking & Retry';
      onAction = () async {
        Prefs.enableChunking = true;
        await DatabaseHelper.instance.retrySingle(item.filePath);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Smart Chunking enabled. Item queued for re-upload.')),
          );
          onRetry?.call();
        }
      };
    } else if (isAuth) {
      title = 'Bot Authentication Failed';
      cause = 'Telegram Bot API rejected your Bot Token.';
      solution = 'Double-check your Bot Token from @BotFather in the Settings tab.';
      actionBtn = 'Retry Upload';
      onAction = () async {
        await DatabaseHelper.instance.retrySingle(item.filePath);
        if (context.mounted) {
          Navigator.pop(context);
          onRetry?.call();
        }
      };
    } else if (isChannel) {
      title = 'Channel Permission Missing';
      cause = 'Your bot is not an Administrator in the target channel or lacks "Post Messages" permission.';
      solution = 'Open Telegram → Go to your private channel → Manage Channel → Administrators → Add your bot with Post Messages enabled.';
      actionBtn = 'Retry Upload';
      onAction = () async {
        await DatabaseHelper.instance.retrySingle(item.filePath);
        if (context.mounted) {
          Navigator.pop(context);
          onRetry?.call();
        }
      };
    } else {
      title = 'Upload Interrupted';
      cause = error;
      solution = 'A network timeout or transient error interrupted transmission. Tapping retry will resume upload from storage.';
      actionBtn = 'Retry Upload';
      onAction = () async {
        await DatabaseHelper.instance.retrySingle(item.filePath);
        if (context.mounted) {
          Navigator.pop(context);
          onRetry?.call();
        }
      };
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.build_circle_rounded, color: ValtSkyTheme.error, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ValtSkyTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: ValtSkyTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.filePath.split('/').last,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('WHAT WENT WRONG:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(cause, style: const TextStyle(fontSize: 12.5, height: 1.3)),
            const SizedBox(height: 12),
            const Text('HOW TO FIX IT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ValtSkyTheme.info, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(solution, style: const TextStyle(fontSize: 12.5, height: 1.3)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DISMISS'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.info,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onAction,
            child: Text(actionBtn, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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

    return InkWell(
      onTap: () => _showTroubleshootDialog(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E171E) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ValtSkyTheme.error.withValues(alpha: isDark ? 0.3 : 0.2),
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
                color: ValtSkyTheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.broken_image_rounded,
                color: ValtSkyTheme.error,
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
                      Text(
                        '•',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.errorReason ?? 'Upload failed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ValtSkyTheme.error,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Tap for diagnosis & 1-click fix',
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Retry upload',
              style: IconButton.styleFrom(
                backgroundColor: ValtSkyTheme.primaryAccent.withValues(alpha: 0.1),
                foregroundColor: ValtSkyTheme.primaryAccent,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () async {
                await DatabaseHelper.instance.retrySingle(item.filePath);
                onRetry?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
