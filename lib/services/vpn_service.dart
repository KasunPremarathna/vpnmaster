import 'dart:async';
import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';

enum VpnConnectionState { disconnected, connecting, connected, disconnecting, error }

class VpnStats {
  final int uploadBytes;
  final int downloadBytes;
  final int uploadSpeed;   // bytes/sec
  final int downloadSpeed; // bytes/sec
  final Duration duration;

  const VpnStats({
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.duration = Duration.zero,
  });

  String get uploadSpeedFormatted => _format(uploadSpeed);
  String get downloadSpeedFormatted => _format(downloadSpeed);

  static String _format(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }
}

class VpnService {
  static const _channel = MethodChannel(AppConstants.vpnChannel);

  final _stateController = StreamController<VpnConnectionState>.broadcast();
  final _statsController = StreamController<VpnStats>.broadcast();

  Stream<VpnConnectionState> get stateStream => _stateController.stream;
  Stream<VpnStats> get statsStream => _statsController.stream;

  VpnConnectionState _state = VpnConnectionState.disconnected;
  VpnConnectionState get state => _state;

  Timer? _statsTimer;

  VpnService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStateChanged':
        _updateState(call.arguments as String);
        break;
      case 'onError':
        _stateController.add(VpnConnectionState.error);
        break;
    }
  }

  void _updateState(String stateName) {
    switch (stateName) {
      case 'CONNECTED':
        _state = VpnConnectionState.connected;
        _startStatsPolling();
        break;
      case 'CONNECTING':
        _state = VpnConnectionState.connecting;
        break;
      case 'DISCONNECTED':
        _state = VpnConnectionState.disconnected;
        _stopStatsPolling();
        break;
      case 'DISCONNECTING':
        _state = VpnConnectionState.disconnecting;
        break;
      case 'ERROR':
        _state = VpnConnectionState.error;
        _stopStatsPolling();
        break;
    }
    _stateController.add(_state);
  }

  Future<bool> startVpn(Map<String, dynamic> config) async {
    try {
      _updateState('CONNECTING');
      final result = await _channel.invokeMethod<bool>('startVpn', config);
      return result ?? false;
    } on PlatformException catch (e) {
      _updateState('ERROR');
      throw Exception('VPN start failed: ${e.message}');
    }
  }

  Future<void> stopVpn() async {
    try {
      _updateState('DISCONNECTING');
      await _channel.invokeMethod('stopVpn');
    } on PlatformException catch (e) {
      throw Exception('VPN stop failed: ${e.message}');
    }
  }

  Future<int> pingServer(String xrayJson) async {
    try {
      final result = await _channel.invokeMethod<int>('pingServer', {'xrayJson': xrayJson});
      return result ?? -1;
    } catch (_) {
      return -1;
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>('getStats');
        if (raw != null) {
          _statsController.add(VpnStats(
            uploadBytes: raw['uploadBytes'] as int? ?? 0,
            downloadBytes: raw['downloadBytes'] as int? ?? 0,
            uploadSpeed: raw['uploadSpeed'] as int? ?? 0,
            downloadSpeed: raw['downloadSpeed'] as int? ?? 0,
            duration: Duration(seconds: raw['durationSec'] as int? ?? 0),
          ));
        }
      } catch (_) {}
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void dispose() {
    _statsTimer?.cancel();
    _stateController.close();
    _statsController.close();
  }
}
