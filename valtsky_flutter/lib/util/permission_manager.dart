import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import '../data/prefs.dart';
import '../util/media_scanner.dart';
import '../util/theme.dart';
import '../ui/widgets/animated_stagger.dart';

class PermissionManager {
  static bool get _isTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Checks if any core permission (Gallery, Notifications, Location) is missing
  static Future<bool> hasMissingPermissions() async {
    if (kIsWeb || _isTest) return false;

    try {
      // 1. Gallery check
      bool hasGallery = false;
      if (Platform.isAndroid) {
        final photosStatus = await Permission.photos.status;
        final storageStatus = await Permission.storage.status;
        hasGallery = photosStatus.isGranted || storageStatus.isGranted;
      } else {
        hasGallery = await Permission.photos.isGranted;
      }

      // 2. Notifications check
      final notificationStatus = await Permission.notification.status;

      // 3. Location check (media location on Android 10+, fallback to location)
      final bool hasLocation;
      if (!kIsWeb && Platform.isAndroid) {
        hasLocation = (await Permission.accessMediaLocation.status).isGranted ||
            (await Permission.location.status).isGranted;
      } else {
        hasLocation = (await Permission.location.status).isGranted;
      }

      return !hasGallery || !notificationStatus.isGranted || !hasLocation;
    } catch (e) {
      debugPrint('[PermissionManager] Status check error: $e');
      return false;
    }
  }

  /// Request all required permissions sequentially for Android & mobile
  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{
      'gallery': false,
      'notification': false,
      'location': false,
      'battery': false,
    };

    if (kIsWeb || _isTest) {
      Prefs.permissionsRequested = true;
      return {'gallery': true, 'notification': true, 'location': true, 'battery': true};
    }

    try {
      // 1. Request Gallery / Media Permissions
      debugPrint('[PermissionManager] Requesting Gallery & Media permissions...');
      final mediaPermissions = <Permission>[
        Permission.photos,
        Permission.videos,
        Permission.storage,
        Permission.accessMediaLocation,
      ];
      final mediaStatuses = await mediaPermissions.request();
      final galleryGranted = (mediaStatuses[Permission.photos]?.isGranted ?? false) ||
          (mediaStatuses[Permission.storage]?.isGranted ?? false) ||
          (mediaStatuses[Permission.videos]?.isGranted ?? false);
      results['gallery'] = galleryGranted;

      // Also invoke PhotoManager's internal extend request
      try {
        final pmState = await PhotoManager.requestPermissionExtend();
        if (pmState.isAuth) {
          results['gallery'] = true;
        }
      } catch (e) {
        debugPrint('[PermissionManager] PhotoManager extend error: $e');
      }

      // 2. Request Notification Permission
      debugPrint('[PermissionManager] Requesting Notification permission...');
      final notifStatus = await Permission.notification.request();
      results['notification'] = notifStatus.isGranted;

      // 3. Request Location Permission (EXIF & Media Location preservation)
      debugPrint('[PermissionManager] Requesting Location permission...');
      final mediaLocStatus = await Permission.accessMediaLocation.request();
      final locStatus = await Permission.location.request();
      results['location'] = mediaLocStatus.isGranted || locStatus.isGranted;

      // 4. Request Battery Optimization Exemption (Background Engine survival)
      if (Platform.isAndroid) {
        debugPrint('[PermissionManager] Checking battery optimization exemption...');
        final isBatteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
        if (!isBatteryIgnored) {
          final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
          results['battery'] = batteryStatus.isGranted;
        } else {
          results['battery'] = true;
        }
      }

      Prefs.permissionsRequested = true;

      // Kick off background scanner if gallery was granted
      if (results['gallery'] == true) {
        MediaScanner.scanForNewMedia().catchError((e) {
          debugPrint('[PermissionManager] Initial scan error: $e');
          return 0;
        });
      }
    } catch (e) {
      debugPrint('[PermissionManager] Error requesting permissions: $e');
    }

    return results;
  }

  /// Show the first-time permission onboarding popup
  static Future<void> showPermissionOnboardingModal(
    BuildContext context, {
    VoidCallback? onComplete,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);
    final primaryColor = ValtSkyTheme.primary(isDark);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header Icon & Title
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(Icons.security_rounded, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permissions Required',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ValtSky needs device access for zero-loss cloud backup',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Permission Items List
                _buildPermissionItem(
                  icon: Icons.photo_library_rounded,
                  title: 'Gallery (Photos & Videos)',
                  subtitle: 'Scans & backs up new camera media bit-for-bit to Telegram.',
                  isDark: isDark,
                  borderColor: borderColor,
                  trackBg: trackBg,
                ),
                const SizedBox(height: 10),
                _buildPermissionItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'Notifications',
                  subtitle: 'Displays live upload progress & transfer speeds in status bar.',
                  isDark: isDark,
                  borderColor: borderColor,
                  trackBg: trackBg,
                ),
                const SizedBox(height: 10),
                _buildPermissionItem(
                  icon: Icons.location_on_rounded,
                  title: 'Location Access',
                  subtitle: 'Preserves camera EXIF GPS tags & geotagged photo metadata.',
                  isDark: isDark,
                  borderColor: borderColor,
                  trackBg: trackBg,
                ),
                const SizedBox(height: 10),
                _buildPermissionItem(
                  icon: Icons.bolt_rounded,
                  title: 'Background Battery Exemption',
                  subtitle: 'Prevents Android from killing automated sync in the background.',
                  isDark: isDark,
                  borderColor: borderColor,
                  trackBg: trackBg,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                TactilePress(
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await requestAllPermissions();
                    onComplete?.call();
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ALLOW ALL PERMISSIONS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Prefs.permissionsRequested = true;
                    Navigator.of(ctx).pop();
                    onComplete?.call();
                  },
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  static Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color borderColor,
    required Color trackBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ValtSkyTheme.primary(isDark).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: ValtSkyTheme.primary(isDark), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
