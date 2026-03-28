import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hotspot_proxy_server.dart';

class HotspotProvider extends ChangeNotifier {
  static const _channel = MethodChannel('com.vpnmaster/vpn');
  final _proxyServer = HotspotProxyServer();

  bool _isActive = false;
  bool _isLoading = false;
  bool _proxyOnlyMode = false; // true = using system hotspot, proxy only
  String? _ssid;
  String? _password;
  List<String> _gatewayIps = ['192.168.43.1', '192.168.49.1'];
  int _proxyPort = 10809; 
  String? _error;

  String? _customSsid;
  String? _customPassword;

  bool get isActive => _isActive;
  bool get isLoading => _isLoading;
  bool get proxyOnlyMode => _proxyOnlyMode;
  String? get ssid => _ssid;
  String? get password => _password;
  List<String> get gatewayIps => _gatewayIps;
  int get proxyPort => _proxyPort;
  String? get error => _error;

  String? get customSsid => _customSsid;
  String? get customPassword => _customPassword;

  void setCustomCredentials(String ssid, String password) {
    _customSsid = ssid;
    _customPassword = password;
    notifyListeners();
  }

  HotspotProvider() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hotspotStopped') {
        await stop();
        _error = 'Hotspot was stopped by the system.';
        notifyListeners();
      }
    });
  }

  /// Detect all potential gateway IPs of hotspot interfaces
  Future<List<String>> _detectGatewayIps() async {
    final List<String> ips = [];
    try {
      final interfaces = await NetworkInterface.list();
      debugPrint('[HotspotProvider] Scanning interfaces: ${interfaces.map((i) => i.name).toList()}');
      
      for (final interface in interfaces) {
        // Skip the main WiFi interface usually used for internet, 
        // focus on AP (Hotspot), P2P (WiFi Direct), or RMNET (Tethering bridge)
        if (interface.name.contains('wlan0')) continue; 
        
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            if (!ips.contains(ip)) {
              ips.add(ip);
              debugPrint('[HotspotProvider] Found Interface: ${interface.name} -> $ip');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[HotspotProvider] Error detecting gateway: $e');
    }
    
    // Fallback to standard defaults if nothing found
    if (ips.isEmpty) {
      ips.addAll(['192.168.43.1', '192.168.49.1']);
    }
    return ips;
  }

  /// Start app-managed local hotspot
  Future<void> start() async {
    _isLoading = true;
    _error = null;
    _proxyOnlyMode = false;
    notifyListeners();

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('startLocalHotspot');
      if (result != null) {
        _ssid = result['ssid'] as String?;
        _password = result['password'] as String?;
        
        // Detect IP dynamically
        _gatewayIps = await _detectGatewayIps();
        
        // Start Dart proxy server (Handles both HTTP 10809 and SOCKS5 10810)
        await _proxyServer.start();
        if (_proxyServer.isRunning) {
          _isActive = true;
          _proxyPort = 10809;
          _error = null;
        } else {
          _error = 'Failed to start proxy service.';
          await stop();
        }
      }
    } on PlatformException catch (e) {
      _error = e.message ?? 'Failed to start hotspot.';
      _isActive = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Activate proxy-only mode: user enables system hotspot manually, proxy listens
  Future<void> startProxyOnly() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _proxyServer.start();
      if (_proxyServer.isRunning) {
        _isActive = true;
        _proxyOnlyMode = true;
        
        // Detect IP dynamically
        _gatewayIps = await _detectGatewayIps();
        
        _proxyPort = 10809;
        _ssid = null;
        _password = null;
        _error = null;
      } else {
        _error = 'Failed to start proxy service.';
      }
    } catch (e) {
      _error = 'Proxy error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Open device's native hotspot/tethering settings
  Future<void> openSystemHotspotSettings() async {
    try {
      await _channel.invokeMethod('openHotspotSettings');
    } catch (_) {}
  }

  Future<void> stop() async {
    _isLoading = true;
    notifyListeners();
    
    await _proxyServer.stop();
    
    if (!_proxyOnlyMode) {
      try {
        await _channel.invokeMethod('stopLocalHotspot');
      } catch (_) {}
    }
    
    _isActive = false;
    _isLoading = false;
    _proxyOnlyMode = false;
    _ssid = null;
    _password = null;
    _error = null;
    _gatewayIps = ['192.168.43.1', '192.168.49.1'];
    notifyListeners();
  }
}
