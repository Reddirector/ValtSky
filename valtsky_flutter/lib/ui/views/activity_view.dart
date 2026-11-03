import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../util/theme.dart';
import '../widgets/media_item_card.dart';
import '../widgets/animated_stagger.dart';
import '../widgets/manual_upload_assistant_sheet.dart';
import '../../util/telegram_launcher.dart';

class ActivityView extends StatefulWidget {
  final VoidCallback onDataChanged;

  const ActivityView({super.key, required this.onDataChanged});

  @override
  State<ActivityView> createState() => ActivityViewState();
}

class ActivityViewState extends State<ActivityView> {
  String _selectedFilter = 'ALL';
  List<MediaItem> _items = [];
  bool _isLoading = true;
  int _oversizedCount = 0;

  @override
  void initState() {
    super.initState();
    refreshItems();
  }

  Future<void> refreshItems() async {
    setState(() => _isLoading = true);
    final status = _selectedFilter == 'ALL' ? null : _selectedFilter;
    final items = await DatabaseHelper.instance.getAllItems(statusFilter: status);
    final oversizedCount = await DatabaseHelper.instance.getOversizedCount();
    if (mounted) {
      setState(() {
        _items = items;
        _oversizedCount = oversizedCount;
        _isLoading = false;
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

  Future<void> _simulateNewPhoto() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Simulate Gallery Capture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'Add simulated media to test background sync and oversized manual uploads',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_rounded),
                title: const Text('Simulate Standard Photo (3.5 MB)'),
                subtitle: const Text('Uploads automatically via background sync'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertMockMedia(isVideo: false, isOversized: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.movie_rounded),
                title: const Text('Simulate Video (45 MB)'),
                subtitle: const Text('Chunks into 48MB parts if limit exceeded'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertMockMedia(isVideo: true, isOversized: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_rounded, color: ValtSkyTheme.warning),
                title: const Text('Simulate Oversized 4K Master (2.85 GB)'),
                subtitle: const Text('Held in QUEUED for 4-click manual lossless upload'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertMockMedia(isVideo: true, isOversized: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _insertMockMedia({required bool isVideo, required bool isOversized}) async {
    final randId = Random().nextInt(9000) + 1000;
    final ext = isOversized ? 'mov' : (isVideo ? 'mp4' : 'jpg');
    final mime = isOversized ? 'video/quicktime' : (isVideo ? 'video/mp4' : 'image/jpeg');
    final size = isOversized
        ? 2854300000 // 2.85 GB
        : (isVideo ? (30 + Random().nextInt(30)) * 1024 * 1024 : (2 + Random().nextInt(5)) * 1024 * 1024);
    final prefix = isOversized ? 'VID_4K60_RAW' : (isVideo ? 'VID' : 'IMG');

    final newItem = MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/${prefix}_20261101_$randId.$ext',
      mimeType: mime,
      dateTaken: DateTime.now().millisecondsSinceEpoch,
      fileSize: size,
      status: MediaItem.statusPending,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseHelper.instance.insert(newItem);
    await refreshItems();
    widget.onDataChanged();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isOversized ? ValtSkyTheme.warning : ValtSkyTheme.primaryAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            isOversized
                ? '⚡ 2.85 GB Oversized file added to > 2 GB queue!'
                : 'Simulated new media added to sync queue: ${prefix}_20261101_$randId.$ext',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips Row + Add Simulation Button
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip(MediaItem.statusDone, 'Synced'),
                      const SizedBox(width: 8),
                      _buildFilterChip(MediaItem.statusPending, 'Queued'),
                      const SizedBox(width: 8),
                      _buildFilterChip('OVERSIZED', '> 2 GB', badgeCount: _oversizedCount),
                      const SizedBox(width: 8),
                      _buildFilterChip(MediaItem.statusFailed, 'Failed'),
                      const SizedBox(width: 8),
                      _buildFilterChip(MediaItem.statusStashed, 'Stashed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Simulate taking a new photo',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                onPressed: _simulateNewPhoto,
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                          '${_items.length} Files',
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
                            onTap: () => _openManualUploadAssistant(_items),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 20, color: isDark ? Colors.black : Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'UPLOAD ALL OVERSIZED',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: isDark ? Colors.black : Colors.white,
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
                        '${_items.length} Stashed Files',
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
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                return StaggeredFadeSlide(
                                  delayMs: (index * 35).clamp(0, 200),
                                  child: MediaItemCard(
                                    item: _items[index],
                                    onChanged: () {
                                      refreshItems();
                                      widget.onDataChanged();
                                    },
                                    onManualUpload: () => _openManualUploadAssistant([_items[index]]),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {int? badgeCount}) {
    final isSelected = _selectedFilter == filterKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badgeCount != null && badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : ValtSkyTheme.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.black,
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
        color: isSelected 
            ? (isDark ? Colors.black : Colors.white)
            : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B)),
      ),
      selectedColor: isDark ? Colors.white : Colors.black,
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      side: BorderSide(
        color: isSelected 
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
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
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _simulateNewPhoto,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: const Text('Add Test Photo'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
        ],
      ),
    );
  }
}
