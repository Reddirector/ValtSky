import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../util/theme.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = widget.accentColor ?? ValtSkyTheme.accent(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);
    final hairline = ValtSkyTheme.hairline(isDark);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                              '$_totalCount',
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
                        'Lazy-loaded • ${_items.length} of $_totalCount cached',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 11.5,
                          color: mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
                          final fileName = item.filePath.split('/').last;
                          final dateStr = DateTime.fromMillisecondsSinceEpoch(
                            item.dateTaken,
                          ).toString().split('.').first;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ValtSkyTheme.darkSurface2
                                  : ValtSkyTheme.lightSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: hairline),
                            ),
                            child: Row(
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
                                    item.isVideo
                                        ? Icons.videocam_rounded
                                        : Icons.photo_rounded,
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
                                            _formatFileSize(item.fileSize),
                                            style: TextStyle(
                                              fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: effectiveAccent,
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
                                      if (item.errorReason != null &&
                                          item.errorReason!.isNotEmpty) ...[
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
                                _buildStatusBadge(item.status, isDark),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
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
