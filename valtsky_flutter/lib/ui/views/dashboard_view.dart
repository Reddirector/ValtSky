import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../services/background_service.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../../util/media_scanner.dart';
import '../widgets/glass_card.dart';
import '../widgets/failed_item_card.dart';
import '../widgets/health_status_banner.dart';
import '../widgets/media_slideshow_reel.dart';
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

class DashboardViewState extends State<DashboardView> with SingleTickerProviderStateMixin {
  final GlobalKey<MediaSlideshowReelState> _slideshowKey = GlobalKey<MediaSlideshowReelState>();
  int _totalCount = 0;
  int _uploadedCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;
  bool _isRefreshing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    refreshStats();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> refreshStats() async {
    final total = await DatabaseHelper.instance.getTotalCount();
    final uploaded = await DatabaseHelper.instance.getUploadedCount();
    final pending = await DatabaseHelper.instance.getPendingCount();
    final failed = await DatabaseHelper.instance.getFailedCount();

    if (mounted) {
      setState(() {
        _totalCount = total;
        _uploadedCount = uploaded;
        _pendingCount = pending;
        _failedCount = failed;
      });
      _slideshowKey.currentState?.refresh();
    }
  }

  Future<void> _handleScan() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await MediaScanner.scanForNewMedia();
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
                Text('Gallery scan complete'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
          content: const Text('Please configure Bot Token and Channel ID first'),
        ),
      );
      return;
    }

    final newStatus = !Prefs.monitoringEnabled;
    Prefs.monitoringEnabled = newStatus;
    if (!kIsWeb) {
      if (newStatus) {
        await BackgroundService.start();
      } else {
        await BackgroundService.stop();
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
    final progress = _totalCount == 0 ? 0.0 : (_uploadedCount / _totalCount).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: _handleScan,
      color: ValtSkyTheme.primaryAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── SYSTEM HEALTH & DIAGNOSTIC BANNER ───────────
            StaggeredFadeSlide(
              delayMs: 0,
              child: HealthStatusBanner(
                failedCount: _failedCount,
                onNavigateToSettings: widget.onNavigateToSettings,
                onNavigateToActivity: () => widget.onNavigateToActivity?.call('FAILED'),
                onDataChanged: refreshStats,
              ),
            ),
            const SizedBox(height: 14),

            // ─── HERO STATUS CARD ────────────────────────────
            StaggeredFadeSlide(
              delayMs: 40,
              child: _buildHeroCard(isDark, isConfigured, isMonitoring, isPaused),
            ),
            const SizedBox(height: 18),

            // ─── RECENT MEDIA SLIDESHOW REEL ─────────────────
            StaggeredFadeSlide(
              delayMs: 80,
              child: MediaSlideshowReel(
                key: _slideshowKey,
                onDataChanged: refreshStats,
              ),
            ),
            const SizedBox(height: 18),

            // ─── 2X2 METRIC GRID ──────────────────────────────
            StaggeredFadeSlide(
              delayMs: 120,
              child: _buildMetricsGrid(isDark),
            ),
            const SizedBox(height: 18),

            // ─── SYNC PROGRESS & SPEED ────────────────────────
            StaggeredFadeSlide(
              delayMs: 160,
              child: _buildProgressSection(progress, isDark, isMonitoring, isPaused),
            ),
            const SizedBox(height: 18),

            // ─── FAILED ITEMS ALERT (IF ANY) ─────────────────
            if (_failedCount > 0) ...[
              StaggeredFadeSlide(
                delayMs: 200,
                child: _buildFailedItemsAlert(isDark),
              ),
              const SizedBox(height: 18),
            ],

            // ─── QUICK CONTROLS ──────────────────────────────
            StaggeredFadeSlide(
              delayMs: 240,
              child: _buildQuickControls(isConfigured, isMonitoring, isPaused),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark, bool isConfigured, bool isMonitoring, bool isPaused) {
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (!isConfigured) {
      statusColor = ValtSkyTheme.warning;
      statusTitle = 'Setup Required';
      statusSubtitle = 'Connect your Telegram bot to enable cloud backup';
      statusIcon = Icons.settings_outlined;
    } else if (!isMonitoring) {
      statusColor = isDark ? Colors.white : Colors.black;
      statusTitle = 'Monitoring Stopped';
      statusSubtitle = 'Tap Start to automatically backup new photos & videos';
      statusIcon = Icons.pause_circle_outline_rounded;
    } else if (isPaused) {
      statusColor = ValtSkyTheme.warning;
      statusTitle = 'Uploads Paused';
      statusSubtitle = 'Detecting new media, but queue is held';
      statusIcon = Icons.pause_rounded;
    } else {
      statusColor = ValtSkyTheme.success;
      statusTitle = 'Live Cloud Sync';
      statusSubtitle = Prefs.channelName.isNotEmpty 
          ? 'Syncing silently to ${Prefs.channelName}'
          : 'Monitoring camera roll in background';
      statusIcon = Icons.cloud_done_rounded;
    }

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                statusColor.withValues(alpha: 0.12),
                const Color(0xFF18181B),
              ]
            : [
                statusColor.withValues(alpha: 0.08),
                Colors.white,
              ],
      ),
      border: Border.all(
        color: statusColor.withValues(alpha: isDark ? 0.35 : 0.25),
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: isMonitoring && !isPaused
                          ? [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.3 * _pulseController.value),
                                blurRadius: 16 * _pulseController.value,
                                spreadRadius: 4 * _pulseController.value,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 28),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            statusTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isMonitoring)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isPaused ? 'PAUSED' : 'LIVE',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isConfigured) ...[
            const SizedBox(height: 16),
            TactilePress(
              onTap: widget.onNavigateToSettings,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_rounded, size: 18, color: isDark ? Colors.black : Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'CONNECT TELEGRAM BOT',
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
          ] else ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.send_rounded, size: 14, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Prefs.botName.isNotEmpty ? '@${Prefs.botName}' : 'Telegram Bot',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text('→', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Icon(Icons.campaign_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    Prefs.channelName.isNotEmpty ? Prefs.channelName : 'Private Channel',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
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
          count: '$_totalCount',
          icon: Icons.photo_library_rounded,
          color: isDark ? Colors.white : Colors.black,
          isDark: isDark,
          onTap: () => widget.onNavigateToActivity?.call('ALL'),
        ),
        _buildMetricTile(
          title: 'SYNCED',
          count: '$_uploadedCount',
          icon: Icons.cloud_done_rounded,
          color: ValtSkyTheme.success,
          isDark: isDark,
          onTap: () => widget.onNavigateToActivity?.call('SYNCED'),
        ),
        _buildMetricTile(
          title: 'IN QUEUE',
          count: '$_pendingCount',
          icon: Icons.hourglass_top_rounded,
          color: ValtSkyTheme.warning,
          isDark: isDark,
          onTap: () => widget.onNavigateToActivity?.call('QUEUED'),
        ),
        _buildMetricTile(
          title: 'FAILED',
          count: '$_failedCount',
          icon: Icons.error_outline_rounded,
          color: _failedCount > 0 ? ValtSkyTheme.error : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
          isDark: isDark,
          onTap: () => widget.onNavigateToActivity?.call('FAILED'),
        ),
      ],
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

  Widget _buildProgressSection(double progress, bool isDark, bool isMonitoring, bool isPaused) {
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
                  if (isMonitoring && !isPaused) ...[
                    const SizedBox(width: 10),
                    PassiveTransferWave(
                      color: isDark ? Colors.white : Colors.black,
                      isLive: true,
                    ),
                  ],
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
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animVal, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: animVal,
                  minHeight: 10,
                  backgroundColor: isDark 
                      ? Colors.white.withValues(alpha: 0.06) 
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : Colors.black),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_uploadedCount of $_totalCount files backed up',
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
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.retryAllFailed();
                await refreshStats();
              },
              child: const Text('Retry All', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<MediaItem>>(
          stream: DatabaseHelper.instance.getFailedItemsStream(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const SizedBox();
            return Column(
              children: items.take(2).map((item) => FailedItemCard(
                item: item,
                onRetry: refreshStats,
              )).toList(),
            );
          },
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
                  onPressed: _isRefreshing ? null : _handleScan,
                  icon: _isRefreshing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Scan Gallery',
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
}
