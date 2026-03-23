import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/vpn_provider.dart';

class HotspotScreen extends StatefulWidget {
  const HotspotScreen({super.key});

  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  static const _channel = MethodChannel('com.vpnmaster/vpn');

  bool _hotspotActive = false;
  bool _loading = false;
  String? _ssid;
  String? _password;
  String _gatewayIp = '192.168.49.1';
  int _proxyPort = 10808;
  String? _errorMsg;
  bool _needsPermissionSettings = false;

  @override
  void initState() {
    super.initState();
    // Receive hotspot stopped callback from native
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hotspotStopped') {
        if (mounted) setState(() { _hotspotActive = false; _ssid = null; _password = null; });
      }
    });
  }

  Future<void> _startHotspot() async {
    setState(() { _loading = true; _errorMsg = null; });

    // Request location and nearby devices permissions (required by Android 13+ for startLocalOnlyHotspot)
    final statuses = await [
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    final locGranted = statuses[Permission.location]?.isGranted ?? false;
    final nearbyGranted = statuses[Permission.nearbyWifiDevices]?.isGranted ?? false;

    if (!locGranted || (!nearbyGranted && Platform.isAndroid && await Permission.nearbyWifiDevices.status != PermissionStatus.restricted)) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Location and Nearby Devices permissions are required to create a WiFi hotspot. Please grant them in Settings.';
          _needsPermissionSettings = true;
        });
      }
      return;
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('startLocalHotspot');
      if (result != null && mounted) {
        setState(() {
          _hotspotActive = true;
          _loading = false;
          _ssid = result['ssid'] as String?;
          _password = result['password'] as String?;
          _gatewayIp = result['gatewayIp'] as String? ?? '192.168.49.1';
          _proxyPort = result['proxyPort'] as int? ?? 10808;
          _errorMsg = null;
          _needsPermissionSettings = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = e.message ?? 'Failed to start hotspot.';
        });
      }
    }
  }

  Future<void> _stopHotspot() async {
    setState(() => _loading = true);
    try {
      await _channel.invokeMethod('stopLocalHotspot');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loading = false;
        _hotspotActive = false;
        _ssid = null;
        _password = null;
      });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final isVpnConnected = vpn.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Hotspot'),
        actions: [
          if (_hotspotActive)
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
            // ── VPN Status Banner ──────────────────────────────
            _BannerCard(
              color: isVpnConnected ? Colors.green : Colors.orange,
              icon: isVpnConnected ? Icons.vpn_lock_rounded : Icons.warning_amber_rounded,
              message: isVpnConnected
                  ? 'VPN Connected — Hotspot users will share your VPN internet.'
                  : 'VPN is not connected. Connect VPN first for secure sharing.',
            ),
            const SizedBox(height: 24),

            // ── Hotspot Control Card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hotspotActive ? Colors.green.withValues(alpha: 0.5) : Colors.white12,
                  width: _hotspotActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  // Big animated icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Icon(
                      _hotspotActive ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                      key: ValueKey(_hotspotActive),
                      size: 72,
                      color: _hotspotActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hotspotActive ? 'Hotspot is ON' : 'Hotspot is OFF',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _hotspotActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _hotspotActive ? _stopHotspot : _startHotspot,
                            icon: Icon(_hotspotActive ? Icons.wifi_tethering_off_rounded : Icons.wifi_tethering_rounded),
                            label: Text(
                              _hotspotActive ? 'Stop Hotspot' : 'Start Hotspot',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hotspotActive ? Colors.red : Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                  ],
                  if (_needsPermissionSettings) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => openAppSettings(),
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Open App Settings'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Credentials (shown when active) ─────────────────
            if (_hotspotActive) ...[
              const Text('  Connect other devices with:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _InfoCard(
                children: [
                  _InfoRow(label: '📶 Network Name (SSID)', value: _ssid ?? 'VPN-Hotspot', onCopy: () => _copy(_ssid ?? '', 'SSID')),
                  const Divider(height: 1, color: Colors.white10),
                  _InfoRow(label: '🔑 Password', value: _password ?? '(none)', onCopy: () => _copy(_password ?? '', 'Password')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('  Then set this SOCKS5 proxy on the other device:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _InfoCard(
                children: [
                  _InfoRow(label: '🌐 Proxy Host', value: _gatewayIp, onCopy: () => _copy(_gatewayIp, 'Proxy host')),
                  const Divider(height: 1, color: Colors.white10),
                  _InfoRow(label: '🔌 Proxy Port', value: '$_proxyPort', onCopy: () => _copy('$_proxyPort', 'Proxy port')),
                  const Divider(height: 1, color: Colors.white10),
                  const _InfoRow(label: '⚙️ Proxy Type', value: 'SOCKS5', onCopy: null),
                ],
              ),
              const SizedBox(height: 16),

              // Quick guide
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📱 How to set proxy on Android:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('WiFi Settings → Long press network → Modify → Advanced → Proxy: Manual', style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                    SizedBox(height: 14),
                    Text('💻 How to set proxy on Windows:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('Settings → Network → Proxy → Manual setup → SOCKS: 192.168.49.1 Port: 10808', style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.grey, size: 32),
                    SizedBox(height: 12),
                    Text(
                      'Tap "Start Hotspot" to create a WiFi network.\nOther devices can connect to it and use your VPN internet through a SOCKS5 proxy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _InfoRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace')),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.blueAccent),
              onPressed: onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
