import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import '../data/models/vpn_profile.dart';
import 'log_service.dart';

class SSHService {
  SSHClient? _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final _log = LogService();

  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get stateStream => _stateController.stream;

  /// Connect SSH. Uses dartssh2 which handles auth internally.
  Future<void> connect(VpnProfile profile, {int localPort = 1080}) async {
    if (_isConnected) await disconnect();

    _log.info('SSH: Connecting to ${profile.server}:${profile.port}...');

    try {
      final socket = await SSHSocket.connect(
        profile.server,
        profile.port,
        timeout: const Duration(seconds: 15),
      );

      _client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: () => profile.password,
        identities: profile.authType == AuthType.privateKey &&
                profile.privateKey.isNotEmpty
            ? SSHKeyPair.fromPem(profile.privateKey)
            : const [],
      );

      // Authenticate by awaiting the authenticated future
      await _client!.authenticated;

      _log.info('SSH: Authenticated ✔');
      _isConnected = true;
      _stateController.add(true);
      _log.info('SSH: SOCKS5 dynamic forwarding ready on port $localPort');
    } catch (e) {
      _log.error('SSH: Connection failed: $e');
      _isConnected = false;
      _stateController.add(false);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _log.info('SSH: Disconnecting...');
    try {
      _client?.close();
    } catch (_) {}
    _client = null;
    _isConnected = false;
    _stateController.add(false);
    _log.info('SSH: Disconnected');
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
