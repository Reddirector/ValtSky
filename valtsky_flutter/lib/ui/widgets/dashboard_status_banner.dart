import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

class DashboardStatusBanner extends StatefulWidget {
  final VoidCallback onNavigateToSettings;
  final VoidCallback onCheckNetwork;

  const DashboardStatusBanner({
    super.key,
    required this.onNavigateToSettings,
    required this.onCheckNetwork,
  });

  @override
  State<DashboardStatusBanner> createState() => _DashboardStatusBannerState();
}

class _DashboardStatusBannerState extends State<DashboardStatusBanner> {
  SyncEngineStatus? _dismissedStatus;

  @override
  Widget build(BuildContext context) {
    final status = SyncEngine.engineStatusNotifier.value;
    final message = SyncEngine.engineStatusMessageNotifier.value;
    final rateLimitRemaining = SyncEngine.rateLimitSecondsRemainingNotifier.value;

    // Reset dismissed state whenever status changes away from the previously dismissed status
    if (_dismissedStatus != null && status != _dismissedStatus) {
      _dismissedStatus = null;
    }

    if (status == SyncEngineStatus.idle ||
        status == SyncEngineStatus.active ||
        status == SyncEngineStatus.paused ||
        _dismissedStatus == status) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color border;
    Color text;
    IconData icon;
    Widget? action;

    switch (status) {
      case SyncEngineStatus.rateLimited:
        bg = ValtSkyTheme.warning.withAlpha(20);
        border = ValtSkyTheme.warning.withAlpha(120);
        text = ValtSkyTheme.warning;
        icon = Icons.timer_outlined;
        action = Text(
          '${rateLimitRemaining}s remaining',
          style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 12),
        );
        break;

      case SyncEngineStatus.offline:
        bg = Colors.amber.withAlpha(20);
        border = Colors.amber.withAlpha(120);
        text = Colors.amber.shade400;
        icon = Icons.wifi_off_rounded;
        action = TextButton.icon(
          onPressed: widget.onCheckNetwork,
          icon: Icon(Icons.refresh_rounded, size: 14, color: text),
          label: Text('Retry', style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12)),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        );
        break;

      case SyncEngineStatus.sessionExpired:
        bg = ValtSkyTheme.error.withAlpha(20);
        border = ValtSkyTheme.error.withAlpha(120);
        text = ValtSkyTheme.error;
        icon = Icons.lock_clock_rounded;
        action = ElevatedButton(
          onPressed: widget.onNavigateToSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: ValtSkyTheme.error,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );
        break;

      case SyncEngineStatus.restarting:
        final restartColor = ValtSkyTheme.secondary(isDark);
        bg = restartColor.withAlpha(20);
        border = restartColor.withAlpha(120);
        text = restartColor;
        icon = Icons.autorenew_rounded;
        break;

      default:
        bg = ValtSkyTheme.tertiaryCard(isDark);
        border = ValtSkyTheme.tertiaryBorder(isDark);
        text = isDark ? Colors.white : const Color(0xFF0F172A);
        icon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.isNotEmpty ? message : status.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action,
          ],
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: text.withAlpha(160),
            tooltip: 'Dismiss alert',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              setState(() {
                _dismissedStatus = status;
              });
            },
          ),
        ],
      ),
    );
  }
}
