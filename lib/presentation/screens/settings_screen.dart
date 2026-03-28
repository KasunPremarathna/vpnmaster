import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/payload_config.dart';
import '../../providers/config_provider.dart';
import '../../providers/log_provider.dart';
import '../../core/theme/app_theme.dart';
import 'payload_builder_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _dns1, _dns2;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<ConfigProvider>().appConfig;
    _dns1 = TextEditingController(text: cfg.dns1);
    _dns2 = TextEditingController(text: cfg.dns2);
  }

  @override
  void dispose() {
    _dns1.dispose();
    _dns2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final theme = context.watch<ThemeProvider>();
    final cfg = config.appConfig;
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Connection', colors),
          _toggle(
            'Kill Switch',
            'Block internet when VPN drops',
            Icons.security_rounded,
            cfg.killSwitch,
            (v) => config.saveAppConfig(AppConfig(
              killSwitch: v,
              splitTunneling: cfg.splitTunneling,
              excludedApps: cfg.excludedApps,
              autoReconnect: cfg.autoReconnect,
              autoStart: cfg.autoStart,
              dns1: cfg.dns1,
              dns2: cfg.dns2,
              darkMode: cfg.darkMode,
            )),
          ),
          _toggle(
            'Auto Reconnect',
            'Reconnect automatically on failure',
            Icons.refresh_rounded,
            cfg.autoReconnect,
            (v) => config.saveAppConfig(AppConfig(
              killSwitch: cfg.killSwitch,
              splitTunneling: cfg.splitTunneling,
              excludedApps: cfg.excludedApps,
              autoReconnect: v,
              autoStart: cfg.autoStart,
              dns1: cfg.dns1,
              dns2: cfg.dns2,
              darkMode: cfg.darkMode,
            )),
          ),
          _toggle(
            'Auto Start on Boot',
            'Start VPN when device boots',
            Icons.power_settings_new_rounded,
            cfg.autoStart,
            (v) => config.saveAppConfig(AppConfig(
              killSwitch: cfg.killSwitch,
              splitTunneling: cfg.splitTunneling,
              excludedApps: cfg.excludedApps,
              autoReconnect: cfg.autoReconnect,
              autoStart: v,
              dns1: cfg.dns1,
              dns2: cfg.dns2,
              darkMode: cfg.darkMode,
            )),
          ),
          const SizedBox(height: 8),
          _sectionHeader('Split Tunneling', colors),
          _toggle(
            'Split Tunneling',
            'Route only selected apps through VPN',
            Icons.call_split_rounded,
            cfg.splitTunneling,
            (v) => config.saveAppConfig(AppConfig(
              killSwitch: cfg.killSwitch,
              splitTunneling: v,
              excludedApps: cfg.excludedApps,
              autoReconnect: cfg.autoReconnect,
              autoStart: cfg.autoStart,
              dns1: cfg.dns1,
              dns2: cfg.dns2,
              darkMode: cfg.darkMode,
            )),
          ),
          if (cfg.splitTunneling)
            ListTile(
              leading: Icon(Icons.apps_rounded, color: colors.accent),
              title: const Text('Excluded Apps'),
              subtitle: Text('${cfg.excludedApps.length} apps excluded'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('App selector requires device query')),
                );
              },
            ),
          const SizedBox(height: 8),
          _sectionHeader('DNS', colors),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dns1,
                    decoration: const InputDecoration(labelText: 'Primary DNS'),
                    onChanged: (_) => _saveDns(config, cfg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _dns2,
                    decoration:
                        const InputDecoration(labelText: 'Secondary DNS'),
                    onChanged: (_) => _saveDns(config, cfg),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionHeader('Payload Templates', colors),
          ListTile(
            leading: Icon(Icons.tune_rounded, color: colors.accent),
            title: const Text('Payload Builder'),
            subtitle: Text('${config.payloads.length} templates saved'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PayloadBuilderScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _sectionHeader('Appearance', colors),
          _toggle(
            'Dark Mode',
            'Switch between dark and light theme',
            Icons.dark_mode_rounded,
            theme.isDark,
            (_) => theme.toggle(),
          ),
          const SizedBox(height: 8),
          _sectionHeader('About', colors),
          ListTile(
            leading: Icon(Icons.privacy_tip_rounded, color: colors.accent),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/privacy'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: colors.accent),
            title: const Text('Version'),
            trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _saveDns(ConfigProvider config, AppConfig cfg) {
    config.saveAppConfig(AppConfig(
      killSwitch: cfg.killSwitch,
      splitTunneling: cfg.splitTunneling,
      excludedApps: cfg.excludedApps,
      autoReconnect: cfg.autoReconnect,
      autoStart: cfg.autoStart,
      dns1: _dns1.text,
      dns2: _dns2.text,
      darkMode: cfg.darkMode,
    ));
  }

  Widget _sectionHeader(String label, AppColors colors) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );

  Widget _toggle(String title, String subtitle, IconData icon, bool value,
          void Function(bool) onChanged) =>
      Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: SwitchListTile(
          secondary: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: onChanged,
        ),
      );
}
