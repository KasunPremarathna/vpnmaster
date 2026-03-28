import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/vpn_provider.dart';
import '../../providers/hotspot_provider.dart';
import '../../core/theme/app_theme.dart';

class HotspotScreen extends StatelessWidget {
  const HotspotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final hotspot = context.watch<HotspotProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Hotspot'),
        actions: [
          if (hotspot.isActive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_tethering_rounded, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // VPN Status
            _BannerCard(
              color: vpn.isConnected ? Colors.green : Colors.orange,
              icon: vpn.isConnected ? Icons.vpn_lock_rounded : Icons.warning_amber_rounded,
              message: vpn.isConnected
                  ? 'VPN Connected — Hotspot users will share your VPN.'
                  : 'VPN not connected. Connect VPN first.',
            ),
            const SizedBox(height: 24),

            const _StepLabel(step: 1, title: 'Network Setup'),
            _StepCard(
              child: Column(
                children: [
                  if (hotspot.isActive && !hotspot.proxyOnlyMode) ...[
                    _StatusRow(label: '📶 SSID', value: hotspot.ssid ?? '-', onCopy: () => _copy(context, hotspot.ssid ?? '', 'SSID')),
                    _StatusRow(label: '🔑 Password', value: hotspot.password ?? '-', onCopy: () => _copy(context, hotspot.password ?? '', 'Password')),
                  ] else if (hotspot.isActive && hotspot.proxyOnlyMode)
                    const _StatusRow(label: '🌐 Mode', value: 'System Hotspot')
                  else ...[
                    const Text('Start "App Hotspot" for automatic setup, or use "System Hotspot" if you have custom settings.', 
                        style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 16),
                  ],
                  
                  if (!hotspot.isActive) ...[
                    ElevatedButton.icon(
                      onPressed: () => _startAppHotspot(context, hotspot),
                      icon: const Icon(Icons.wifi_tethering_rounded),
                      label: const Text('Start App Hotspot'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => hotspot.openSystemHotspotSettings(),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Use System Hotspot'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: hotspot.stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop Sharing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _StepLabel(step: 2, title: 'VPN Sharing Status'),
            _StepCard(
              child: Column(
                children: [
                  if (!hotspot.isActive)
                    const Text('Activate Step 1 first to start sharing.', style: TextStyle(color: Colors.grey, fontSize: 13))
                  else if (hotspot.isActive && !hotspot.proxyOnlyMode)
                    const _StatusRow(label: '🛡️ Status', value: 'VPN Sharing Active', isPositive: true)
                  else if (hotspot.isActive && hotspot.proxyOnlyMode)
                    ElevatedButton(
                      onPressed: hotspot.startProxyOnly,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, 
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('START SHARING (PROXY)'),
                    )
                  else
                    const _StatusRow(label: '🛡️ Status', value: 'Active', isPositive: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _StepLabel(step: 3, title: 'Client Configuration'),
            if (hotspot.isActive)
              _StepCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configure your Laptop / Tablet proxy:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    _InfoRow(label: '🌐 Gateway IPs', value: hotspot.gatewayIps.join('\n'), onCopy: () => _copy(context, hotspot.gatewayIps.first, 'IP')),
                    const Divider(height: 20, color: Colors.white10),
                    _InfoRow(label: '🧦 SOCKS5 Port', value: '10810 (Shielded)', onCopy: () => _copy(context, '10810', 'Port')),
                    _InfoRow(label: '🔌 HTTP Port', value: '10809', onCopy: () => _copy(context, '10809', 'Port')),
                    
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🛡️ Anti-Leak Requirements:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(height: 6),
                          Text('1. Disable IPv6 on client device.\n2. Disable QUIC in Chrome settings.\n3. Use SOCKS5 Port 10810.', 
                              style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              const _StepCard(
                child: Text('Sharing info will appear here once active.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),

            if (hotspot.error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(hotspot.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startAppHotspot(BuildContext context, HotspotProvider hotspot) async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      await hotspot.start();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required for Hotspot.')),
        );
      }
    }
  }

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int step;
  final String title;
  const _StepLabel({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
            child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final Widget child;
  const _StepCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;
  final VoidCallback? onCopy;

  const _StatusRow({required this.label, required this.value, this.isPositive = false, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Row(
            children: [
              Text(value, style: TextStyle(
                color: isPositive ? Colors.green : Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
              if (onCopy != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCopy,
                  child: const Icon(Icons.copy_rounded, color: Colors.blueAccent, size: 16),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoRow({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right),
          if (onCopy != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCopy,
              child: const Icon(Icons.copy_rounded, color: Colors.blueAccent, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;

  const _BannerCard({required this.color, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
