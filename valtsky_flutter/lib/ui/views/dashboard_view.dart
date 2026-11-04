import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../data/prefs.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../services/background_service.dart';
import '../../services/sync_engine.dart';
import '../../util/media_scanner.dart';
import '../../util/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/failed_item_card.dart';
import '../widgets/animated_stagger.dart';
import '../widgets/passive_elements.dart';

class DashboardView extends StatefulWidget {
  final VoidCallback onNavigateToSettings;
  final Function(String? filter)? onNavigateToActivity;

  const DashboardView({
    super.key,
    required this.onNavigateToSettings,
    required this.onNavigateToActivity,
  });

  @override
  State<DashboardView> createState() => DashboardViewState();
}

class DashboardViewState extends State<DashboardView> {
  int _totalCount = 0;
  int _uploadedCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;
  bool _isRefreshing = false;
  bool _isScanning = false;
  bool _isRestarting = false;
  List<MediaItem> _cachedFailedItems = [];

  @override
  void initState() {
    super.initState();
    refreshStats();
    SyncEngine.statsNotifier.addListener(_onStatsChanged);
  }

  void _onStatsChanged() {
    final stats = SyncEngine.statsNotifier.value;
    if (stats != null && mounted) {
      final prevFailed = _failedCount;
      _totalCount = stats.total;
      _uploadedCount = stats.synced;
      _pendingCount = stats.inQueue;
      _failedCount = stats.failed;

      // Only trigger targeted setState if failed status changed so UI doesn't rebuild on every photo
      if ((prevFailed > 0) != (_failedCount > 0)) {
        if (_failedCount > 0) {
          _loadFailedItems();
        } else {
          setState(() {
            _cachedFailedItems = [];
          });
        }
      }
    }
  }

  Future<void> _loadFailedItems() async {
    final items = await DatabaseHelper.instance.getFailedItems(limit: 2);
    if (mounted) {
      setState(() {
        _cachedFailedItems = items;
      });
    }
  }

  @override
  void dispose() {
    SyncEngine.statsNotifier.removeListener(_onStatsChanged);
    super.dispose();
  }

  Future<void> refreshStats() async {
    final stats = await SyncEngine.fetchCurrentStats(forceDb: true);
    List<MediaItem> failedItems = [];
    if (stats.failed > 0) {
      failedItems = await DatabaseHelper.instance.getFailedItems(limit: 2);
    }
    if (mounted) {
      setState(() {
        _totalCount = stats.total;
        _uploadedCount = stats.synced;
        _pendingCount = stats.inQueue;
        _failedCount = stats.failed;
        _cachedFailedItems = failedItems;
      });
    }
  }

  /// Instant, zero-lag count refresh without heavy filesystem gallery scanning
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await refreshStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Live counts refreshed'),
              ],
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Scans device gallery in strict chronological order and queues any newly discovered media
  Future<void> _handleScanGallery() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    try {
      final newCount = await MediaScanner.scanForNewMedia();
      await refreshStats();
      if (mounted) {
        final total = _totalCount;
        final msg = newCount > 0
            ? 'Scan complete: $newCount new captures queued ($total total)'
            : 'Gallery up to date ($total media items indexed)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(msg)),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Gallery scan error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Self-healing full restart of upload workers, socket pool, and queue state
  Future<void> _handleRestartEngine() async {
    if (_isRestarting) return;
    setState(() => _isRestarting = true);
    try {
      await SyncEngine.instance.restartEngine();
      await refreshStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Engine restarted: Sockets flushed & queue reset'),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestarting = false);
    }
  }

  Future<void> _toggleMonitoring() async {
    if (!Prefs.isConfigured()) {
      widget.onNavigateToSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Please connect your Telegram account first'),
        ),
      );
      return;
    }

    final newStatus = !Prefs.monitoringEnabled;
    Prefs.monitoringEnabled = newStatus;
    if (!kIsWeb) {
      if (newStatus) {
        await BackgroundService.start();
        SyncEngine().startSync();
        // Immediately scan for any new captures taken while monitoring was off
        MediaScanner.scanForNewMedia().then((_) {
          if (mounted) refreshStats();
        });
      } else {
        await BackgroundService.stop();
        SyncEngine().stopSync();
      }
    } else {
      if (newStatus) {
        SyncEngine().startSync();
      } else {
        SyncEngine().stopSync();
      }
    }
    setState(() {});
    await refreshStats();
  }

  void _togglePauseUpload() {
    final newPause = !Prefs.uploadPaused;
    Prefs.uploadPaused = newPause;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConfigured = Prefs.isConfigured();
    final isMonitoring = Prefs.monitoringEnabled;
    final isPaused = Prefs.uploadPaused;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: ValtSkyTheme.primaryAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── ACTIVE ENGINE STATUS BANNER (IF ANY ISSUE) ───
            _buildEngineStatusBanner(isDark),

            // ─── 2X2 METRIC GRID ──────────────────────────────
            StaggeredFadeSlide(
              delayMs: 0,
              child: _buildMetricsGrid(isDark),
            ),
            const SizedBox(height: 18),

            // ─── SYNC PROGRESS & SPEED ────────────────────────
            StaggeredFadeSlide(
              delayMs: 40,
              child: _buildProgressSection(isDark, isMonitoring, isPaused),
            ),
            const SizedBox(height: 18),

            // ─── FAILED ITEMS ALERT (IF ANY) ─────────────────
            if (_failedCount > 0 || _cachedFailedItems.isNotEmpty) ...[
              StaggeredFadeSlide(
                delayMs: 80,
                child: _buildFailedItemsAlert(isDark),
              ),
              const SizedBox(height: 18),
            ],

            // ─── QUICK CONTROLS ──────────────────────────────
            StaggeredFadeSlide(
              delayMs: 120,
              child: _buildQuickControls(isConfigured, isMonitoring, isPaused),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    return ValueListenableBuilder<SyncStats?>(
      valueListenable: SyncEngine.statsNotifier,
      builder: (context, stats, _) {
        final total = stats?.total ?? _totalCount;
        final synced = stats?.synced ?? _uploadedCount;
        final inQueue = stats?.inQueue ?? _pendingCount;
        final failed = stats?.failed ?? _failedCount;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _buildMetricTile(
              title: 'TOTAL MEDIA',
              count: '$total',
              icon: Icons.photo_library_rounded,
              color: isDark ? Colors.white : Colors.black,
              isDark: isDark,
              onTap: () => widget.onNavigateToActivity?.call('ALL'),
            ),
            _buildMetricTile(
              title: 'SYNCED',
              count: '$synced',
              icon: Icons.cloud_done_rounded,
              color: ValtSkyTheme.success,
              isDark: isDark,
              onTap: () => widget.onNavigateToActivity?.call('SYNCED'),
            ),
            _buildMetricTile(
              title: 'IN QUEUE',
              count: '$inQueue',
              icon: Icons.hourglass_top_rounded,
              color: ValtSkyTheme.warning,
              isDark: isDark,
              onTap: () => widget.onNavigateToActivity?.call('QUEUED'),
            ),
            _buildMetricTile(
              title: 'FAILED',
              count: '$failed',
              icon: Icons.error_outline_rounded,
              color: failed > 0 ? ValtSkyTheme.error : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
              isDark: isDark,
              onTap: () => widget.onNavigateToActivity?.call('FAILED'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return TactilePress(
      onTap: onTap,
      scaleDown: 0.96,
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            Text(
              count,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(bool isDark, bool isMonitoring, bool isPaused) {
    return ValueListenableBuilder<SyncStats?>(
      valueListenable: SyncEngine.statsNotifier,
      builder: (context, stats, child) {
        final total = stats?.total ?? _totalCount;
        final synced = stats?.synced ?? _uploadedCount;
        final progress = total == 0 ? 0.0 : (synced / total).clamp(0.0, 1.0);
        final percentage = (progress * 100).toInt();

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
                      const SizedBox(width: 8),
                      const Text(
                        'Backup Progress',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: SyncEngine.uploadSpeedNotifier,
                        builder: (context, speed, child) {
                          if (speed.isEmpty) return const SizedBox();
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ValtSkyTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              speed,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ValtSkyTheme.success,
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: isDark 
                      ? Colors.white.withValues(alpha: 0.06) 
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$synced of $total files backed up',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  if (Prefs.lastSyncedTs > 0)
                    Text(
                      'Updated ${_formatRelativeTime(Prefs.lastSyncedTs)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Oldest captures sync first (chronological order)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '100% EXIF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRelativeTime(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildFailedItemsAlert(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: ValtSkyTheme.error),
                const SizedBox(width: 8),
                Text(
                  'Failed Uploads ($_failedCount)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ValtSkyTheme.error,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await DatabaseHelper.instance.stashAllFailed();
                    await refreshStats();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All failed uploads stashed'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Stash All', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await DatabaseHelper.instance.retryAllFailed();
                    await refreshStats();
                    if (Prefs.monitoringEnabled) {
                      SyncEngine().startSync();
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry All', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_cachedFailedItems.isNotEmpty)
          Column(
            children: _cachedFailedItems.take(2).map((item) => FailedItemCard(
              item: item,
              onRetry: () async {
                await refreshStats();
                if (Prefs.monitoringEnabled) {
                  SyncEngine().startSync();
                }
              },
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildQuickControls(bool isConfigured, bool isMonitoring, bool isPaused) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── MASTER BACKUP HERO CARD ────────────────────────
        _buildMasterMonitoringCard(isConfigured, isMonitoring, isPaused, isDark),
        const SizedBox(height: 14),

        // ─── 2X2 SYSTEM CONTROL MATRIX ──────────────────────
        Row(
          children: [
            // Control 1: Pause / Resume Uploads
            Expanded(
              child: _buildActionTile(
                title: isPaused ? 'Resume' : 'Pause',
                subtitle: isPaused
                    ? 'Uploads on hold'
                    : (isMonitoring ? 'Hold transfer queue' : 'Start backup first'),
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                accentColor: isPaused
                    ? ValtSkyTheme.warning
                    : (isMonitoring ? Colors.amber : (isDark ? Colors.grey[600]! : Colors.grey[400]!)),
                isDark: isDark,
                isHighlighted: isPaused,
                badgeText: isPaused ? 'PAUSED' : null,
                onTap: isMonitoring ? _togglePauseUpload : null,
              ),
            ),
            const SizedBox(width: 12),

            // Control 2: Scan Device Gallery (Chronological)
            Expanded(
              child: _buildActionTile(
                title: 'Scan Gallery',
                subtitle: _isScanning ? 'Reading storage...' : 'Detect new captures',
                icon: Icons.photo_library_rounded,
                accentColor: const Color(0xFF00B4D8),
                isDark: isDark,
                isLoading: _isScanning,
                onTap: _isScanning ? null : _handleScanGallery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Control 3: Refresh Counts
            Expanded(
              child: _buildActionTile(
                title: 'Refresh Counts',
                subtitle: _isRefreshing ? 'Querying database...' : 'Instant stats sync',
                icon: Icons.sync_rounded,
                accentColor: const Color(0xFF8B5CF6),
                isDark: isDark,
                isLoading: _isRefreshing,
                onTap: _isRefreshing ? null : _handleRefresh,
              ),
            ),
            const SizedBox(width: 12),

            // Control 4: Restart Engine (Self-Healing)
            Expanded(
              child: _buildActionTile(
                title: 'Restart Engine',
                subtitle: _isRestarting ? 'Flushing sockets...' : 'Reset sockets & queue',
                icon: Icons.restart_alt_rounded,
                accentColor: const Color(0xFF06D6A0),
                isDark: isDark,
                isLoading: _isRestarting,
                onTap: _isRestarting ? null : _handleRestartEngine,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ─── SYSTEM HEALTH & DIAGNOSTICS CARD ────────────────
        _buildDiagnosticsControlTile(isDark),
      ],
    );
  }

  Widget _buildMasterMonitoringCard(bool isConfigured, bool isMonitoring, bool isPaused, bool isDark) {
    Color cardBorderColor;
    if (!isConfigured) {
      cardBorderColor = isDark ? Colors.white12 : Colors.black12;
    } else if (isMonitoring) {
      cardBorderColor = isPaused ? ValtSkyTheme.warning.withValues(alpha: 0.5) : ValtSkyTheme.success.withValues(alpha: 0.5);
    } else {
      cardBorderColor = isDark ? Colors.white24 : Colors.black26;
    }

    return GlassCard(
      padding: const EdgeInsets.all(18),
      border: Border.all(color: cardBorderColor, width: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AmbientRadarDot(
                    color: !isConfigured
                        ? Colors.grey
                        : isMonitoring
                            ? (isPaused ? ValtSkyTheme.warning : ValtSkyTheme.success)
                            : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    size: 8,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !isConfigured
                        ? 'SETUP REQUIRED'
                        : isMonitoring
                            ? (isPaused ? 'ENGINE PAUSED' : 'MONITORING ACTIVE')
                            : 'STANDBY (OFF)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: !isConfigured
                          ? Colors.grey
                          : isMonitoring
                              ? (isPaused ? ValtSkyTheme.warning : ValtSkyTheme.success)
                              : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                    ),
                  ),
                ],
              ),
              if (isMonitoring && !isPaused)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '4x MTProto Turbo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ValtSkyTheme.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Master CTA Button
          TactilePress(
            scaleDown: 0.98,
            onTap: isConfigured ? _toggleMonitoring : widget.onNavigateToSettings,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: !isConfigured
                    ? (isDark ? Colors.white : Colors.black)
                    : isMonitoring
                        ? ValtSkyTheme.error
                        : (isDark ? Colors.white : Colors.black),
                boxShadow: [
                  if (isMonitoring)
                    BoxShadow(
                      color: ValtSkyTheme.error.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !isConfigured
                        ? Icons.link_rounded
                        : isMonitoring
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                    size: 22,
                    color: !isConfigured
                        ? (isDark ? Colors.black : Colors.white)
                        : isMonitoring
                            ? Colors.white
                            : (isDark ? Colors.black : Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    !isConfigured
                        ? 'CONFIGURE TELEGRAM BACKUP'
                        : isMonitoring
                            ? 'STOP MONITORING'
                            : 'START CLOUD BACKUP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: !isConfigured
                          ? (isDark ? Colors.black : Colors.white)
                          : isMonitoring
                              ? Colors.white
                              : (isDark ? Colors.black : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              !isConfigured
                  ? 'Connect Telegram to activate zero-loss storage'
                  : isMonitoring
                      ? 'Camera roll is actively syncing to your private Telegram channel'
                      : 'Monitoring is off. Backups will not run until started.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isHighlighted = false,
    String? badgeText,
  }) {
    final isEnabled = onTap != null;

    return TactilePress(
      onTap: onTap,
      scaleDown: isEnabled ? 0.96 : 1.0,
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: Border.all(
          color: isHighlighted
              ? accentColor.withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
          width: isHighlighted ? 1.4 : 1.0,
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.45,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: accentColor,
                          ),
                        )
                      : Icon(icon, color: accentColor, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsControlTile(bool isDark) {
    return TactilePress(
      onTap: () => _showDiagnosticsSheet(context, isDark),
      scaleDown: 0.98,
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ValtSkyTheme.primaryAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.monitor_heart_rounded,
                color: ValtSkyTheme.primaryAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Engine Diagnostics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ValtSkyTheme.primaryAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SYSTEM HEALTH',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: ValtSkyTheme.primaryAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MTProto DC socket health, queue telemetry & connection repair',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineStatusBanner(bool isDark) {
    return ValueListenableBuilder<SyncEngineStatus>(
      valueListenable: SyncEngine.engineStatusNotifier,
      builder: (context, status, _) {
        if (status == SyncEngineStatus.idle ||
            status == SyncEngineStatus.active ||
            status == SyncEngineStatus.paused) {
          return const SizedBox.shrink();
        }

        switch (status) {
          case SyncEngineStatus.offline:
            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              child: GlassCard(
                borderRadius: 20,
                border: Border.all(color: ValtSkyTheme.warning.withValues(alpha: 0.5)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ValtSkyTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: ValtSkyTheme.warning, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No Internet Connection',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ValtSkyTheme.warning),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Uploads paused safely. Will auto-resume when online.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: ValtSkyTheme.warning.withValues(alpha: 0.15),
                        foregroundColor: ValtSkyTheme.warning,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () async {
                        final reconnected = await SyncEngine.instance.checkNetworkAndResume();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: reconnected ? ValtSkyTheme.success : ValtSkyTheme.warning,
                              content: Text(reconnected ? 'Connected! Resuming uploads...' : 'Still offline. Check your network.'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: const Text('Check', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );

          case SyncEngineStatus.rateLimited:
            return ValueListenableBuilder<int>(
              valueListenable: SyncEngine.rateLimitSecondsRemainingNotifier,
              builder: (context, secondsRemaining, _) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: GlassCard(
                    borderRadius: 20,
                    border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.hourglass_bottom_rounded, color: Colors.indigoAccent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Telegram Cooldown Active',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.indigoAccent),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Flood wait detected. Auto-resuming in ${secondsRemaining}s...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${secondsRemaining}s',
                            style: const TextStyle(
                              color: Colors.indigoAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

          case SyncEngineStatus.sessionExpired:
            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              child: GlassCard(
                borderRadius: 20,
                border: Border.all(color: ValtSkyTheme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ValtSkyTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: ValtSkyTheme.error, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Telegram Session Expired',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ValtSkyTheme.error),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Authentication key was revoked. Tap to re-login.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ValtSkyTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: widget.onNavigateToSettings,
                      child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );

          case SyncEngineStatus.permissionDenied:
            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              child: GlassCard(
                borderRadius: 20,
                border: Border.all(color: ValtSkyTheme.warning.withValues(alpha: 0.5)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ValtSkyTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.no_photography_rounded, color: ValtSkyTheme.warning, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gallery Access Needed',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ValtSkyTheme.warning),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Permission required to scan & back up your photos.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ValtSkyTheme.warning,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => PhotoManager.openSetting(),
                      child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );

          case SyncEngineStatus.restarting:
            return Container(
              margin: const EdgeInsets.only(bottom: 18),
              child: GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Restarting Sync Engine...',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Flushing socket pool & cleaning upload queue...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  void _showDiagnosticsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121215) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final engineStatus = SyncEngine.engineStatusNotifier.value;
            final phone = Prefs.userPhoneNumber.isNotEmpty ? Prefs.userPhoneNumber : (Prefs.botToken.isNotEmpty ? 'Bot Token' : 'Not configured');
            final channel = Prefs.channelName.isNotEmpty ? Prefs.channelName : (Prefs.channelId.isNotEmpty ? Prefs.channelId : 'None');
            final dcId = Prefs.telegramDcId;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Icon(Icons.health_and_safety_rounded, color: ValtSkyTheme.primaryAccent, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Engine Diagnostics & Repair',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDiagRow('Engine Status', engineStatus.name.toUpperCase(), isDark, highlight: true),
                    _buildDiagRow('Active Workers', '4 Parallel Turbo Workers', isDark),
                    _buildDiagRow('Telegram Target', '$channel (DC $dcId)', isDark),
                    _buildDiagRow('Auth Account', phone, isDark),
                    _buildDiagRow('Total Gallery Items', '$_totalCount', isDark),
                    _buildDiagRow('Synced to Telegram', '$_uploadedCount', isDark),
                    _buildDiagRow('Pending in Queue', '$_pendingCount', isDark),
                    _buildDiagRow('Failed Uploads', '$_failedCount', isDark),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ValtSkyTheme.primaryAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _handleRestartEngine();
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 20),
                        label: const Text('Restart Engine & Flush Sockets', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (_failedCount > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await DatabaseHelper.instance.retryAllFailed();
                                await refreshStats();
                                if (Prefs.monitoringEnabled) {
                                  SyncEngine().startSync();
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry All Failed', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await DatabaseHelper.instance.stashAllFailed();
                                await refreshStats();
                              },
                              icon: const Icon(Icons.archive_outlined, size: 16),
                              label: const Text('Stash All Failed', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiagRow(String title, String value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: highlight ? FontWeight.w900 : FontWeight.w700, color: highlight ? ValtSkyTheme.primaryAccent : (isDark ? Colors.white : Colors.black))),
        ],
      ),
    );
  }
}
