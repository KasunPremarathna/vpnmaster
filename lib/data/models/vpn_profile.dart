import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/utils/crypto_utils.dart';

enum VpnProtocol { ssh, vmess, vless, trojan, shadowsocks, http, https }
enum AuthType { password, privateKey }

class VpnProfile {
  final String id;
  String name;
  String server;
  int port;
  VpnProtocol protocol;
  AuthType authType;
  String username;
  String password;
  String privateKey;
  String? payload;
  String? sni;
  String? dns;
  XrayConfig? xrayConfig;
  DateTime createdAt;

  VpnProfile({
    String? id,
    required this.name,
    required this.server,
    required this.port,
    this.protocol = VpnProtocol.ssh,
    this.authType = AuthType.password,
    this.username = '',
    this.password = '',
    this.privateKey = '',
    this.payload,
    this.sni,
    this.dns,
    this.xrayConfig,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  VpnProfile copyWith({
    String? name,
    String? server,
    int? port,
    VpnProtocol? protocol,
    AuthType? authType,
    String? username,
    String? password,
    String? privateKey,
    String? payload,
    String? sni,
    String? dns,
    XrayConfig? xrayConfig,
  }) =>
      VpnProfile(
        id: id,
        name: name ?? this.name,
        server: server ?? this.server,
        port: port ?? this.port,
        protocol: protocol ?? this.protocol,
        authType: authType ?? this.authType,
        username: username ?? this.username,
        password: password ?? this.password,
        privateKey: privateKey ?? this.privateKey,
        payload: payload ?? this.payload,
        sni: sni ?? this.sni,
        dns: dns ?? this.dns,
        xrayConfig: xrayConfig ?? this.xrayConfig,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'server': server,
        'port': port,
        'protocol': protocol.name,
        'authType': authType.name,
        'username': username,
        'password': password,
        'privateKey': privateKey,
        'payload': payload,
        'sni': sni,
        'dns': dns,
        'xrayConfig': xrayConfig?.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) => VpnProfile(
        id: json['id'] as String?,
        name: json['name'] as String,
        server: json['server'] as String,
        port: json['port'] as int,
        protocol: VpnProtocol.values.firstWhere(
          (e) => e.name == json['protocol'],
          orElse: () => VpnProtocol.ssh,
        ),
        authType: AuthType.values.firstWhere(
          (e) => e.name == json['authType'],
          orElse: () => AuthType.password,
        ),
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        privateKey: json['privateKey'] as String? ?? '',
        payload: json['payload'] as String?,
        sni: json['sni'] as String?,
        dns: json['dns'] as String?,
        xrayConfig: json['xrayConfig'] != null
            ? XrayConfig.fromJson(json['xrayConfig'] as Map<String, dynamic>)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  /// Parse a generic VPN URI by introspecting its scheme
  static VpnProfile fromUri(String uri) {
    if (uri.startsWith('vless://')) {
      final p = fromVlessUri(uri);
      if (p != null) return p;
    } else if (uri.startsWith('nm-vless://')) {
      final p = fromNmVless(uri);
      if (p != null) return p;
    }
    // Add vmess, trojan etc. as the app expands
    throw FormatException('Unsupported or invalid profile URI: $uri');
  }

  /// Parse nm-vless:// URI securely using decrypted netmod payload
  static VpnProfile? fromNmVless(String uri) {
    try {
      if (!uri.startsWith('nm-vless://')) return null;
      final encoded = uri.replaceFirst('nm-vless://', '');
      final decrypted = CryptoUtils.decryptNetmod(encoded);
      if (decrypted.isEmpty) return null;
      return fromVlessUri('vless://$decrypted');
    } catch (_) {
      return null;
    }
  }

  /// Parse standard vless:// URI
  static VpnProfile? fromVlessUri(String uriString) {
    try {
      if (!uriString.startsWith('vless://')) return null;
      
      final uri = Uri.parse(uriString);
      final host = uri.host;
      if (host.isEmpty) return null;
      
      final port = uri.hasPort ? uri.port : 443;
      final uuid = uri.userInfo;
      final params = uri.queryParameters;
      final remark = uri.fragment.isNotEmpty 
          ? Uri.decodeComponent(uri.fragment) 
          : 'VLess Profile';

      return VpnProfile(
        name: remark,
        server: host,
        port: port,
        protocol: VpnProtocol.vless,
        username: uuid,
        sni: params['sni'],
        xrayConfig: XrayConfig(
          type: XrayType.vless,
          address: host,
          port: port,
          uuid: uuid,
          network: params['type'] ?? 'tcp',
          tls: params['security'] ?? '',
          sni: params['sni'],
          host: params['host'],
          path: params['path'],
          flow: params['flow'],
          security: params['encryption'],
          remark: remark,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String get protocolLabel {
    switch (protocol) {
      case VpnProtocol.ssh:
        return 'SSH';
      case VpnProtocol.vmess:
        return 'VMess';
      case VpnProtocol.vless:
        return 'VLess';
      case VpnProtocol.trojan:
        return 'Trojan';
      case VpnProtocol.shadowsocks:
        return 'SS';
      case VpnProtocol.http:
        return 'HTTP';
      case VpnProtocol.https:
        return 'HTTPS';
    }
  }
}

// ────────────────────────────────────────────────────────────
// XRAY Config
// ────────────────────────────────────────────────────────────

enum XrayType { vmess, vless, trojan, shadowsocks }

class XrayConfig {
  final XrayType type;
  final String address;
  final int port;
  final String uuid;
  final String? alterId;
  final String? security;
  final String? network;
  final String? tls;
  final String? sni;
  final String? host;
  final String? path;
  final String? flow;
  final String? password; // trojan / ss
  final String? method;   // ss cipher
  final String? remark;

  const XrayConfig({
    required this.type,
    required this.address,
    required this.port,
    this.uuid = '',
    this.alterId,
    this.security,
    this.network,
    this.tls,
    this.sni,
    this.host,
    this.path,
    this.flow,
    this.password,
    this.method,
    this.remark,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'address': address,
        'port': port,
        'uuid': uuid,
        'alterId': alterId,
        'security': security,
        'network': network,
        'tls': tls,
        'sni': sni,
        'host': host,
        'path': path,
        'flow': flow,
        'password': password,
        'method': method,
        'remark': remark,
      };

  factory XrayConfig.fromJson(Map<String, dynamic> json) => XrayConfig(
        type: XrayType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => XrayType.vless,
        ),
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        uuid: json['uuid'] as String? ?? '',
        alterId: json['alterId'] as String?,
        security: json['security'] as String?,
        network: json['network'] as String?,
        tls: json['tls'] as String?,
        sni: json['sni'] as String?,
        host: json['host'] as String?,
        path: json['path'] as String?,
        flow: json['flow'] as String?,
        password: json['password'] as String?,
        method: json['method'] as String?,
        remark: json['remark'] as String?,
      );

  /// Parse vmess:// URI (base64-encoded JSON)
  static XrayConfig? fromVmessUri(String uri) {
    try {
      if (!uri.startsWith('vmess://')) return null;
      final b64 = uri.replaceFirst('vmess://', '');
      final decoded = utf8.decode(base64Decode(
          b64.padRight(b64.length + (4 - b64.length % 4) % 4, '=')));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return XrayConfig(
        type: XrayType.vmess,
        address: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '443') ?? 443,
        uuid: json['id'] as String? ?? '',
        alterId: json['aid']?.toString(),
        security: json['scy'] as String?,
        network: json['net'] as String?,
        tls: json['tls'] as String?,
        sni: json['sni'] as String?,
        host: json['host'] as String?,
        path: json['path'] as String?,
        remark: json['ps'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse trojan:// URI
  static XrayConfig? fromTrojanUri(String uriString) {
    try {
      if (!uriString.startsWith('trojan://')) return null;
      
      final uri = Uri.parse(uriString);
      final host = uri.host;
      if (host.isEmpty) return null;
      
      final port = uri.hasPort ? uri.port : 443;
      final password = uri.userInfo;
      final params = uri.queryParameters;
      final remark = uri.fragment.isNotEmpty 
          ? Uri.decodeComponent(uri.fragment) 
          : 'Trojan';

      return XrayConfig(
        type: XrayType.trojan,
        address: host,
        port: port,
        password: password,
        sni: params['sni'],
        network: params['type'],
        remark: remark,
      );
    } catch (_) {
      return null;
    }
  }

  String get typeLabel {
    switch (type) {
      case XrayType.vmess: return 'VMess';
      case XrayType.vless: return 'VLess';
      case XrayType.trojan: return 'Trojan';
      case XrayType.shadowsocks: return 'Shadowsocks';
    }
  }
}
