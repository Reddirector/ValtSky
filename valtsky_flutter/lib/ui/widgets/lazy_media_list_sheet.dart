import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../services/sync_engine.dart';
import '../../util/formatters.dart';
import '../../util/theme.dart';
import 'file_upload_loading_bar.dart';

/// A high-performance, lazy-loaded pop-up sheet designed to stream media items in
/// discrete chunks (e.g. 20 items at a time), mimicking a Python generator / lazy
/// iterator to prevent CPU spikes and heap thrashing.
class LazyMediaListSheet extends StatefulWidget {
  final String title;
  final String? statusFilter;
  final bool? isVideo;
  final IconData icon;
  final Color? accentColor;

  const LazyMediaListSheet({
    super.key,
    required this.title,
    this.statusFilter,
    this.isVideo,
    required this.icon,
    this.accentColor,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? statusFilter,
    bool? isVideo,
    required IconData icon,
    Color? accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    // Short pop-up window: stays comfortably in the lower/mid region (never reaches top of screen)
    final maxHeight = (screenHeight * 0.48).clamp(240.0, 440.0);

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: 540,
      ),
      backgroundColor: ValtSkyTheme.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => LazyMediaListSheet(
        title: title,
        statusFilter: statusFilter,
        isVideo: isVideo,
        icon: icon,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<LazyMediaListSheet> createState() => _LazyMediaListSheetState();
}

class _LazyMediaListSheetState extends State<LazyMediaListSheet> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<MediaItem> _items = [];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initLoad();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _initLoad() async {
    setState(() => _isLoadingInitial = true);
    final count = await DatabaseHelper.instance.getItemCount(
      statusFilter: widget.statusFilter,
      isVideo: widget.isVideo,
    );
    final initialBatch = await DatabaseHelper.instance.getAllItems(
      statusFilter: widget.statusFilter,
      isVideo: widget.isVideo,
      limit: _pageSize,
      offset: 0,
    );

    if (mounted) {
      setState(() {
        _totalCount = count;
        _items.clear();
        _items.addAll(initialBatch);
        _isLoadingInitial = false;
        _hasMore = initialBatch.length == _pageSize && initialBatch.length < count;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextBatch = await DatabaseHelper.instance.getAllItems(
      statusFilter: widget.statusFilter,
      isVideo: widget.isVideo,
      limit: _pageSize,
      offset: _items.length,
    );

    if (mounted) {
      setState(() {
        _items.addAll(nextBatch);
        _isLoadingMore = false;
        _hasMore = nextBatch.length == _pageSize && _items.length < _totalCount;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _handleDeleteAllWithDoubleVerification() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isQueue = widget.statusFilter == MediaItem.statusPending;
    final typeName = widget.isVideo == null
        ? (isQueue ? 'Queued Items' : 'Failed Items')
        : (widget.isVideo!
            ? (isQueue ? 'Queued Videos' : 'Failed Videos')
            : (isQueue ? 'Queued Photos' : 'Failed Photos'));

    // Step 1
    final step1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Step 1 of 2: Delete All $typeName?',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove all $_totalCount $typeName? Your physical camera roll files will not be deleted.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed to Step 2', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (step1 != true) return;
    if (!mounted) return;

    // Step 2
    final step2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ValtSkyTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: ValtSkyTheme.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Step 2 of 2: Final Confirmation',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ValtSkyTheme.error),
              ),
            ),
          ],
        ),
        content: Text(
          'This action CANNOT be undone. All $_totalCount $typeName will be permanently deleted.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abort / Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanently Delete All', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (step2 != true) return;

    if (isQueue) {
      await DatabaseHelper.instance.clearQueueItems(isVideo: widget.isVideo);
    } else {
      await DatabaseHelper.instance.clearFailedItems(isVideo: widget.isVideo);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = widget.accentColor ?? ValtSkyTheme.accent(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);
    final hairline = ValtSkyTheme.hairline(isDark);

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.48).clamp(240.0, 440.0);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: 540,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, color: effectiveAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: ValtSkyTheme.textPrimary(isDark),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ValtSkyTheme.darkSurface3
                                  : ValtSkyTheme.lightSurface2,
                              borderRadius:
                                  BorderRadius.circular(ValtSkyTheme.radiusPill),
                              border: Border.all(color: hairline),
                            ),
                            child: Text(
                              ValtSkyFormatters.formatMediaCount(_totalCount),
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ValtSkyTheme.textPrimary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (widget.statusFilter == MediaItem.statusPending)
                            ? 'Drag handle to change priority • Tap trash to remove'
                            : 'Lazy-loaded • ${ValtSkyFormatters.formatMediaCount(_items.length)} of ${ValtSkyFormatters.formatMediaCount(_totalCount)} cached',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 11.5,
                          color: (widget.statusFilter == MediaItem.statusPending)
                              ? effectiveAccent
                              : mutedText,
                          fontWeight: (widget.statusFilter == MediaItem.statusPending)
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_totalCount > 0 &&
                    (widget.statusFilter == MediaItem.statusPending ||
                        widget.statusFilter == MediaItem.statusFailed))
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                    color: ValtSkyTheme.error,
                    tooltip: 'Delete All',
                    onPressed: _handleDeleteAllWithDoubleVerification,
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: mutedText,
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content body
          Expanded(
            child: _isLoadingInitial
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: effectiveAccent,
                    ),
                  )
                : _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: ValtSkyTheme.surface(isDark, level: 2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  widget.icon,
                                  size: 28,
                                  color: mutedText,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No items found',
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: ValtSkyTheme.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category is currently empty',
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyBody,
                                  fontSize: 12,
                                  color: mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (widget.statusFilter == MediaItem.statusPending)
                        ? ReorderableListView.builder(
                            scrollController: _scrollController,
                            buildDefaultDragHandles: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _items.length,
                            onReorderItem: (int oldIndex, int newIndex) async {
                              final movedItem = _items.removeAt(oldIndex);
                              _items.insert(newIndex, movedItem);
                              setState(() {});
                              final ordered = _items.map((e) => e.filePath).toList();
                              await SyncEngine.instance.reorderQueue(ordered);
                            },
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _buildListItem(
                                context,
                                item,
                                index,
                                isDark,
                                hairline,
                                effectiveAccent,
                                mutedText,
                                isQueueMode: true,
                              );
                            },
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _items.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index >= _items.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: effectiveAccent,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = _items[index];
                              return _buildListItem(
                                context,
                                item,
                                index,
                                isDark,
                                hairline,
                                effectiveAccent,
                                mutedText,
                                isQueueMode: false,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    MediaItem item,
    int index,
    bool isDark,
    Color hairline,
    Color effectiveAccent,
    Color mutedText, {
    required bool isQueueMode,
  }) {
    final fileName = item.filePath.split('/').last;
    final dateStr = DateTime.fromMillisecondsSinceEpoch(
      item.dateTaken,
    ).toString().split('.').first;

    return ValueListenableBuilder<Map<String, FileUploadProgress>>(
      key: ValueKey(item.filePath),
      valueListenable: SyncEngine.activeUploadsNotifier,
      builder: (context, activeUploads, _) {
        final activeProgress = activeUploads[item.filePath];
        final isUploading = activeProgress != null;
        final activeBorderColor = isUploading
            ? (item.isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8))
            : hairline;

        return Container(
          margin: isQueueMode ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? ValtSkyTheme.darkSurface2 : ValtSkyTheme.lightSurface,
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
                      color: item.isVideo
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                          : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      item.isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                      color: item.isVideo
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF38BDF8),
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
                        Row(
                          children: [
                            Text(
                              isUploading
                                  ? '⚡ Uploading • ${_formatFileSize(item.fileSize)}'
                                  : _formatFileSize(item.fileSize),
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isUploading
                                    ? (item.isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF38BDF8))
                                    : effectiveAccent,
                              ),
                            ),
                            Text(
                              ' • $dateStr',
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyBody,
                                fontSize: 11,
                                color: mutedText,
                              ),
                            ),
                          ],
                        ),
                        if (item.errorReason != null && item.errorReason!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.errorReason!,
                            style: const TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyBody,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: ValtSkyTheme.error,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isQueueMode) ...[
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: ValtSkyTheme.error,
                      tooltip: 'Remove from Queue',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      onPressed: () async {
                        await SyncEngine.instance.removeFromQueue(item.filePath);
                        if (mounted) {
                          setState(() {
                            _items.removeAt(index);
                            _totalCount = (_totalCount - 1).clamp(0, 9999999);
                          });
                        }
                      },
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
                          size: 18,
                        ),
                      ),
                    ),
                  ] else ...[
                    _buildStatusBadge(item.status, isDark),
                  ],
                ],
              ),
              if (isUploading) ...[
                const SizedBox(height: 10),
                FileUploadLoadingBar(
                  progress: activeProgress,
                  isDark: isDark,
                  compact: true,
                  showHeader: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case MediaItem.statusDone:
        bg = ValtSkyTheme.synced(isDark).withValues(alpha: 0.16);
        fg = ValtSkyTheme.synced(isDark);
        label = 'SYNCED';
        break;
      case MediaItem.statusPending:
      case MediaItem.statusUploading:
        bg = ValtSkyTheme.accent(isDark).withValues(alpha: 0.16);
        fg = ValtSkyTheme.accent(isDark);
        label = 'QUEUED';
        break;
      case MediaItem.statusFailed:
        bg = ValtSkyTheme.failed(isDark).withValues(alpha: 0.16);
        fg = ValtSkyTheme.failed(isDark);
        label = 'FAILED';
        break;
      default:
        bg = isDark ? Colors.white10 : Colors.black12;
        fg = ValtSkyTheme.textSecondary(isDark);
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: ValtSkyTheme.fontFamilyDisplay,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
