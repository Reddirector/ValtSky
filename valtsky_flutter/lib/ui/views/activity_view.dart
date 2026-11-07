import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../data/models/media_breakdown.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../widgets/media_item_card.dart';
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
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActiveTrack ? color.withValues(alpha: 0.35) : borderColor,
          width: 1.2,
        ),
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
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
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
    final primaryColor = ValtSkyTheme.primary(isDark);

    return Column(
      children: [
        Row(
          children: [
            // Scan Gallery Now
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isScanning ? null : () async {
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
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Scan Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            // Clear Queue / Exclude
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7)),
                  ),
                ),
                onPressed: _isClearingQueue ? null : _handleClearQueue,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Clear Queue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        if (_breakdown.totalFailed > 0) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isRetryingAll
                  ? null
                  : () async {
                      setState(() => _isRetryingAll = true);
                      try {
                        final retried = await DatabaseHelper.instance.retryAllFailed();
                        await refreshItems();
                        if (!mounted) return;
                        widget.onDataChanged();
                        if (Prefs.monitoringEnabled && !Prefs.uploadPaused) {
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
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(
                'Retry ${_breakdown.totalFailed} Failed Transfers',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
            ),
            onPressed: () => TelegramLauncher.openChannel(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open Telegram Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueSummaryBanner(bool isDark) {
    final primaryColor = ValtSkyTheme.primary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

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

  Widget _buildOversizedHeader(bool isDark) {
    final primaryColor = ValtSkyTheme.primary(isDark);

    return Container(
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
          if (_oversizedItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openManualUploadAssistant(_oversizedItems),
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
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
                color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 40,
                color: ValtSkyTheme.primary(isDark),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Oversized Vault Clear',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'No media files exceed the 2 GB threshold',
              style: TextStyle(fontSize: 12, color: ValtSkyTheme.tertiaryText(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}
