import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../widgets/media_item_card.dart';
import '../widgets/animated_stagger.dart';
import '../widgets/manual_upload_assistant_sheet.dart';
import '../../util/telegram_launcher.dart';
import '../../util/media_scanner.dart';

class ActivityView extends StatefulWidget {
  final VoidCallback onDataChanged;

  const ActivityView({super.key, required this.onDataChanged});

  @override
  State<ActivityView> createState() => ActivityViewState();
}

class ActivityViewState extends State<ActivityView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 30;

  String _selectedFilter = 'ALL';
  List<MediaItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _oversizedCount = 0;
  int _stashedCount = 0;
  bool _isRetryingAll = false;
  Map<String, int> _counts = {'total': 0, 'synced': 0, 'inQueue': 0, 'failed': 0, 'uploading': 0};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    refreshItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 350) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final currentRequestedFilter = _selectedFilter;
    final status = currentRequestedFilter == 'ALL' ? null : currentRequestedFilter;
    try {
      final nextBatch = await DatabaseHelper.instance.getAllItems(
        statusFilter: status,
        limit: _pageSize,
        offset: _items.length,
      );
      if (mounted && _selectedFilter == currentRequestedFilter) {
        final existingPaths = _items.map((e) => e.filePath).toSet();
        final uniqueBatch = nextBatch.where((e) => !existingPaths.contains(e.filePath)).toList();
        setState(() {
          _items.addAll(uniqueBatch);
          _hasMore = nextBatch.length >= _pageSize;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> refreshItems() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
    });
    final status = _selectedFilter == 'ALL' ? null : _selectedFilter;
    final items = await DatabaseHelper.instance.getAllItems(
      statusFilter: status,
      limit: _pageSize,
      offset: 0,
    );
    final oversizedCount = await DatabaseHelper.instance.getOversizedCount();
    final counts = await DatabaseHelper.instance.getAggregatedCounts();
    final stashedCount = await DatabaseHelper.instance.getStashedCount();
    if (mounted) {
      setState(() {
        _items = items;
        _hasMore = items.length >= _pageSize;
        _oversizedCount = oversizedCount;
        _counts = counts;
        _stashedCount = stashedCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRemoveItem(MediaItem item) async {
    final fileName = item.filePath.split('/').last;
    await DatabaseHelper.instance.deleteItem(item.filePath);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((i) => i.filePath == item.filePath);
    });
    final oversizedCount = await DatabaseHelper.instance.getOversizedCount();
    final counts = await DatabaseHelper.instance.getAggregatedCounts();
    final stashedCount = await DatabaseHelper.instance.getStashedCount();
    if (mounted) {
      setState(() {
        _oversizedCount = oversizedCount;
        _counts = counts;
        _stashedCount = stashedCount;
      });
    }
    widget.onDataChanged();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.primary(Theme.of(context).brightness == Brightness.dark),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Removed $fileName from queue'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
        _items = [];
        _hasMore = true;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      refreshItems();
    }
  }

  void _openManualUploadAssistant(List<MediaItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        child: ManualUploadAssistantSheet(
          items: items,
          onCompleted: () {
            refreshItems();
            widget.onDataChanged();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab Bar with Live Count Badges
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All', badgeCount: _counts['total'] ?? _items.length),
                          const SizedBox(width: 8),
                          _buildFilterChip(MediaItem.statusPending, 'Queued', badgeCount: _counts['inQueue'] ?? 0),
                          const SizedBox(width: 8),
                          _buildFilterChip(MediaItem.statusDone, 'Synced', badgeCount: _counts['synced'] ?? 0),
                          const SizedBox(width: 8),
                          _buildFilterChip('OVERSIZED', '> 2 GB', badgeCount: _oversizedCount),
                          const SizedBox(width: 8),
                          _buildFilterChip(MediaItem.statusFailed, 'Failed', badgeCount: _counts['failed'] ?? 0),
                          if (_stashedCount > 0) ...[
                            const SizedBox(width: 8),
                            _buildFilterChip(MediaItem.statusStashed, 'Stashed', badgeCount: _stashedCount),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Queue Summary Count Banner (Counts rather than photos)
              _buildQueueSummaryBanner(isDark),

          // ─── QUEUED TAB NOTICE FOR OVERSIZED FILES ─────────────────
          if (_selectedFilter == MediaItem.statusPending && _oversizedCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ValtSkyTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ValtSkyTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: ValtSkyTheme.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_oversizedCount oversized files (> 2 GB) held for manual upload',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ValtSkyTheme.warning),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor: ValtSkyTheme.warning.withValues(alpha: 0.2),
                      foregroundColor: ValtSkyTheme.warning,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() => _selectedFilter = 'OVERSIZED');
                      refreshItems();
                    },
                    child: const Text('Review Vault', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),

          // ─── OVERSIZED ACTION HEADER (IF IN > 2 GB TAB) ────────────
          if (_selectedFilter == 'OVERSIZED')
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ValtSkyTheme.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.layers_clear_rounded, size: 18, color: ValtSkyTheme.warning),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OVERSIZED VAULT (> 2 GB)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Exceeds standard automated Bot limits',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_oversizedCount Files',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TactilePress(
                            onTap: () async {
                              final allOversized = await DatabaseHelper.instance.getAllItems(statusFilter: 'OVERSIZED');
                              if (mounted) _openManualUploadAssistant(allOversized);
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'UPLOAD ALL OVERSIZED',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TactilePress(
                            onTap: () => TelegramLauncher.openChannel(context),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.open_in_new_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Open Channel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    TactilePress(
                      onTap: () => TelegramLauncher.openChannel(context),
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                            const SizedBox(width: 8),
                            Text(
                              'Open Channel in Telegram',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ─── STASHED ACTION HEADER (IF IN STASHED TAB) ─────────────
          if (_selectedFilter == MediaItem.statusStashed && _items.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.archive_outlined, size: 20, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        '$_stashedCount Stashed Files',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await DatabaseHelper.instance.restoreAllStashed();
                      await refreshItems();
                      widget.onDataChanged();
                    },
                    icon: const Icon(Icons.unarchive_outlined, size: 16),
                    label: const Text('Restore All to Queue', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

          // Items List or Empty State with Smooth Crossfade & Staggered Transitions
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isLoading
                  ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? KeyedSubtree(key: const ValueKey('empty'), child: _buildEmptyState(isDark))
                      : KeyedSubtree(
                          key: ValueKey<String>('list_$_selectedFilter'),
                          child: RefreshIndicator(
                            onRefresh: refreshItems,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _items.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: ValtSkyTheme.primary(isDark),
                                      ),
                                    ),
                                  );
                                }
                                final card = MediaItemCard(
                                  key: ValueKey(_items[index].filePath),
                                  item: _items[index],
                                  onChanged: () {
                                    refreshItems();
                                    widget.onDataChanged();
                                  },
                                  onRemove: () => _handleRemoveItem(_items[index]),
                                  onManualUpload: () => _openManualUploadAssistant([_items[index]]),
                                );

                                if (index < 8) {
                                  return StaggeredFadeSlide(
                                    delayMs: (index * 30).clamp(0, 200),
                                    child: card,
                                  );
                                }
                                return card;
                              },
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  },
);
  }

  Widget _buildQueueSummaryBanner(bool isDark) {
    final primaryColor = ValtSkyTheme.primary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    final pendingCount = _counts['inQueue'] ?? 0;
    final syncedCount = _counts['synced'] ?? 0;

    String title;
    String subtitle;
    IconData icon;

    if (_selectedFilter == MediaItem.statusPending) {
      title = '$pendingCount PENDING IN QUEUE';
      subtitle = pendingCount > 0
          ? 'Tap trash icon to exclude any photo from upload'
          : 'Upload queue is clear';
      icon = Icons.schedule_rounded;
    } else if (_selectedFilter == MediaItem.statusDone) {
      title = '$syncedCount SYNCHRONIZED';
      subtitle = 'Bit-for-bit lossless backup in Telegram';
      icon = Icons.cloud_done_rounded;
    } else if (_selectedFilter == 'OVERSIZED') {
      title = '$_oversizedCount OVERSIZED (> 2 GB)';
      subtitle = 'Held for manual lossless upload';
      icon = Icons.layers_rounded;
    } else if (_selectedFilter == MediaItem.statusFailed) {
      final failedCount = _counts['failed'] ?? 0;
      title = '$failedCount FAILED TRANSFERS';
      subtitle = 'Check connection or retry';
      icon = Icons.error_outline_rounded;
    } else {
      final totalCount = _counts['total'] ?? _items.length;
      title = '$totalCount TOTAL MEDIA TRACKED';
      subtitle = '$pendingCount pending • $syncedCount synced';
      icon = Icons.photo_library_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: mutedText, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_selectedFilter == MediaItem.statusFailed && (_counts['failed'] ?? 0) > 0)
            ElevatedButton.icon(
              onPressed: _isRetryingAll
                  ? null
                  : () async {
                      setState(() => _isRetryingAll = true);
                      try {
                        final count = await DatabaseHelper.instance.retryAllFailed();
                        await refreshItems();
                        widget.onDataChanged();
                        if (Prefs.monitoringEnabled && !Prefs.uploadPaused) {
                          SyncEngine().startSync();
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$count failed items queued for retry'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: ValtSkyTheme.success,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isRetryingAll = false);
                        }
                      }
                    },
              icon: _isRetryingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('RETRY ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.error,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {int? badgeCount}) {
    final isSelected = _selectedFilter == filterKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ValtSkyTheme.primary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badgeCount != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withAlpha(50)
                    : (filterKey == 'OVERSIZED' && badgeCount > 0
                        ? ValtSkyTheme.warning.withAlpha(40)
                        : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12))),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? Colors.white
                      : (filterKey == 'OVERSIZED' && badgeCount > 0
                          ? ValtSkyTheme.warning
                          : (isDark ? Colors.white70 : const Color(0xFF1E293B))),
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filterKey);
          refreshItems();
        }
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
        color: isSelected ? Colors.white : mutedText,
      ),
      selectedColor: primaryColor,
      backgroundColor: cardBg,
      side: BorderSide(
        color: isSelected ? primaryColor : borderColor,
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final isOversized = _selectedFilter == 'OVERSIZED';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B29) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOversized ? Icons.cloud_done_rounded : Icons.perm_media_outlined,
              size: 48,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isOversized
                ? 'Oversized Vault Clear'
                : (_selectedFilter == 'ALL' ? 'No media tracked yet' : 'No $_selectedFilter items found'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            isOversized
                ? 'All files are within standard bot upload limits (< 2 GB)'
                : 'New photos and videos taken will show up here',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          if (isOversized)
            ElevatedButton.icon(
              onPressed: () => TelegramLauncher.openChannel(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Channel in Telegram'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.primary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () async {
                setState(() => _isLoading = true);
                try {
                  final newCount = await MediaScanner.scanForNewMedia(forceFull: false);
                  if (!mounted) return;
                  await refreshItems();
                  if (!mounted) return;
                  widget.onDataChanged();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newCount > 0
                            ? 'Scanned gallery: $newCount new items queued'
                            : 'Gallery up to date (no new items)',
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to scan gallery: $e'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Scan Gallery Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.primary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}
