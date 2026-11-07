import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/vault_storage_card.dart';
import '../widgets/vault_metric_deck.dart';
import '../widgets/dashboard_control_deck.dart';
import '../widgets/dashboard_status_banner.dart';
import '../widgets/diagnostics_sheet.dart';
import '../widgets/failed_item_card.dart';

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

class DashboardViewState extends State<DashboardView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final DashboardViewModel _viewModel;
  bool _isRetrying = false;

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
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isConfigured = Prefs.isConfigured();
        final isMonitoring = Prefs.monitoringEnabled;
        final isPaused = Prefs.uploadPaused;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            final horizontalPadding = isNarrow ? 12.0 : 16.0;

            return RefreshIndicator(
              onRefresh: _viewModel.refreshStats,
              color: secondaryColor,
              backgroundColor: cardBg,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                // 1. Status & Warning Banner (Offline / Rate Limit)
                ValueListenableBuilder<SyncEngineStatus>(
                  valueListenable: SyncEngine.engineStatusNotifier,
                  builder: (context, _, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: SyncEngine.rateLimitSecondsRemainingNotifier,
                      builder: (context, _, _) {
                        return DashboardStatusBanner(
                          onNavigateToSettings: widget.onNavigateToSettings,
                          onCheckNetwork: () => SyncEngine.hasInternetConnection(),
                        );
                      },
                    );
                  },
                ),

                // 2. Monolithic Storage Vault Card (Progress, Master Switch)
                VaultStorageCard(
                  isConfigured: isConfigured,
                  isMonitoring: isMonitoring,
                  isPaused: isPaused,
                  uploadedCount: _viewModel.uploadedCount,
                  totalCount: _viewModel.totalCount,
                  progress: _viewModel.progress,
                  onToggleMonitoring: () {
                    if (!isConfigured) {
                      widget.onNavigateToSettings();
                    } else {
                      _viewModel.toggleMonitoring(
                        context,
                        onNavigateToSettings: widget.onNavigateToSettings,
                      );
                    }
                  },
                ),

                const SizedBox(height: 16),

                // 4. Precision Instrumentation Metrics Deck
                VaultMetricDeck(
                  totalCount: _viewModel.totalCount,
                  uploadedCount: _viewModel.uploadedCount,
                  pendingCount: _viewModel.pendingCount,
                  failedCount: _viewModel.failedCount,
                  onNavigateToActivity: (filter) => widget.onNavigateToActivity?.call(filter),
                ),

                const SizedBox(height: 16),

                // 5. Tactical Quick Action Controls
                DashboardControlDeck(
                  isConfigured: isConfigured,
                  isMonitoring: isMonitoring,
                  isPaused: isPaused,
                  isScanning: _viewModel.isScanning,
                  onTogglePause: _viewModel.togglePauseUpload,
                  onScanGallery: () => _viewModel.handleScanGallery(context),
                  onStopProcess: () => _viewModel.handleStopProcess(context),
                  onShowDiagnostics: () {
                    DiagnosticsSheet.show(
                      context,
                      onRestartEngine: () => _viewModel.handleRestartEngine(context),
                    );
                  },
                ),

                // 6. Failed Items Alert (Conditional)
                if (_viewModel.failedCount > 0 && _viewModel.cachedFailedItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildFailedItemsAlert(isDark),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  },
);
  }

  Widget _buildFailedItemsAlert(bool isDark) {
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.error.withAlpha(120);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: ValtSkyTheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_viewModel.failedCount} Failed Uploads',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ValtSkyTheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _isRetrying
                        ? null
                        : () async {
                            setState(() => _isRetrying = true);
                            try {
                              final count = await DatabaseHelper.instance.retryAllFailed();
                              await _viewModel.refreshStats();
                              if (!Prefs.uploadPaused) {
                                SyncEngine().startSync();
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$count failed items queued for retry'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: ValtSkyTheme.success,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isRetrying = false);
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: _isRetrying
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ValtSkyTheme.error),
                          )
                        : const Text('Retry All', style: TextStyle(color: ValtSkyTheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
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
