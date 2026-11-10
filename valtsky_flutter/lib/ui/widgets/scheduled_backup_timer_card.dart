import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/backup_scheduler_service.dart';
import '../../util/theme.dart';
import 'valtsky_components.dart';

/// Interactive Dashboard Card for setting up an automated alarm clock backup.
/// Users can configure a specific time of day for automatic gallery monitoring,
/// which automatically scans local media, populates the upload queue, stops discovery,
/// and uploads directly to the Telegram channel.
class ScheduledBackupTimerCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onDataChanged;

  const ScheduledBackupTimerCard({
    super.key,
    required this.isDark,
    this.onDataChanged,
  });

  @override
  State<ScheduledBackupTimerCard> createState() => _ScheduledBackupTimerCardState();
}

class _ScheduledBackupTimerCardState extends State<ScheduledBackupTimerCard> {
  static const Color alarmAmber = Color(0xFFF59E0B);
  static const Color alarmAmberGleam = Color(0xFFFBBF24);
  static const Color alarmBlue = Color(0xFF38BDF8);

  Future<void> _pickTime(BuildContext context, int initialHour, int initialMinute) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: widget.isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: alarmAmber,
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E24),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: alarmAmber,
                    onPrimary: Color(0xFF1E1E24),
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      await BackupSchedulerService.instance.setSchedule(picked.hour, picked.minute);
      if (!BackupSchedulerService.instance.state.isEnabled) {
        await BackupSchedulerService.instance.setEnabled(true);
      }
      if (!mounted) return;
      widget.onDataChanged?.call();
    }
  }

  void _applyPreset(int hour, int minute) async {
    await BackupSchedulerService.instance.setSchedule(hour, minute);
    if (!BackupSchedulerService.instance.state.isEnabled) {
      await BackupSchedulerService.instance.setEnabled(true);
    }
    if (!mounted) return;
    widget.onDataChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final mutedText = ValtSkyTheme.textSecondary(isDark);
    final primaryText = ValtSkyTheme.textPrimary(isDark);
    final amberText = isDark ? alarmAmber : const Color(0xFFB45309);

    return ValueListenableBuilder<ScheduledBackupState>(
      valueListenable: BackupSchedulerService.instance.stateNotifier,
      builder: (context, state, _) {
        final isEnabled = state.isEnabled;
        final isExecuting = state.isExecuting;
        final hasError = state.statusMessage.toLowerCase().contains('error');

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
            border: Border.all(
              color: isEnabled
                  ? alarmAmber.withValues(alpha: isDark ? 0.35 : 0.25)
                  : borderColor,
              width: 1.2,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: alarmAmber.withValues(alpha: isDark ? 0.08 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── HEADER: ICON, TITLE, TOGGLE SWITCH ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isEnabled
                            ? [alarmAmber, alarmAmberGleam]
                            : [
                                isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                                isDark ? const Color(0xFF18181B) : const Color(0xFFD4D4D8),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isEnabled
                          ? [
                              BoxShadow(
                                color: alarmAmber.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isEnabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                      color: isEnabled ? Colors.black87 : mutedText,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALARM CLOCK BACKUP',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyDisplay,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isEnabled ? amberText : mutedText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasError
                              ? state.statusMessage
                              : (isEnabled
                                  ? (isExecuting ? 'Running: Scanning & loading queue...' : 'Scheduled: ${state.countdownText}')
                                  : 'Set a daily auto-backup time'),
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyBody,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hasError
                                ? Colors.redAccent
                                : (isExecuting ? alarmBlue : mutedText),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Toggle daily scheduled backup',
                    toggled: isEnabled,
                    child: CupertinoSwitch(
                      value: isEnabled,
                      activeTrackColor: alarmAmber,
                      onChanged: (val) async {
                        await BackupSchedulerService.instance.setEnabled(val);
                        if (!mounted) return;
                        widget.onDataChanged?.call();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ─── DIGITAL CLOCK READOUT CONTAINER ─────────────────────────
              InkWell(
                onTap: () => _pickTime(context, state.hour, state.minute),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF18181B)
                        : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEnabled
                          ? alarmAmber.withValues(alpha: 0.20)
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                state.formattedTime.split(' ').first,
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                  color: isEnabled ? primaryText : mutedText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                state.formattedTime.split(' ').last,
                                style: TextStyle(
                                  fontFamily: ValtSkyTheme.fontFamilyDisplay,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isEnabled ? amberText : mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isEnabled ? amberText : mutedText).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: isEnabled ? amberText : mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to Edit',
                              style: TextStyle(
                                fontFamily: ValtSkyTheme.fontFamilyBody,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isEnabled ? amberText : mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── QUICK PRESET CHIPS ──────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetChip(
                      label: '🌙 2:00 AM (Night)',
                      isActive: state.hour == 2 && state.minute == 0,
                      onTap: () => _applyPreset(2, 0),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: '🌅 6:00 AM (Morning)',
                      isActive: state.hour == 6 && state.minute == 0,
                      onTap: () => _applyPreset(6, 0),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: '🛌 11:30 PM (Bedtime)',
                      isActive: state.hour == 23 && state.minute == 30,
                      onTap: () => _applyPreset(23, 30),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ─── ALARM WORKFLOW EXPLANATION & TEST TRIGGER ────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isEnabled ? alarmAmber : mutedText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'At the set time, ValtSky scans device media, loads all new items into the queue, and automatically uploads to Telegram.',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 11,
                          color: mutedText,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Test Alarm / Run Now Button
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  label: isExecuting ? 'Running Scheduled Backup...' : 'Test Alarm / Run Backup Now',
                  icon: isExecuting ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                  variant: PillButtonVariant.secondary,
                  isLoading: isExecuting,
                  onPressed: isExecuting
                      ? null
                      : () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Triggering automated alarm backup workflow...'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          await BackupSchedulerService.instance.executeBackupWorkflow();
                          if (!mounted) return;
                          widget.onDataChanged?.call();
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    final amberText = isDark ? alarmAmber : const Color(0xFFB45309);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
      child: Semantics(
        label: '$label preset',
        selected: isActive,
        button: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? alarmAmber.withValues(alpha: isDark ? 0.22 : 0.15)
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill),
            border: Border.all(
              color: isActive ? alarmAmber : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamilyDisplay,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? amberText : ValtSkyTheme.textPrimary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
