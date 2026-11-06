import 'package:flutter/material.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';

class DashboardHeroCard extends StatefulWidget {
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final int uploadedCount;
  final int totalCount;
  final double progress;
  final VoidCallback onToggleMonitoring;

  const DashboardHeroCard({
    super.key,
    required this.isConfigured,
    required this.isMonitoring,
    required this.isPaused,
    required this.uploadedCount,
    required this.totalCount,
    required this.progress,
    required this.onToggleMonitoring,
  });

  @override
  State<DashboardHeroCard> createState() => _DashboardHeroCardState();
}

class _DashboardHeroCardState extends State<DashboardHeroCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engineStatus = SyncEngine.engineStatusNotifier.value;

    final isActive = widget.isMonitoring && !widget.isPaused && engineStatus == SyncEngineStatus.active;
    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isActive
        ? const Color(0xFF06B6D4).withAlpha(100)
        : (widget.isMonitoring
            ? ValtSkyTheme.warning.withAlpha(80)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)));

    final percentInt = (widget.progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isActive ? const Color(0xFF06B6D4).withAlpha(30) : Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status badge & mode badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isActive)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withValues(alpha: _pulseAnimation.value),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withAlpha(150),
                              blurRadius: 8 * _pulseAnimation.value,
                              spreadRadius: 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isPaused
                            ? ValtSkyTheme.warning
                            : (widget.isMonitoring ? const Color(0xFF0EA5E9) : Colors.grey),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isMonitoring
                        ? (widget.isPaused ? 'UPLOADS PAUSED' : 'MONITORING ACTIVE')
                        : 'STANDBY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: widget.isMonitoring
                          ? (widget.isPaused ? ValtSkyTheme.warning : const Color(0xFF10B981))
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: isDark ? const Color(0xFF06B6D4) : Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(
                      '2x MTProto Turbo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Middle Row: Speed & Progress Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.uploadedCount} of ${widget.totalCount} files',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: SyncEngine.uploadSpeedNotifier,
                    builder: (context, currentSpeed, _) {
                      if (currentSpeed.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF06B6D4).withAlpha(80)),
                          ),
                          child: Text(
                            currentSpeed,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF06B6D4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Text(
                    '$percentInt%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: widget.progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isPaused
                    ? ValtSkyTheme.warning
                    : (isActive ? const Color(0xFF06B6D4) : const Color(0xFF10B981)),
              ),
            ),
          ),

          ValueListenableBuilder<String>(
            valueListenable: SyncEngine.currentItemNotifier,
            builder: (context, activeFile, _) {
              if (activeFile.isEmpty || !isActive) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        activeFile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // Master Control Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onToggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: !widget.isConfigured
                    ? ValtSkyTheme.telegramBlue
                    : (widget.isMonitoring ? ValtSkyTheme.error : const Color(0xFF10B981)),
                foregroundColor: Colors.white,
                elevation: widget.isMonitoring ? 4 : 2,
                shadowColor: !widget.isConfigured
                    ? ValtSkyTheme.telegramBlue.withAlpha(120)
                    : (widget.isMonitoring
                        ? ValtSkyTheme.error.withAlpha(120)
                        : const Color(0xFF10B981).withAlpha(100)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !widget.isConfigured
                        ? Icons.tune_rounded
                        : (widget.isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !widget.isConfigured
                        ? 'CONFIGURE TELEGRAM BACKUP'
                        : (widget.isMonitoring ? 'STOP MONITORING' : 'START MONITORING'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
