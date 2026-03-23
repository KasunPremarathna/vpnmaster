import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vpn_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/vpn_service.dart';
import '../../data/models/vpn_profile.dart';
// import '../widgets/marketplace_section.dart'; // temporarily hidden
import 'server_list_screen.dart';
import 'log_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import 'config_screen.dart';
import 'hotspot_screen.dart';
import 'package:in_app_update/in_app_update.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  final List<FlSpot> _uploadData = [];
  final List<FlSpot> _downloadData = [];
  int _tick = 0;

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _updateGraph(VpnStats stats) {
    _tick++;
    _uploadData.add(FlSpot(_tick.toDouble(), stats.uploadSpeed / 1024));
    _downloadData.add(FlSpot(_tick.toDouble(), stats.downloadSpeed / 1024));
    if (_uploadData.length > 30) {
      _uploadData.removeAt(0);
      _downloadData.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final config = context.watch<ConfigProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;

    _updateGraph(vpn.stats);

    return Scaffold(
      drawer: _buildDrawer(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 60,
            floating: true,
            pinned: true,
            title: Row(
              children: [
                Image.asset('assets/icons/logo.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.vpn_lock, color: colors.accent, size: 28)),
                const SizedBox(width: 10),
                const Text('Velora VPN Proxy'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.list_alt_rounded),
                tooltip: 'Logs',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LogScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Active Profile ──────────────────────
                _ProfileSelector(
                  profile: config.selectedProfile,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ServerListScreen())),
                ),
                const SizedBox(height: 32),

                // ── Connect Button ──────────────────────
                Center(
                  child: _ConnectButton(
                    state: vpn.connectionState,
                    pulseController: _pulseController,
                    onTap: () async {
                      if (vpn.isConnected) {
                        await vpn.disconnect();
                      } else {
                        final profile = config.selectedProfile;
                        if (profile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please select a server first')),
                          );
                          return;
                        }
                        await vpn.connect(profile);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // ── Status Label ─────────────────────────
                Center(
                  child: _StatusBadge(state: vpn.connectionState),
                ),
                const SizedBox(height: 32),

                // ── Speed Cards ──────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SpeedCard(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Upload',
                        value: vpn.stats.uploadSpeedFormatted,
                        color: colors.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SpeedCard(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Download',
                        value: vpn.stats.downloadSpeedFormatted,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // ── Ping Button ──────────────────────────
                Center(
                  child: _HomePingButton(
                    profile: config.selectedProfile,
                    vpnProvider: vpn,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Duration ─────────────────────────────
                if (vpn.isConnected)
                  Center(
                    child: Text(
                      _formatDuration(vpn.stats.duration),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Speed Graph ──────────────────────────
                _SpeedGraph(
                  uploadData: _uploadData,
                  downloadData: _downloadData,
                  accentColor: colors.accent,
                  greenColor: colors.accentGreen,
                ),
                const SizedBox(height: 48),

                // ── Marketplace Section (temporarily hidden) ─
                // const MarketplaceSection(),
                // const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.vpn_lock, size: 48, color: Color(0xFF00D4FF)),
                  SizedBox(height: 8),
                  Text('VPN Master',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _drawerItem(context, Icons.home_rounded, 'Home', () => Navigator.pop(context)),
            _drawerItem(context, Icons.dns_rounded, 'Servers', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ServerListScreen()));
            }),
            _drawerItem(context, Icons.list_alt_rounded, 'Logs', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LogScreen()));
            }),
            _drawerItem(context, Icons.wifi_tethering_rounded, 'VPN Hotspot', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HotspotScreen()));
            }),
            _drawerItem(context, Icons.tune_rounded, 'Payload Builder', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/payload');
            }),
            _drawerItem(context, Icons.folder_rounded, 'Config', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ConfigScreen()));
            }),
            _drawerItem(context, Icons.settings_rounded, 'Settings', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _drawerItem(context, Icons.school_rounded, 'Tutorial & Guide', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TutorialScreen()));
            }),
            _drawerItem(context, Icons.privacy_tip_rounded, 'Privacy Policy', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/privacy');
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }

  ListTile _drawerItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Connect Button widget ─────────────────────────────────────
class _ConnectButton extends StatelessWidget {
  final VpnConnectionState state;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _ConnectButton({
    required this.state,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isConnected = state == VpnConnectionState.connected;
    final isConnecting = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting;

    Color buttonColor = isConnected
        ? colors.accentGreen
        : isConnecting
            ? colors.accentOrange
            : colors.accent;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = isConnected
            ? 1.0 + 0.04 * pulseController.value
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: isConnecting ? null : onTap,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    buttonColor.withValues(alpha: .9),
                    buttonColor.withValues(alpha: .3),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: isConnected ? .5 : .2),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(color: buttonColor, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isConnecting
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : Icon(
                          isConnected ? Icons.power_settings_new : Icons.power_settings_new,
                          size: 48,
                          color: Colors.white,
                        ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected
                        ? 'DISCONNECT'
                        : isConnecting
                            ? _connectingLabel(state)
                            : 'CONNECT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
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

  String _connectingLabel(VpnConnectionState s) {
    switch (s) {
      case VpnConnectionState.connecting: return 'CONNECTING';
      case VpnConnectionState.disconnecting: return 'STOPPING';
      default: return 'WAIT...';
    }
  }
}

// ── Status Badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final VpnConnectionState state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    Color color;
    String label;
    switch (state) {
      case VpnConnectionState.connected:
        color = colors.accentGreen; label = '● Connected'; break;
      case VpnConnectionState.connecting:
        color = colors.accentOrange; label = '◉ Connecting…'; break;
      case VpnConnectionState.disconnecting:
        color = colors.accentOrange; label = '◉ Disconnecting…'; break;
      case VpnConnectionState.error:
        color = colors.accentRed; label = '✕ Error'; break;
      default:
        color = Colors.grey; label = '○ Disconnected'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Profile Selector ──────────────────────────────────────────
class _ProfileSelector extends StatelessWidget {
  final dynamic profile;
  final VoidCallback onTap;
  const _ProfileSelector({this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.accent.withValues(alpha: .2)),
        ),
        child: Row(
          children: [
            Icon(Icons.dns_rounded, color: colors.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: profile == null
                  ? Text('Tap to select a server',
                      style: TextStyle(color: Colors.grey.shade500))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${profile.server}:${profile.port}  •  ${profile.protocolLabel}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey)),
                      ],
                    ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

// ── Speed Card ────────────────────────────────────────────────
class _SpeedCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SpeedCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              Text(value,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Speed Graph ───────────────────────────────────────────────
class _SpeedGraph extends StatelessWidget {
  final List<FlSpot> uploadData;
  final List<FlSpot> downloadData;
  final Color accentColor;
  final Color greenColor;

  const _SpeedGraph({
    required this.uploadData,
    required this.downloadData,
    required this.accentColor,
    required this.greenColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    if (uploadData.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Connect to see speed graph', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final allY = [...uploadData.map((e) => e.y), ...downloadData.map((e) => e.y)];
    final maxY = allY.reduce(max).clamp(1.0, double.infinity) * 1.3;
    final minX = uploadData.first.x;
    final maxX = uploadData.last.x;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Colors.white10, strokeWidth: 1),
            getDrawingVerticalLine: (_) => const FlLine(color: Colors.transparent),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _line(uploadData, greenColor),
            _line(downloadData, accentColor),
          ],
        ),
      ),
    );
  }

      LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: .1),
        ),
      );
}

class _HomePingButton extends StatefulWidget {
  final VpnProfile? profile;
  final VpnProvider vpnProvider;

  const _HomePingButton({required this.profile, required this.vpnProvider});

  @override
  State<_HomePingButton> createState() => _HomePingButtonState();
}

class _HomePingButtonState extends State<_HomePingButton> {
  bool _isPinging = false;
  int? _lastPing;

  Future<void> _doPing() async {
    if (widget.profile == null || _isPinging) {
      if (widget.profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a server first')));
      }
      return;
    }
    setState(() {
      _isPinging = true;
      _lastPing = null;
    });

    final ms = await widget.vpnProvider.checkPing(widget.profile!);
    if (!mounted) return;

    setState(() {
      _isPinging = false;
      _lastPing = ms;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPinging) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    
    if (_lastPing != null) {
      final color = _lastPing! < 0
          ? Colors.red
          : _lastPing! < 300
              ? Colors.green
              : Colors.orange;
      return TextButton.icon(
        icon: Icon(Icons.network_ping_rounded, color: color),
        label: Text(
          _lastPing! < 0 ? 'Timeout' : 'Ping: ${_lastPing}ms',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        onPressed: _doPing,
      );
    }

    return TextButton.icon(
      icon: const Icon(Icons.network_ping_rounded, color: Colors.grey),
      label: const Text('Test Ping', style: TextStyle(color: Colors.grey)),
      onPressed: _doPing,
    );
  }
}
