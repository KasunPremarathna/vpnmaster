import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/vpn_profile.dart';
import '../services/vpn_service.dart';
import '../services/ssh_service.dart';
import '../services/log_service.dart';
import '../core/utils/xray_config_generator.dart';

class VpnProvider extends ChangeNotifier {
  final VpnService _vpnService = VpnService();
  final SSHService _sshService = SSHService();
  final LogService _log = LogService();

  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  VpnStats _stats = const VpnStats();
  VpnProfile? _activeProfile;
  String? _error;

  StreamSubscription<VpnConnectionState>? _stateSub;
  StreamSubscription<VpnStats>? _statsSub;

  // Auto-reconnect
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool autoReconnect = true;

  VpnConnectionState get connectionState => _connectionState;
  VpnStats get stats => _stats;
  VpnProfile? get activeProfile => _activeProfile;
  String? get error => _error;

  bool get isConnected => _connectionState == VpnConnectionState.connected;
  bool get isConnecting => _connectionState == VpnConnectionState.connecting;

  VpnProvider() {
    _stateSub = _vpnService.stateStream.listen(_onStateChanged);
    _statsSub = _vpnService.statsStream.listen(_onStatsChanged);
  }

  void _onStateChanged(VpnConnectionState state) {
    _connectionState = state;
    
    switch (state) {
      case VpnConnectionState.connected:
        _log.info('VPN Connected Successfully ✔️');
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        break;
      case VpnConnectionState.disconnected:
        _log.info('VPN Disconnected 🛑');
        break;
      case VpnConnectionState.error:
        _log.error('VPN Connection Error ⚠️');
        if (autoReconnect) _scheduleReconnect();
        break;
      case VpnConnectionState.connecting:
        break;
      case VpnConnectionState.disconnecting:
        break;
    }

    notifyListeners();
  }

  void _onStatsChanged(VpnStats stats) {
    _stats = stats;
    notifyListeners();
  }

  Future<void> connect(VpnProfile profile) async {
    _activeProfile = profile;
    _error = null;
    notifyListeners();

    try {
      _log.info('Connecting to ${profile.name} (${profile.protocolLabel})...');

      String activeSni = profile.sni ?? '';
      if (activeSni.contains(',')) {
        final snis = activeSni.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (snis.isNotEmpty) {
          activeSni = snis[_reconnectAttempts % snis.length];
          _log.info('Multi-SNI Rotator selected: $activeSni (Attempt $_reconnectAttempts)');
        }
      }

      final config = {
        'server': profile.server,
        'port': profile.port,
        'protocol': profile.protocol.name,
        'username': profile.username,
        'password': profile.password,
        'dns': profile.dns ?? '1.1.1.1',
        'sni': activeSni,
        'xrayJson': [VpnProtocol.vless, VpnProtocol.vmess, VpnProtocol.trojan].contains(profile.protocol)
            ? XrayConfigGenerator.generate(profile, overrideSni: activeSni)
            : null,
      };

      await _vpnService.startVpn(config);
    } catch (e) {
      _log.error('VPN connection error: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<int> checkPing(VpnProfile profile) async {
    if (![VpnProtocol.vless, VpnProtocol.vmess, VpnProtocol.trojan].contains(profile.protocol)) {
      return -1; // Cannot ping SSH natively using Libv2ray yet
    }
    
    _log.info('Pinging ${profile.server}...');
    final xrayJson = XrayConfigGenerator.generate(profile);
    final ms = await _vpnService.pingServer(xrayJson);
    
    if (ms > 0) {
      _log.info('Server response: $ms ms ⚡');
    } else {
      _log.warning('Server ping timeout or unreachable ⏱️');
    }
    
    return ms;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    await _vpnService.stopVpn();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      _log.warning('Max reconnect attempts reached');
      return;
    }
    _reconnectAttempts++;
    _log.info('Reconnecting in 5s (attempt $_reconnectAttempts/5)...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_activeProfile != null) connect(_activeProfile!);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _statsSub?.cancel();
    _reconnectTimer?.cancel();
    _vpnService.dispose();
    _sshService.dispose();
    super.dispose();
  }
}
