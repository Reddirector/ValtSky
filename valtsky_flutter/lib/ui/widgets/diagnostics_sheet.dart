import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

class DiagnosticsSheet extends StatefulWidget {
  final VoidCallback onRestartEngine;

  const DiagnosticsSheet({
    super.key,
    required this.onRestartEngine,
  });

  static void show(BuildContext context, {required VoidCallback onRestartEngine}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DiagnosticsSheet(onRestartEngine: onRestartEngine),
    );
  }

  @override
  State<DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<DiagnosticsSheet> {
  bool _isTestingNetwork = false;
  bool? _lastNetworkResult;

  Future<void> _checkNetwork() async {
    setState(() => _isTestingNetwork = true);
    final result = await SyncEngine.hasInternetConnection();
    if (mounted) {
      setState(() {
        _lastNetworkResult = result;
        _isTestingNetwork = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engineStatus = SyncEngine.engineStatusNotifier.value;
    final engineMessage = SyncEngine.engineStatusMessageNotifier.value;
    final speed = SyncEngine.uploadSpeedNotifier.value;
    final rateLimitRemaining = SyncEngine.rateLimitSecondsRemainingNotifier.value;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Engine Diagnostics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildRow('Engine Status', engineStatus.name.toUpperCase(), isDark, highlight: true),
                const Divider(height: 16),
                _buildRow('Status Message', engineMessage.isNotEmpty ? engineMessage : 'Running normally', isDark),
                const Divider(height: 16),
                _buildRow('Upload Speed', speed.isNotEmpty ? speed : '0.0 MB/s', isDark),
                const Divider(height: 16),
                _buildRow('Rate Limit Remaining', '${rateLimitRemaining}s', isDark),
                const Divider(height: 16),
                _buildRow('Worker Concurrency', '4x MTProto Parallel Streams', isDark),
                const Divider(height: 16),
                _buildRow('Database Mode', 'SQLite WAL (Write-Ahead Logging)', isDark),
                const Divider(height: 16),
                _buildRow('Chunk Transport', '128 KB Non-Blocking Stream Slices', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTestingNetwork ? null : _checkNetwork,
                  icon: _isTestingNetwork
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _lastNetworkResult == null
                              ? Icons.network_check_rounded
                              : (_lastNetworkResult! ? Icons.check_circle_rounded : Icons.error_rounded),
                          size: 16,
                          color: _lastNetworkResult == null
                              ? null
                              : (_lastNetworkResult! ? ValtSkyTheme.success : ValtSkyTheme.error),
                        ),
                  label: Text(_lastNetworkResult == null ? 'Ping Network' : (_lastNetworkResult! ? 'Online' : 'Offline')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRestartEngine();
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Restart Sockets'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? const Color(0xFF06B6D4)
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
