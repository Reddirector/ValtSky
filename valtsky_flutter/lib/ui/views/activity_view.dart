import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../data/models/media_breakdown.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../widgets/media_item_card.dart';
import '../widgets/manual_upload_assistant_sheet.dart';
import '../widgets/valtsky_components.dart';
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

  String _selectedFilter = 'ALL';
  List<MediaItem> _oversizedItems = [];
  bool _isRetryingAll = false;
  bool _isClearingQueue = false;
  bool _isScanning = false;

  MediaBreakdown _breakdown = const MediaBreakdown();
  int _oversizedCount = 0;
  int _stashedCount = 0;

  @override
  void initState() {
    super.initState();
    SyncEngine.mediaBreakdownNotifier.addListener(_onBreakdownChanged);
    refreshItems();
  }

  @override
  void dispose() {
    SyncEngine.mediaBreakdownNotifier.removeListener(_onBreakdownChanged);
    super.dispose();
  }

  void _onBreakdownChanged() {
    if (!mounted) return;
    setState(() {
      _breakdown = SyncEngine.mediaBreakdownNotifier.value;
      _oversizedCount = _breakdown.oversizedCount;
    });
  }

  Future<void> refreshItems() async {
    if (!mounted) return;

    final breakdown = await DatabaseHelper.instance.getMediaBreakdown();
    final stashedCount = await DatabaseHelper.instance.getStashedCount();

    List<MediaItem> oversized = [];
    if (_selectedFilter == 'OVERSIZED') {
      oversized = await DatabaseHelper.instance.getAllItems(statusFilter: 'OVERSIZED', limit: 50);
    }

    if (mounted) {
      setState(() {
        _breakdown = breakdown;
        _oversizedCount = breakdown.oversizedCount;
        _stashedCount = stashedCount;
        _oversizedItems = oversized;
      });
    }
  }

  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
      });
      refreshItems();
    }
  }

  Future<void> _handleClearQueue() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: const Text('Clear Upload Queue?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
          'This will remove all pending photos and videos from the active upload queue. Your local files will not be deleted.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Queue', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearingQueue = true);
    try {
      final removed = await DatabaseHelper.instance.clearPendingQueue();
      await refreshItems();
      if (!mounted) return;
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared $removed items from upload queue'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ValtSkyTheme.primary(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingQueue = false);
      }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── FILTER TABS BAR ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All', badgeCount: _breakdown.totalCount),
                          const SizedBox(width: 8),
                          _buildFilterChip(MediaItem.statusPending, 'Queued', badgeCount: _breakdown.totalPending),
                          const SizedBox(width: 8),
                          _buildFilterChip(MediaItem.statusDone, 'Synced', badgeCount: _breakdown.totalSynced),
                          const SizedBox(width: 8),
                          _buildFilterChip('OVERSIZED', '> 2 GB', badgeCount: _breakdown.oversizedCount),
                          const SizedBox(width: 8),
                          _buildFilterChip(MediaItem.statusFailed, 'Failed', badgeCount: _breakdown.totalFailed),
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

              // ─── OVERSIZED VAULT VIEW (IF IN > 2 GB TAB) ───────────────
              if (_selectedFilter == 'OVERSIZED') ...[
                _buildOversizedHeader(isDark),
                if (_oversizedItems.isEmpty)
                  _buildEmptyState(isDark)
                else
                  ..._oversizedItems.map(
                    (item) => MediaItemCard(
                      key: ValueKey(item.filePath),
                      item: item,
                      onChanged: () {
                        refreshItems();
                        widget.onDataChanged();
                      },
                      onRemove: () async {
                        await DatabaseHelper.instance.deleteItem(item.filePath);
                        refreshItems();
                        widget.onDataChanged();
                      },
                      onManualUpload: () => _openManualUploadAssistant([item]),
                    ),
                  ),
              ] else ...[
                // ─── QUEUE SUMMARY BANNER ──────────────────────────────
                _buildQueueSummaryBanner(isDark),

                // ─── NOTICE FOR OVERSIZED FILES IN QUEUED TAB ──────────
                if (_selectedFilter == MediaItem.statusPending && _breakdown.oversizedCount > 0)
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
                            '${_breakdown.oversizedCount} oversized files (> 2 GB) held for manual upload',
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

                // ─── THE FOUR TELEMETRY BLOCKS ─────────────────────────
                _buildFourTelemetryBlocks(isDark),

                const SizedBox(height: 16),

                // ─── ZERO-LAG ACTIONS DECK ─────────────────────────────
                _buildActionDeck(isDark),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Four distinct telemetry blocks displaying live photo and video counts that decrement live.
  Widget _buildFourTelemetryBlocks(bool isDark) {
    return Column(
      children: [
        // Row 1: Queue Blocks (Photos in Queue + Videos in Queue)
        Row(
          children: [
            Expanded(
              child: _buildTelemetryBlock(
                title: 'PHOTOS IN QUEUE',
                count: _breakdown.pendingPhotos,
                subtitle: _breakdown.pendingPhotos > 0 ? 'Pending / In-Flight' : 'Queue Empty',
                icon: Icons.photo_library_outlined,
                color: const Color(0xFF38BDF8), // Electric Cyan / Sky
                isDark: isDark,
                isActiveTrack: _breakdown.pendingPhotos > 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTelemetryBlock(
                title: 'VIDEOS IN QUEUE',
                count: _breakdown.pendingVideos,
                subtitle: _breakdown.pendingVideos > 0 ? 'Preparing / Wire' : 'Queue Empty',
                icon: Icons.videocam_outlined,
                color: const Color(0xFFF59E0B), // Vivid Amber
                isDark: isDark,
                isActiveTrack: _breakdown.pendingVideos > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Synced Blocks (Photos Synced + Videos Synced)
        Row(
          children: [
            Expanded(
              child: _buildTelemetryBlock(
                title: 'PHOTOS SYNCED',
                count: _breakdown.syncedPhotos,
                subtitle: '100% Lossless',
                icon: Icons.cloud_done_rounded,
                color: const Color(0xFF10B981), // Emerald Green
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTelemetryBlock(
                title: 'VIDEOS SYNCED',
                count: _breakdown.syncedVideos,
                subtitle: 'Original Bitrate',
                icon: Icons.video_library_rounded,
                color: const Color(0xFF8B5CF6), // Royal Violet
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTelemetryBlock({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isActiveTrack = false,
  }) {
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = isActiveTrack
        ? ValtSkyTheme.amber.withValues(alpha: 0.45)
        : ValtSkyTheme.hairline(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (isActiveTrack)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ValtSkyTheme.amber.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamily,
              fontSize: 32,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              color: ValtSkyTheme.textPrimary(isDark),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ValtSkyTheme.capsLabel(
              isDark: isDark,
              color: isDark ? color : (isActiveTrack ? ValtSkyTheme.accentText(isDark) : ValtSkyTheme.textSecondary(isDark)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: mutedText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Compact action deck for managing the queue without rendering huge lists.
  Widget _buildActionDeck(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            // Scan Gallery Now
            Expanded(
              child: PillButton(
                label: 'Scan Gallery',
                icon: Icons.sync_rounded,
                variant: PillButtonVariant.primary,
                isLoading: _isScanning,
                onPressed: _isScanning
                    ? null
                    : () async {
                        setState(() => _isScanning = true);
                        try {
                          final newCount = await MediaScanner.scanForNewMedia(forceFull: false);
                          await refreshItems();
                          widget.onDataChanged();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newCount > 0
                                    ? 'Scanned gallery: $newCount new items queued'
                                    : 'Gallery up to date (no new items)',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: ValtSkyTheme.primary(isDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isScanning = false);
                        }
                      },
              ),
            ),
            const SizedBox(width: 10),
            // Clear Queue / Exclude
            Expanded(
              child: PillButton(
                label: 'Clear Queue',
                icon: Icons.delete_outline_rounded,
                variant: PillButtonVariant.secondary,
                isLoading: _isClearingQueue,
                onPressed: _isClearingQueue ? null : _handleClearQueue,
              ),
            ),
          ],
        ),
        if (_breakdown.totalFailed > 0) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: 'Retry ${_breakdown.totalFailed} Failed Transfers',
              icon: Icons.replay_rounded,
              variant: PillButtonVariant.destructive,
              isLoading: _isRetryingAll,
              onPressed: _isRetryingAll
                  ? null
                  : () async {
                      setState(() => _isRetryingAll = true);
                      try {
                        final retried = await DatabaseHelper.instance.retryAllFailed();
                        await refreshItems();
                        if (!mounted) return;
                        widget.onDataChanged();
                        if (!Prefs.uploadPaused) {
                          SyncEngine().startSync();
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$retried failed items requeued'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: ValtSkyTheme.success,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _isRetryingAll = false);
                      }
                    },
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: PillButton(
            label: 'Open Telegram Channel',
            icon: Icons.open_in_new_rounded,
            variant: PillButtonVariant.outline,
            onPressed: () => TelegramLauncher.openChannel(context),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueSummaryBanner(bool isDark) {
    final secondaryColor = ValtSkyTheme.accentText(isDark);
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    final pendingCount = _breakdown.totalPending;
    final syncedCount = _breakdown.totalSynced;

    String title;
    String subtitle;
    IconData icon;

    if (_selectedFilter == MediaItem.statusPending) {
      title = '$pendingCount PENDING IN QUEUE';
      subtitle = pendingCount > 0
          ? '${_breakdown.pendingPhotos} photos, ${_breakdown.pendingVideos} videos in flight'
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
      final failedCount = _breakdown.totalFailed;
      title = '$failedCount FAILED TRANSFERS';
      subtitle = 'Check connection or retry';
      icon = Icons.error_outline_rounded;
    } else {
      final totalCount = _breakdown.totalCount;
      title = '$totalCount TOTAL MEDIA TRACKED';
      subtitle = '$pendingCount pending • $syncedCount synced';
      icon = Icons.photo_library_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: secondaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: secondaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: 11,
                    color: mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_selectedFilter == MediaItem.statusFailed && _breakdown.totalFailed > 0)
            ElevatedButton.icon(
              onPressed: _isRetryingAll
                  ? null
                  : () async {
                      setState(() => _isRetryingAll = true);
                      try {
                        final count = await DatabaseHelper.instance.retryAllFailed();
                        await refreshItems();
                        if (!mounted) return;
                        widget.onDataChanged();
                        if (!Prefs.uploadPaused) {
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
                backgroundColor: ValtSkyTheme.statusFailed,
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
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Center(
        child: ChoiceChip(
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
                        ? ValtSkyTheme.ink.withValues(alpha: 0.14)
                        : (filterKey == 'OVERSIZED' && badgeCount > 0
                            ? ValtSkyTheme.amber.withValues(alpha: 0.25)
                            : ValtSkyTheme.raised(isDark)),
                    borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontFamily: ValtSkyTheme.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? ValtSkyTheme.ink
                          : (filterKey == 'OVERSIZED' && badgeCount > 0
                              ? ValtSkyTheme.accentText(isDark)
                              : mutedText),
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
            fontFamily: ValtSkyTheme.fontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? ValtSkyTheme.ink : mutedText,
          ),
          selectedColor: ValtSkyTheme.amber,
          backgroundColor: cardBg,
          side: BorderSide(
            color: isSelected ? ValtSkyTheme.amber : borderColor,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill)),
        ),
      ),
    );
  }

  Widget _buildOversizedHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ValtSkyTheme.surface(isDark),
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
        border: Border.all(color: ValtSkyTheme.hairline(isDark)),
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
                      color: ValtSkyTheme.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers_clear_rounded, size: 18, color: ValtSkyTheme.amber),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVERSIZED VAULT (> 2 GB)',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ValtSkyTheme.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        'Exceeds standard automated Bot limits',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamily,
                          fontSize: 11,
                          color: ValtSkyTheme.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ValtSkyTheme.raised(isDark),
                  borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                  border: Border.all(color: ValtSkyTheme.hairline(isDark)),
                ),
                child: Text(
                  '$_oversizedCount Files',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          if (_oversizedItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PillButton(
                    label: 'UPLOAD ALL OVERSIZED',
                    icon: Icons.bolt_rounded,
                    variant: PillButtonVariant.primary,
                    onPressed: () => _openManualUploadAssistant(_oversizedItems),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PillButton(
                    label: 'Open Channel',
                    icon: Icons.open_in_new_rounded,
                    variant: PillButtonVariant.outline,
                    onPressed: () => TelegramLauncher.openChannel(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ValtSkyTheme.surface(isDark),
                shape: BoxShape.circle,
                border: Border.all(color: ValtSkyTheme.hairline(isDark)),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 40,
                color: ValtSkyTheme.amber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Oversized Vault Clear',
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ValtSkyTheme.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No media files exceed the 2 GB threshold',
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamily,
                fontSize: 12,
                color: ValtSkyTheme.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
