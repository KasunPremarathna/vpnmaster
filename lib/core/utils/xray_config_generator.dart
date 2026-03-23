import 'dart:convert';
import '../../data/models/vpn_profile.dart';

class XrayConfigGenerator {
  /// Generates the raw JSON configuration string required by Xray-core
  /// to route traffic intercepted by the Android VpnService via tun2socks.
  static String generate(VpnProfile profile, {int localPort = 10808}) {
    if (profile.xrayConfig == null) return '{}';
    final xc = profile.xrayConfig!;

    // Base Outbound config
    Map<String, dynamic> outbound = {
      "tag": "proxy",
      "protocol": xc.type.name,
    };

    if (xc.type == XrayType.vless) {
      outbound["settings"] = {
        "vnext": [
          {
            "address": xc.address,
            "port": xc.port,
            "users": [
              {
                "id": xc.uuid,
                "encryption": "none",
                "flow": xc.flow ?? "",
              }
            ]
          }
        ]
      };
    } else if (xc.type == XrayType.vmess) {
      outbound["settings"] = {
        "vnext": [
          {
            "address": xc.address,
            "port": xc.port,
            "users": [
              {
                "id": xc.uuid,
                "alterId": int.tryParse(xc.alterId ?? '0') ?? 0,
                "security": xc.security ?? "auto"
              }
            ]
          }
        ]
      };
    } else if (xc.type == XrayType.trojan) {
      outbound["settings"] = {
        "servers": [
          {
            "address": xc.address,
            "port": xc.port,
            "password": xc.password ?? "",
          }
        ]
      };
    }

    // Stream Settings common to VLESS/VMESS/Trojan
    Map<String, dynamic> streamSettings = {};

    if (xc.network != null && xc.network!.isNotEmpty) {
      streamSettings["network"] = xc.network;
      if (xc.network == "ws") {
        streamSettings["wsSettings"] = {
          "path": xc.path ?? "/",
          "headers": {
            if (xc.host != null && xc.host!.isNotEmpty) "Host": xc.host
          }
        };
      } else if (xc.network == "grpc") {
        streamSettings["grpcSettings"] = {
          "serviceName": xc.path ?? ""
        };
      }
    }

    if (xc.security == "tls" || xc.security == "reality") {
      streamSettings["security"] = xc.security;
      
      Map<String, dynamic> secSettings = {
        "serverName": xc.sni ?? xc.address,
        "allowInsecure": true, // Accommodate generic or free servers easily
        "fingerprint": "chrome"
      };

      if (xc.security == "tls") {
        streamSettings["tlsSettings"] = secSettings;
      } else if (xc.security == "reality") {
        streamSettings["realitySettings"] = secSettings;
      }
    }

    if (streamSettings.isNotEmpty) {
      outbound["streamSettings"] = streamSettings;
    }

    // Full config including tun2socks ingress
    final config = {
      "inbounds": [
        {
          "tag": "tun-proxy",
          "protocol": "tun",
          "settings": {
            "mtu": 1500,
            "autoRoute": false,
            "strictRoute": false,
            "endpointAddress": "172.19.0.2",
            "endpointAddressV6": "fc00::2"
          },
          "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
        }
      ],
      "outbounds": [
        outbound,
        {"tag": "direct", "protocol": "freedom", "settings": {}},
        {"tag": "block", "protocol": "blackhole", "settings": {"response": {"type": "http"}}}
      ],
      "routing": {
        "domainStrategy": "AsIs",
        "rules": [
          {"type": "field", "outboundTag": "direct", "domain": ["geosite:cn"]},
          {"type": "field", "outboundTag": "direct", "ip": ["geoip:private", "geoip:cn"]}
        ]
      }
    };

    return jsonEncode(config);
  }
}
