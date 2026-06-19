import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/prefs.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';
import '../services/background_service.dart';
import '../services/telegram_api.dart';
import '../util/media_scanner.dart';
import '../main.dart';
import '../util/theme.dart';
import 'widgets/failed_item_card.dart';
import 'widgets/glass_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _botTokenController = TextEditingController();
  final TextEditingController _channelIdController = TextEditingController();

  bool _isConfigured = Prefs.isConfigured();
  bool _isMonitoring = Prefs.monitoringEnabled;
  bool _uploadPaused = Prefs.uploadPaused;
  bool _isValidating = false;
  bool _isRefreshing = false;

  int _totalCount = 0;
  int _uploadedCount = 0;
  int _pendingCount = 0;
  int _failedCount = 0;
  bool _showToken = false;

  @override
  void initState() {
    super.initState();
    _botTokenController.text = Prefs.botToken;
    _channelIdController.text = Prefs.channelId;
    _updateStats();
  }

  Future<void> _updateStats() async {
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
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      await MediaScanner.scanForNewMedia();
      await _updateStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gallery scan complete'),
          duration: Duration(seconds: 1),
        ));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _onValidate() async {
    setState(() => _isValidating = true);
    final botName = await TelegramApi.getBotInfo(_botTokenController.text);
    if (botName != null) {
      final channelName = await TelegramApi.getChannelInfo(_botTokenController.text, _channelIdController.text);
      if (channelName != null) {
        Prefs.botToken = _botTokenController.text;
        Prefs.channelId = _channelIdController.text;
        Prefs.botName = botName;
        Prefs.channelName = channelName;
        if (mounted) {
          setState(() => _isConfigured = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: ValtSkyTheme.success,
            content: Text('Validated: \$botName in \$channelName'),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: ValtSkyTheme.error,
            content: Text('Invalid Channel ID or Bot lacks permission'),
          ));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: ValtSkyTheme.error,
          content: Text('Invalid Bot Token'),
        ));
      }
    }
    setState(() => _isValidating = false);
  }

  Future<void> _onToggleMonitoring() async {
    if (_isMonitoring) {
      await BackgroundService.stop();
      setState(() => _isMonitoring = false);
    } else {
      await BackgroundService.start();
      setState(() => _isMonitoring = true);
    }
    Prefs.monitoringEnabled = _isMonitoring;
  }

  void _onToggleUploadPause() {
    setState(() {
      _uploadPaused = !_uploadPaused;
      Prefs.uploadPaused = _uploadPaused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'ValtSky',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'Serif',
              ),
            ),
            const SizedBox(width: 12),
            if (_isMonitoring)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ValtSkyTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: ValtSkyTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: ValtSkyTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
          IconButton(
            icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildProgressCard(),
            const SizedBox(height: 20),
            if (_failedCount > 0) _buildFailedItemsSection(),
            const SizedBox(height: 20),
            _buildConfigCard(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: ValtSkyTheme.primaryAccent),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'ValtSky',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Setup Guide'),
            onTap: () {
              // TODO: Navigate to guide
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('TOTAL', _totalCount.toString(), ValtSkyTheme.primaryAccent),
        _buildStatCard('SYNCED', _uploadedCount.toString(), ValtSkyTheme.success),
        _buildStatCard('QUEUED', _pendingCount.toString(), ValtSkyTheme.warning),
        _buildStatCard('FAILED', _failedCount.toString(), ValtSkyTheme.error),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = _totalCount == 0 ? 0.0 : _uploadedCount / _totalCount;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Overall Progress',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: ValtSkyTheme.primaryAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: const AlwaysStoppedAnimation<Color>(ValtSkyTheme.primaryAccent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isMonitoring ? 'Sync engine is active' : 'Sync is paused',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            if (Prefs.lastSyncedTs > 0)
              Text(
                'Last synced: ${DateTime.fromMillisecondsSinceEpoch(Prefs.lastSyncedTs).toString().split('.').first}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildInputLabel('Bot Token'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _botTokenController,
              hint: '7123456789:AAF...',
              isPassword: !_showToken,
              enabled: !_isMonitoring,
              suffix: TextButton(
                onPressed: _isMonitoring ? null : () => setState(() => _showToken = !_showToken),
                child: Text(_showToken ? 'HIDE' : 'SHOW', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            Text(Prefs.botName.isNotEmpty ? 'Connected as: ${Prefs.botName}' : 'Not connected', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            _buildInputLabel('Channel ID'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _channelIdController,
              hint: '-100123456789',
              enabled: !_isMonitoring,
              suffix: TextButton(
                onPressed: (_isValidating || _isMonitoring) ? null : _onValidate,
                child: _isValidating 
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('VALIDATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            if (Prefs.channelName.isNotEmpty)
               Text('Target: ${Prefs.channelName}', style: const TextStyle(fontSize: 11, color: Colors.grey))
            else
               const Text('Not connected', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 20),
            _buildInputLabel('Upload Quality'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Original (Lossless)', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Upload as document to prevent compression', style: TextStyle(fontSize: 11)),
              value: Prefs.useOriginalQuality,
              onChanged: _isMonitoring ? null : (val) => setState(() => Prefs.useOriginalQuality = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey));
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, bool isPassword = false, bool enabled = true, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.grey.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              enabled: enabled,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              style: TextStyle(fontSize: 14, color: enabled ? null : Colors.grey),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _buildFailedItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Failed Uploads', style: TextStyle(fontWeight: FontWeight.bold, color: ValtSkyTheme.error)),
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.retryAllFailed();
                _updateStats();
              },
              child: const Text('Retry All', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        StreamBuilder<List<MediaItem>>(
          stream: DatabaseHelper.instance.getFailedItemsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final items = snapshot.data!;
            if (items.isEmpty) return const SizedBox();
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.take(3).length,
              itemBuilder: (context, index) => FailedItemCard(item: items[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _isMonitoring ? _onToggleUploadPause : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _uploadPaused ? ValtSkyTheme.success : ValtSkyTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1),
              disabledForegroundColor: Colors.grey,
            ),
            child: Text(
              _uploadPaused ? 'CONTINUE UPLOADING' : 'STOP UPLOADING',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _isConfigured ? _onToggleMonitoring : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMonitoring ? ValtSkyTheme.error : ValtSkyTheme.primaryAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(
              _isMonitoring ? 'STOP MONITORING' : 'START MONITORING',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Deep Reset?'),
                content: const Text('This will wipe all sync history and re-upload everything. This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                  TextButton(
                    onPressed: () async {
                      await DatabaseHelper.instance.deleteAll();
                      await Prefs.clearAllSyncState();
                      if (mounted) {
                        Navigator.pop(context);
                        _updateStats();
                      }
                    },
                    child: const Text('RESET', style: TextStyle(color: ValtSkyTheme.error)),
                  ),
                ],
              ),
            );
          },
          child: const Text('RESET ALL SYNC HISTORY', style: TextStyle(color: ValtSkyTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
