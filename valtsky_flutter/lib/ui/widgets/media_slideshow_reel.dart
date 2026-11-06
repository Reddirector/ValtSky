import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../util/theme.dart';
import 'glass_card.dart';

class MediaSlideshowReel extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const MediaSlideshowReel({super.key, this.onDataChanged});

  @override
  State<MediaSlideshowReel> createState() => MediaSlideshowReelState();
}

class MediaSlideshowReelState extends State<MediaSlideshowReel> {
  List<MediaItem> _items = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final allItems = await DatabaseHelper.instance.getAllItems(limit: 6);
    if (mounted) {
      setState(() {
        _items = allItems.take(6).toList();
        if (_currentIndex >= _items.length) {
          _currentIndex = 0;
        }
      });
    }
  }

  void refresh() {
    _loadItems();
  }

  void _nextSlide() {
    if (_items.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _items.length;
    });
  }

  void _prevSlide() {
    if (_items.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _items.length) % _items.length;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = _items[_currentIndex];
    final isVideo = currentItem.mimeType.contains('video');
    final fileName = currentItem.filePath.split('/').last;
    final isDone = currentItem.status == MediaItem.statusDone;
    final formattedDate = DateFormat('MMM d, h:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(currentItem.dateTaken),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 15,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
                const SizedBox(width: 8),
                Text(
                  'RECENT CAPTURES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  ),
                ),
              ],
            ),
            Text(
              '${_currentIndex + 1} of ${_items.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Interactive Media Card
        GestureDetector(
          onTap: () {
            // Show item details sheet
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (ctx) => MediaItemDetailSheet(
                item: currentItem,
                onChanged: () {
                  _loadItems();
                  widget.onDataChanged?.call();
                },
              ),
            );
          },
          child: GlassCard(
            borderRadius: 20,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 168,
              child: Stack(
                children: [
                  // Smooth Crossfade & Scale Image / Visual Canvas
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: Container(
                        key: ValueKey<String>(currentItem.filePath),
                        width: double.infinity,
                        height: 168,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121214) : Colors.white,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? const [
                                    Color(0xFF1C1C20),
                                    Color(0xFF121215),
                                    Color(0xFF0A0A0C),
                                  ]
                                : const [
                                    Color(0xFFFFFFFF),
                                    Color(0xFFF8FAFC),
                                    Color(0xFFF1F5F9),
                                  ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Ambient Diagonal Pattern
                            Positioned(
                              right: -20,
                              bottom: -20,
                              child: Icon(
                                isVideo ? Icons.movie_creation_outlined : Icons.photo_library_outlined,
                                size: 140,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              ),
                            ),
                            // Content Overlay
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top Row: Type & Status Badges
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                                              size: 13,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              isVideo ? 'VIDEO' : 'PHOTO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status Badge in Color
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (isDone ? ValtSkyTheme.success : ValtSkyTheme.warning).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: (isDone ? ValtSkyTheme.success : ValtSkyTheme.warning).withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isDone ? Icons.cloud_done_rounded : Icons.hourglass_top_rounded,
                                              size: 13,
                                              color: isDone ? ValtSkyTheme.success : ValtSkyTheme.warning,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              isDone ? 'BACKED UP' : 'QUEUED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: isDone ? ValtSkyTheme.success : ValtSkyTheme.warning,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Bottom Row: File Details & Lossless Guarantee
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.black,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _formatSize(currentItem.fileSize),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '•',
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF52525B) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Left Navigation Chevron Button
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: InkWell(
                        onTap: _prevSlide,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right Navigation Chevron Button
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: InkWell(
                        onTap: _nextSlide,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Dots Indicator
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_items.length, (idx) {
                        final isSelected = idx == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isSelected ? 22 : 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaItemDetailSheet extends StatelessWidget {
  final MediaItem item;
  final VoidCallback? onChanged;

  const MediaItemDetailSheet({super.key, required this.item, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
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
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
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
