import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/media_item.dart';
import '../../data/db/database_helper.dart';
import '../../util/theme.dart';

class FailedItemCard extends StatelessWidget {
  final MediaItem item;

  const FailedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnail(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.filePath.split('/').last,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.errorReason ?? 'Unknown error',
                    style: TextStyle(fontSize: 11, color: theme.brightness == Brightness.dark ? Colors.red[300] : Colors.red[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: ValtSkyTheme.primaryAccent),
              onPressed: () => DatabaseHelper.instance.retrySingle(item.filePath),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final mimeType = item.mimeType;
    if (mimeType.startsWith('image')) {
      return Image.file(
        File(item.filePath),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(Icons.image),
      );
    } else {
      return _buildPlaceholderIcon(Icons.videocam);
    }
  }

  Widget _buildPlaceholderIcon(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.withValues(alpha: 0.1),
      child: Icon(icon, color: Colors.grey, size: 24),
    );
  }
}
