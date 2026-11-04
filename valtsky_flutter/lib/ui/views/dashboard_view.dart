import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../data/prefs.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../services/background_service.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/failed_item_card.dart';
import '../widgets/animated_stagger.dart';

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
      } else {
        await BackgroundService.stop();
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
      children: [
        // Primary Start/Stop Master Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isConfigured ? _toggleMonitoring : widget.onNavigateToSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: !isConfigured
                  ? (isDark ? Colors.white : Colors.black)
                  : isMonitoring
                      ? ValtSkyTheme.error
                      : (isDark ? Colors.white : Colors.black),
              foregroundColor: isMonitoring ? Colors.white : (isDark ? Colors.black : Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  !isConfigured
                      ? Icons.arrow_forward_rounded
                      : isMonitoring
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  !isConfigured
                      ? 'CONFIGURE TELEGRAM BACKUP'
                      : isMonitoring
                          ? 'STOP MONITORING'
                          : 'START BACKGROUND MONITORING',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Row of Controls
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: isMonitoring ? _togglePauseUpload : null,
                  icon: Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isPaused ? 'Resume Upload' : 'Pause Upload',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  icon: _isRefreshing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Refresh Counts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tertiary Row of Controls (Self-Healing Restart & Diagnostics)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isRestarting ? null : _handleRestartEngine,
                  icon: _isRestarting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text(
                    'Restart Engine',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showDiagnosticsSheet(context, isDark),
                  icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                  label: const Text(
                    'Diagnostics',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
