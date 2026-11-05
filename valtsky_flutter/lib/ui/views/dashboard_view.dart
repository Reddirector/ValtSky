import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/dashboard_stats_grid.dart';
import '../widgets/dashboard_hero_card.dart';
import '../widgets/dashboard_control_deck.dart';
import '../widgets/dashboard_status_banner.dart';
import '../widgets/diagnostics_sheet.dart';
import '../widgets/failed_item_card.dart';
import '../widgets/media_slideshow_reel.dart';

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
  late final DashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DashboardViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Exposed method for external triggers (e.g. AppBar refresh button or tab switch)
  Future<void> refreshStats() async {
    await _viewModel.refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isConfigured = Prefs.isConfigured();
        final isMonitoring = Prefs.monitoringEnabled;
        final isPaused = Prefs.uploadPaused;

        return RefreshIndicator(
          onRefresh: _viewModel.refreshStats,
          color: const Color(0xFF06B6D4),
          backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Reactive Status & Alert Banner (Offline, Flood Wait, Auth Expired)
                DashboardStatusBanner(
                  onNavigateToSettings: widget.onNavigateToSettings,
                  onCheckNetwork: () async {
                    final online = await SyncEngine.instance.checkNetworkAndResume();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: online ? ValtSkyTheme.success : ValtSkyTheme.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: Text(online ? 'Connection restored' : 'No internet connection detected'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),

                // 2. Metrics Grid (Total, Synced, In-Queue, Failed)
                DashboardStatsGrid(
                  totalCount: _viewModel.totalCount,
                  uploadedCount: _viewModel.uploadedCount,
                  pendingCount: _viewModel.pendingCount,
                  failedCount: _viewModel.failedCount,
                  onNavigateToActivity: (filter) => widget.onNavigateToActivity?.call(filter),
                ),

                const SizedBox(height: 16),

                // 3. Master Backup Hero Card (Status, Live Speed, Smooth Progress & Big Action Button)
                DashboardHeroCard(
                  isConfigured: isConfigured,
                  isMonitoring: isMonitoring,
                  isPaused: isPaused,
                  uploadedCount: _viewModel.uploadedCount,
                  totalCount: _viewModel.totalCount,
                  progress: _viewModel.progress,
                  onToggleMonitoring: () => _viewModel.toggleMonitoring(
                    context,
                    onNavigateToSettings: widget.onNavigateToSettings,
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Quick Control Deck (Pause, Scan Gallery, Restart Sockets, Diagnostics)
                DashboardControlDeck(
                  isConfigured: isConfigured,
                  isMonitoring: isMonitoring,
                  isPaused: isPaused,
                  isScanning: _viewModel.isScanning,
                  isRestarting: _viewModel.isRestarting,
                  onTogglePause: _viewModel.togglePauseUpload,
                  onScanGallery: () => _viewModel.handleScanGallery(context),
                  onRestartEngine: () => _viewModel.handleRestartEngine(context),
                  onShowDiagnostics: () => DiagnosticsSheet.show(
                    context,
                    onRestartEngine: () => _viewModel.handleRestartEngine(context),
                  ),
                ),

                // 5. Failed Items Resolution Section
                if (_viewModel.failedCount > 0 && _viewModel.cachedFailedItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildFailedItemsAlert(isDark),
                ],

                const SizedBox(height: 20),

                // 6. Recent Captures Slideshow Reel
                GestureDetector(
                  onTap: () => widget.onNavigateToActivity?.call('ALL'),
                  child: MediaSlideshowReel(
                    onDataChanged: _viewModel.refreshStats,
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailedItemsAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ValtSkyTheme.error.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ValtSkyTheme.error.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ValtSkyTheme.error.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: ValtSkyTheme.error, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_viewModel.failedCount} Failed Uploads Need Attention',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateToActivity?.call('FAILED'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('View All', style: TextStyle(color: ValtSkyTheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in _viewModel.cachedFailedItems) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FailedItemCard(
                item: item,
                onRetry: _viewModel.refreshStats,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
