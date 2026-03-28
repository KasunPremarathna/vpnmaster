import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../services/config_service.dart';
import '../../core/theme/app_theme.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _svc = ConfigService();
  bool _usePassword = false;
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Config Manager')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Stats card
          _StatsCard(
            profileCount: config.profiles.length,
            payloadCount: config.payloads.length,
          ),
          const SizedBox(height: 24),

          // Password protection
          _sectionLabel('Encryption', colors),
          SwitchListTile(
            title: const Text('Password Protect'),
            subtitle: const Text('Encrypt config with AES-256'),
            value: _usePassword,
            onChanged: (v) => setState(() => _usePassword = v),
          ),
          if (_usePassword)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Encryption Password',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Actions
          _sectionLabel('Actions', colors),
          _actionTile(
            context,
            icon: Icons.file_upload_rounded,
            color: colors.accentGreen,
            title: 'Export Config',
            subtitle: 'Save all profiles to a .vpm file',
            onTap: () => _export(config),
          ),
          _actionTile(
            context,
            icon: Icons.file_download_rounded,
            color: colors.accent,
            title: 'Import Config',
            subtitle: 'Load profiles from a .vpm or .ehi file',
            onTap: () => _import(config),
          ),
          _actionTile(
            context,
            icon: Icons.share_rounded,
            color: colors.accentOrange,
            title: 'Share Config',
            subtitle: 'Share via system share sheet',
            onTap: () => _share(config),
          ),
          const SizedBox(height: 20),

          // Danger zone
          _sectionLabel('Danger Zone', colors),
          _actionTile(
            context,
            icon: Icons.delete_forever_rounded,
            color: colors.accentRed,
            title: 'Clear All Profiles',
            subtitle: 'Permanently delete all saved profiles',
            onTap: () => _confirmClearAll(context, config),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _export(ConfigProvider config) async {
    setState(() => _loading = true);
    try {
      await config.exportAll(_svc, password: _usePassword ? _passCtrl.text : null);
      if (mounted) _snack('Config exported successfully');
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import(ConfigProvider config) async {
    setState(() => _loading = true);
    try {
      await config.importAll(_svc, password: _usePassword ? _passCtrl.text : null);
      if (mounted) _snack('Config imported successfully');
    } catch (e) {
      if (mounted) _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share(ConfigProvider config) async {
    setState(() => _loading = true);
    try {
      final bundle = ExportBundle(
        profiles: config.profiles.toList(),
        appConfig: config.appConfig,
        payloads: config.payloads.toList(),
      );
      await _svc.shareConfig(bundle: bundle, password: _usePassword ? _passCtrl.text : null);
    } catch (e) {
      if (mounted) _snack('Share failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmClearAll(BuildContext context, ConfigProvider config) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Delete all profiles, payloads, and settings? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final p in config.profiles.toList()) {
        config.deleteProfile(p.id);
      }
      if (mounted) _snack('All profiles deleted');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _sectionLabel(String label, AppColors colors) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int profileCount;
  final int payloadCount;
  const _StatsCard({required this.profileCount, required this.payloadCount});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent.withValues(alpha: .2), colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(context, '$profileCount', 'Profiles', Icons.dns_rounded),
          Container(width: 1, height: 40, color: Colors.white24),
          _stat(context, '$payloadCount', 'Payloads', Icons.tune_rounded),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Column(
      children: [
        Icon(icon, color: colors.accent, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
