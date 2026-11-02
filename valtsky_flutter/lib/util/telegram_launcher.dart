import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/prefs.dart';
import '../util/theme.dart';

/// Helper to launch the user's Telegram Channel across Android, iOS, Desktop, and Web.
class TelegramLauncher {
  static String getChannelUrl() {
    final rawId = Prefs.channelId.trim();
    final rawName = Prefs.channelName.trim();
    final botName = Prefs.botName.trim();

    // 1. If channelId is a public username like @mychannel or mychannel (not starting with -)
    if (rawId.isNotEmpty && !rawId.startsWith('-') && !RegExp(r'^\d+$').hasMatch(rawId)) {
      final username = rawId.startsWith('@') ? rawId.substring(1) : rawId;
      return 'https://t.me/$username';
    }

    // 2. If channelName is a public username
    if (rawName.startsWith('@')) {
      return 'https://t.me/${rawName.substring(1)}';
    }

    // 3. If channelId is a standard private supergroup/channel ID starting with -100
    if (rawId.startsWith('-100')) {
      final cleanId = rawId.replaceFirst('-100', '');
      return 'https://t.me/c/$cleanId';
    }

    // 4. Fallback to bot if configured
    if (botName.isNotEmpty) {
      final cleanBot = botName.startsWith('@') ? botName.substring(1) : botName;
      return 'https://t.me/$cleanBot';
    }

    // 5. Default Telegram Web
    return 'https://web.telegram.org';
  }

  static Future<void> openChannel(BuildContext context) async {
    final channelUrl = getChannelUrl();
    final channelName = Prefs.channelName.isNotEmpty ? Prefs.channelName : 'Telegram Channel';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ValtSkyTheme.success,
        content: Row(
          children: [
            const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Opening $channelName in Telegram...')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final uri = Uri.parse(channelUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      // Fallback to in-app / browser
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      // If external intent fails, try platform default web view
      try {
        await launchUrl(Uri.parse(channelUrl), mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: ValtSkyTheme.error,
              content: Text('Could not open Telegram: $channelUrl'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Launch official Telegram client or Telegram Web so user can view login notifications
  static Future<void> openTelegramApp() async {
    final nativeUri = Uri.parse('tg://');
    final webUri = Uri.parse('https://web.telegram.org');
    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }
}
