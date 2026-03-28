import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// A lightweight Proxy server that runs in the Flutter process.
/// It provides both HTTP (10809) and SOCKS5 (10810) inbounds.
/// Traffic is forwarded to Xray's local SOCKS5 inbound (127.0.0.1:10808).
class HotspotProxyServer {
  HttpServer? _httpServer;
  ServerSocket? _socksServer;
  bool _isRunning = false;
  
  final int _httpPort = 10809;
  final int _socksServerPort = 10810;

  // Xray's local SOCKS5 inbound info
  final String _xrayHost = '127.0.0.1';
  final int _xrayPort = 10808;

  bool get isRunning => _isRunning;

  /// Start listening for HTTP and SOCKS5 proxy requests
  Future<void> start() async {
    if (_isRunning) return;
    try {
      // 1. Start HTTP Proxy (Port 10809)
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _httpPort, shared: true);
      _httpServer!.listen((HttpRequest request) {
        if (request.method == 'CONNECT') {
          _handleHttpConnect(request);
        } else {
          _handlePlainHttp(request);
        }
      }, onError: (e) => debugPrint('[HotspotProxy] HTTP Error: $e'));

      // 2. Start SOCKS5 Proxy (Port 10810)
      _socksServer = await ServerSocket.bind(InternetAddress.anyIPv4, _socksServerPort, shared: true);
      _socksServer!.listen(_handleSocksServer, onError: (e) => debugPrint('[HotspotProxy] SOCKS Error: $e'));

      _isRunning = true;
      debugPrint('[HotspotProxy] Started: HTTP (10809) & SOCKS5 (10810)');
    } catch (e) {
      debugPrint('[HotspotProxy] Start failed: $e');
      _isRunning = false;
    }
  }

  /// Handles incoming SOCKS5 connections from clients
  Future<void> _handleSocksServer(Socket clientSocket) async {
    try {
      final it = StreamIterator(clientSocket);

      // 1. Handshake: Method Selection
      if (!await it.moveNext().timeout(const Duration(seconds: 3))) return;
      if (it.current[0] != 5) {
        clientSocket.destroy();
        return;
      }
      clientSocket.add([5, 0]); // No Authentication

      // 2. Handshake: Connect Request
      if (!await it.moveNext().timeout(const Duration(seconds: 3))) return;
      final req = it.current;
      if (req.length < 4 || req[1] != 1) { // 1 = CONNECT
        clientSocket.destroy();
        return;
      }

      String host = '';
      int port = 0;
      if (req[3] == 1) { // IPv4
        host = InternetAddress.fromRawAddress(Uint8List.fromList(req.sublist(4, 8))).address;
        port = ByteData.view(Uint8List.fromList(req.sublist(8, 10)).buffer).getUint16(0);
      } else if (req[3] == 3) { // Domain
        int len = req[4];
        host = String.fromCharCodes(req.sublist(5, 5 + len));
        port = ByteData.view(Uint8List.fromList(req.sublist(5 + len, 5 + len + 2)).buffer).getUint16(0);
      } else {
        clientSocket.add([5, 8, 0, 1, 0, 0, 0, 0, 0, 0]); // Addr type not supported
        clientSocket.destroy();
        return;
      }

      debugPrint('[HotspotProxy] SOCKS5 Request: $host:$port');

      final xrayRelay = await _connectToXray(host, port);
      if (xrayRelay == null) {
        clientSocket.add([5, 4, 0, 1, 0, 0, 0, 0, 0, 0]); // Host unreachable
        clientSocket.destroy();
        return;
      }

      clientSocket.add([5, 0, 0, 1, 0, 0, 0, 0, 0, 0]); // Success
      
      // Bi-directional pipe
      xrayRelay.listen(clientSocket.add, onDone: clientSocket.destroy, onError: (_) => clientSocket.destroy());
      
      // Drain the rest of the iterator into the xrayRelay
      while (await it.moveNext()) {
        xrayRelay.add(it.current);
      }
      xrayRelay.destroy();

    } catch (e) {
      clientSocket.destroy();
    }
  }

  /// Connects to Xray with the required SOCKS5 handshake
  Future<dynamic> _connectToXray(String host, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(_xrayHost, _xrayPort, timeout: const Duration(seconds: 3));
      final it = StreamIterator(socket);

      // 1. Method Selection
      socket.add([5, 1, 0]); 
      if (!await it.moveNext().timeout(const Duration(seconds: 3))) throw 'Xray no response';
      if (it.current[0] != 5 || it.current[1] != 0) throw 'Xray auth fail';

      // 2. Connect Request
      final hostBytes = utf8.encode(host);
      final req = BytesBuilder();
      req.add([5, 1, 0, 3, hostBytes.length]);
      req.add(hostBytes);
      final portData = ByteData(2)..setUint16(0, port);
      req.add(portData.buffer.asUint8List());
      socket.add(req.toBytes());

      // 3. Connect Reply
      if (!await it.moveNext().timeout(const Duration(seconds: 5))) throw 'Xray connection timeout';
      if (it.current[0] != 5 || it.current[1] != 0) throw 'Xray connection refused';

      return _ProxySocketWrapper(socket, it);
    } catch (e) {
      debugPrint('[HotspotProxy] Xray Connect Error: $e');
      socket?.destroy();
      return null;
    }
  }

  /// Handles HTTP CONNECT (for HTTPS tunneling)
  void _handleHttpConnect(HttpRequest request) async {
    try {
      String host = request.uri.host.isNotEmpty ? request.uri.host : request.headers.host ?? '';
      int port = request.uri.port > 0 ? request.uri.port : 443;
      
      if (host.contains(':')) {
        final parts = host.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? port;
      }
      if (host.isEmpty) return;

      debugPrint('[HotspotProxy] HTTP CONNECT: $host:$port');
      final xrayRelay = await _connectToXray(host, port);
      if (xrayRelay == null) {
        request.response.statusCode = 502;
        request.response.close();
        return;
      }

      request.response.statusCode = 200;
      final clientPipe = await request.response.detachSocket();
      
      xrayRelay.listen(clientPipe.add, onDone: clientPipe.destroy, onError: (_) => clientPipe.destroy());
      clientPipe.listen(xrayRelay.add, onDone: xrayRelay.destroy, onError: (_) => xrayRelay.destroy());
    } catch (e) {
      request.response.statusCode = 502;
      request.response.close();
    }
  }

  /// Handles plain HTTP requests
  void _handlePlainHttp(HttpRequest request) async {
    try {
      String host = request.uri.host.isNotEmpty ? request.uri.host : request.headers.host ?? '';
      int port = request.uri.port > 0 ? request.uri.port : 80;
      
      if (host.contains(':')) {
        final parts = host.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? port;
      }
      if (host.isEmpty) return;

      debugPrint('[HotspotProxy] HTTP Request: $host');
      final xrayRelay = await _connectToXray(host, port);
      if (xrayRelay == null) {
        request.response.statusCode = 502;
        request.response.close();
        return;
      }

      final path = request.uri.path.isEmpty ? '/' : request.uri.path;
      final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
      xrayRelay.write('${request.method} $path$query HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n');
      request.headers.forEach((name, values) {
        if (!['host', 'connection', 'proxy-connection'].contains(name.toLowerCase())) {
          for (final v in values) {
            xrayRelay.write('$name: $v\r\n');
          }
        }
      });
      xrayRelay.write('\r\n');

      await xrayRelay.addStream(request.cast<List<int>>());
      final clientPipe = await request.response.detachSocket();
      xrayRelay.listen(clientPipe.add, onDone: clientPipe.destroy, onError: (_) => clientPipe.destroy());
    } catch (e) {
      request.response.statusCode = 502;
      request.response.close();
    }
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    await _socksServer?.close();
    _httpServer = null;
    _socksServer = null;
    _isRunning = false;
    debugPrint('[HotspotProxy] Stopped');
  }
}

/// Helper to bridge StreamIterator to the final pipe
class _ProxySocketWrapper {
  final Socket _socket;
  final dynamic _source; // Stream<List<int>> or StreamIterator<List<int>>

  _ProxySocketWrapper(this._socket, this._source);

  void listen(void Function(List<int>) onData, {void Function()? onDone, Function? onError}) {
    if (_source is StreamIterator<List<int>>) {
      _bridgeIterator(_source, onData, onDone, onError);
    } else {
      (_source as Stream<List<int>>).listen(onData, onDone: onDone, onError: onError);
    }
  }

  Future<void> _bridgeIterator(StreamIterator<List<int>> it, Function onData, Function? onDone, Function? onError) async {
    try {
      while (await it.moveNext()) {
        onData(it.current);
      }
      onDone?.call();
    } catch (e) {
      onError?.call(e);
    }
  }

  void add(List<int> d) => _socket.add(d);
  void write(String s) => _socket.write(s);
  Future<void> addStream(Stream<List<int>> s) => _socket.addStream(s);
  void destroy() => _socket.destroy();
}
