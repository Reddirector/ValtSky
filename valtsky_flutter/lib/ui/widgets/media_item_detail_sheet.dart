import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/media_item.dart';
import '../../util/theme.dart';

class MediaItemDetailSheet extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onChanged;

  const MediaItemDetailSheet({super.key, required this.item, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);
    final isVideo = item.mimeType.contains('video');
    final fileName = item.filePath.split('/').last;
    final fullDate = DateFormat('MMMM d, yyyy • h:mm:ss a').format(
      DateTime.fromMillisecondsSinceEpoch(item.dateTaken),
    );

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
                color: mutedText.withAlpha(80),
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
                  color: trackBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                  color: secondaryColor,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Status', item.status, isDark, isHighlight: true),
          _buildInfoRow('File Size', '${(item.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB', isDark),
          _buildInfoRow('Lossless Protocol', 'Telegram Document (Direct RAM Stream)', isDark),
          _buildInfoRow('Chunking Mode', item.fileSize > 50 * 1024 * 1024 ? 'Multi-Part 48MB Chunks' : 'Single Direct Stream', isDark),
          _buildInfoRow('File Hash (SHA-256)', item.fileHash ?? 'Generated on stream', isDark),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    Color? valColor;
    if (isHighlight) {
      if (value == MediaItem.statusDone) valColor = ValtSkyTheme.success;
      if (value == MediaItem.statusPending) valColor = ValtSkyTheme.warning;
      if (value == MediaItem.statusFailed) valColor = ValtSkyTheme.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valColor ?? (isDark ? Colors.white : Colors.black),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
