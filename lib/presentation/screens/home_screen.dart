import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vpn_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/vpn_service.dart';
import '../../data/models/vpn_profile.dart';
import '../../providers/log_provider.dart';
import '../../services/log_service.dart';
import 'server_list_screen.dart';
import 'log_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import 'config_screen.dart';
import 'hotspot_screen.dart';
import 'package:in_app_update/in_app_update.dart';
import '../../services/device_service.dart';
import '../../services/auth_service.dart';
import '../../data/models/user.dart';
import '../marketplace/marketplace_feed_screen.dart';
import 'role_selection_screen.dart';
import 'package:flutter/services.dart';

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
  String? _deviceId;
  int _currentIndex = 0;

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
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await DeviceService.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
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
    return StreamBuilder<AppUser?>(
      stream: AuthService().userStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.hasData && authSnapshot.data!.role == 'pending') {
          return RoleSelectionScreen(user: authSnapshot.data!);
        }

        final vpn = context.watch<VpnProvider>();
        final config = context.watch<ConfigProvider>();
        final colors = Theme.of(context).extension<AppColors>()!;
        final user = authSnapshot.data;

        _updateGraph(vpn.stats);

        return Scaffold(
          drawer: _buildDrawer(context),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildDashboard(context, vpn, config, colors),
              MarketplaceFeedScreen(currentUser: user),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(context, user),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, VpnProvider vpn, ConfigProvider config, AppColors colors) {
    return CustomScrollView(
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
              const SizedBox(height: 24),
              
              // ── Mini Log Console ─────────────────────
              const _MiniLogConsole(),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
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
            
            const Divider(height: 32, indent: 16, endIndent: 16),
            
            const Spacer(),
            
            // ── Device Information ────────────────────
            if (_deviceId != null)
              _buildDeviceIdSection(context),
            
            // ── Footer Decoration ─────────────────────
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: Color(0x4DE6E0E9),
                      fontSize: 8,
                      letterSpacing: 2,
                    ),
                  ),
                  Divider(color: Colors.white10, height: 16),
                  Text(
                    'v1.0.6+7',
                    style: TextStyle(
                      color: Color(0xFFE6E0E9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceIdSection(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DEVICE ID', 
            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _deviceId ?? 'Loading...',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: colors.accent.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _deviceId ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device ID copied!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
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

  Widget _buildBottomNav(BuildContext context, AppUser? user) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index > 0 && user == null) {
            _showLoginPrompt(context);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: colors.accent,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.vpn_lock_rounded),
            label: 'VPN',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: 'MARKETPLACE',
          ),
        ],
      ),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please sign in to access the VPN marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final auth = AuthService();
              try {
                await auth.signInWithGoogle();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Login failed: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Sign in with Google'),
          ),
        ],
      ),
    );
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
              width: 110,
              height: 110,
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
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: buttonColor, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isConnecting
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : const Icon(
                          Icons.power_settings_new,
                          size: 34,
                          color: Colors.white,
                        ),
                  const SizedBox(height: 4),
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

// ── Mini Log Console ───────────────────────────────────────────
class _MiniLogConsole extends StatelessWidget {
  const _MiniLogConsole();

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, size: 16, color: colors.accent),
              const SizedBox(width: 6),
              const Text('Live Console', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.entries.isEmpty
                ? const Center(child: Text('Waiting for connection...', style: TextStyle(color: Colors.grey, fontSize: 11)))
                : ListView.builder(
                    reverse: true, // Auto scrolls to bottom natively 
                    itemCount: logs.entries.length,
                    itemBuilder: (ctx, i) {
                      // Reverse index to show newest at bottom because list is reversed
                      final reversedIndex = logs.entries.length - 1 - i;
                      final entry = logs.entries[reversedIndex];
                      final color = _colorForLevel(context, entry.level);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.formattedTime, style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entry.message, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _colorForLevel(BuildContext context, LogLevel level) {
    switch (level) {
      case LogLevel.debug: return Colors.grey;
      case LogLevel.info: return Theme.of(context).extension<AppColors>()!.accent;
      case LogLevel.warning: return Colors.orange;
      case LogLevel.error: return Colors.redAccent;
    }
  }
}
