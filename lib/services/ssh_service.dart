import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../data/models/vpn_profile.dart';
import 'log_service.dart';

class SSHService {
  SSHClient? _client;
  Socket? _rawSocket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final _log = LogService();

  final _stateController = StreamController<bool>.broadcast();
  Stream<bool> get stateStream => _stateController.stream;

  /// Connect SSH, optionally tunneling through an HTTP CONNECT proxy payload.
  Future<void> connect(VpnProfile profile, {int localPort = 1080}) async {
    if (_isConnected) await disconnect();

    _log.info('SSH: Connecting to ${profile.server}:${profile.port}...');

    try {
      if (profile.payload != null && profile.payload!.isNotEmpty) {
        // ── Phase 1: Inject HTTP CONNECT payload ─────────────────────────────
        _log.info('SSH: Sending HTTP CONNECT payload...');
        _rawSocket = await Socket.connect(
          profile.server,
          profile.port,
          timeout: const Duration(seconds: 15),
        );

        // Build the payload, replacing template variables with real values
        final payload = _buildPayload(profile.payload!, profile.server, profile.port);
        _rawSocket!.write(payload);
        await _rawSocket!.flush();
        _log.info('SSH: Payload sent, awaiting server response...');

        // Wait for the HTTP 200 OK or 101 Switching Protocols response
        bool tunnelEstablished = false;
        final responseBuffer = StringBuffer();
        final completer = Completer<void>();

        late StreamSubscription sub;
        sub = _rawSocket!.listen(
          (bytes) {
            final chunk = utf8.decode(bytes, allowMalformed: true);
            responseBuffer.write(chunk);
            _log.info('SSH: Server response: ${chunk.trim()}');

            final response = responseBuffer.toString();
            if (response.contains('200') || response.contains('101')) {
              tunnelEstablished = true;
              sub.cancel();
              if (!completer.isCompleted) completer.complete();
            } else if (response.contains('HTTP/1') && response.contains('\r\n\r\n')) {
              // Got a complete non-200 response
              sub.cancel();
              if (!completer.isCompleted) {
                completer.completeError(
                  Exception('Proxy rejected: ${response.split('\r\n').first}')
                );
              }
            }
          },
          onError: (e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
        );

        // Timeout if no response
        await completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception('Payload response timeout — server did not reply');
        });

        if (!tunnelEstablished) {
          throw Exception('HTTP CONNECT failed — no 200/101 received');
        }

        _log.info('SSH: HTTP tunnel established ✔ Starting SSH handshake...');

        // ── Phase 2: SSH handshake over the established HTTP tunnel ──────────
        final sshSocket = _DartSocketAdapter(_rawSocket!);
        _client = SSHClient(
          sshSocket,
          username: profile.username,
          onPasswordRequest: () => profile.password,
          identities: profile.authType == AuthType.privateKey &&
                  profile.privateKey.isNotEmpty
              ? SSHKeyPair.fromPem(profile.privateKey)
              : const [],
        );

      } else {
        // ── No payload: Direct raw SSH connection ────────────────────────────
        _log.info('SSH: Direct connection (no payload)...');
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
      }

      // Await authentication
      await _client!.authenticated;

      _log.info('SSH: Authenticated ✔');
      _isConnected = true;
      _stateController.add(true);
      _log.info('SSH: SOCKS5 forwarding active on port $localPort');

    } catch (e) {
      _log.error('SSH: Connection failed: $e');
      _isConnected = false;
      _stateController.add(false);
      _rawSocket?.destroy();
      _rawSocket = null;
      rethrow;
    }
  }

  /// Builds the HTTP CONNECT injectable payload string, substituting template variables.
  String _buildPayload(String template, String host, int port) {
    final hostPort = '$host:$port';
    // Replace common template variables
    String payload = template
        .replaceAll('[host_port]', hostPort)
        .replaceAll('[host]', host)
        .replaceAll('[port]', port.toString())
        .replaceAll('[crlf]', '\r\n')
        .replaceAll('[cr]', '\r')
        .replaceAll('[lf]', '\n')
        .replaceAll(r'\r\n', '\r\n')
        .replaceAll(r'\n', '\n');

    // Ensure the payload ends with the double CRLF required by HTTP spec
    if (!payload.endsWith('\r\n\r\n')) {
      payload = '${payload.trimRight()}\r\n\r\n';
    }

    return payload;
  }

  Future<void> disconnect() async {
    _log.info('SSH: Disconnecting...');
    try {
      _client?.close();
    } catch (_) {}
    try {
      _rawSocket?.destroy();
    } catch (_) {}
    _client = null;
    _rawSocket = null;
    _isConnected = false;
    _stateController.add(false);
    _log.info('SSH: Disconnected');
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}

/// Adapts a dart:io Socket into the SSHSocket interface expected by dartssh2.
/// Used to hand off the pre-tunneled socket (after HTTP CONNECT) for SSH handshaking.
class _DartSocketAdapter implements SSHSocket {
  final Socket _socket;
  _DartSocketAdapter(this._socket);

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> close() async => _socket.destroy();
}
