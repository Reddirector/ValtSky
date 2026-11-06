import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

class DashboardStatusBanner extends StatelessWidget {
  final VoidCallback onNavigateToSettings;
  final VoidCallback onCheckNetwork;

  const DashboardStatusBanner({
    super.key,
    required this.onNavigateToSettings,
    required this.onCheckNetwork,
  });

  @override
  Widget build(BuildContext context) {
    final status = SyncEngine.engineStatusNotifier.value;
    final message = SyncEngine.engineStatusMessageNotifier.value;
    final rateLimitRemaining = SyncEngine.rateLimitSecondsRemainingNotifier.value;

    if (status == SyncEngineStatus.idle || status == SyncEngineStatus.active || status == SyncEngineStatus.paused) {
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
          onPressed: onCheckNetwork,
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
          onPressed: onNavigateToSettings,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: text),
          const SizedBox(width: 12),
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
        ],
      ),
    );
  }
}
