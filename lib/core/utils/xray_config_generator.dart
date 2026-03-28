import 'dart:convert';
import '../../data/models/vpn_profile.dart';

class XrayConfigGenerator {
  /// Generates the raw JSON configuration string required by Xray-core
  /// to route traffic intercepted by the Android VpnService via tun2socks.
  static String generate(VpnProfile profile, {int localPort = 10808, String? overrideSni}) {
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
                if (xc.flow != null && xc.flow!.isNotEmpty) "flow": xc.flow,
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
    final activeHost = (overrideSni?.isNotEmpty == true) ? overrideSni : xc.host;

    if (xc.network != null && xc.network!.isNotEmpty) {
      streamSettings["network"] = xc.network;
      if (xc.network == "ws") {
        streamSettings["wsSettings"] = {
          "path": xc.path ?? "/",
          "headers": {
            if (activeHost != null && activeHost.isNotEmpty) "Host": activeHost
          }
        };
      } else if (xc.network == "grpc") {
        streamSettings["grpcSettings"] = {
          "serviceName": xc.path ?? ""
        };
      }
    }

    if (xc.tls == "tls" || xc.tls == "reality" || xc.tls == "xtls") {
      streamSettings["security"] = xc.tls;
      
      Map<String, dynamic> secSettings = {
        "serverName": (overrideSni?.isNotEmpty == true) ? overrideSni : (xc.sni ?? xc.address),
        "allowInsecure": true, // Accommodate generic or free servers easily
        "fingerprint": "chrome"
      };

      if (xc.tls == "tls") {
        streamSettings["tlsSettings"] = secSettings;
      } else if (xc.tls == "reality") {
        streamSettings["realitySettings"] = secSettings;
      } else if (xc.tls == "xtls") {
        streamSettings["xtlsSettings"] = secSettings;
      }
    }

    if (streamSettings.isNotEmpty) {
      outbound["streamSettings"] = streamSettings;
    }

    // Full config including tun2socks ingress and internal DNS resolver
    final config = {
      "log": {"loglevel": "info"},
      "dns": {
        "servers": [
          profile.dns ?? "1.1.1.1",
          "8.8.8.8",
          "localhost"
        ]
      },
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
        },
        {
          "tag": "socks-in",
          "protocol": "socks",
          "listen": "127.0.0.1",
          "port": 10808,
          "settings": {
            "auth": "noauth",
            "udp": true
          },
          "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
        }
      ],
      "outbounds": [
        outbound, // Tag: "proxy"
        {"tag": "dns-out", "protocol": "dns", "settings": {}} // Answers intercepted TUN DNS queries
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          // Mandatory DNS intercept
          {"type": "field", "inboundTag": ["tun-proxy"], "port": 53, "network": "udp", "outboundTag": "dns-out"},
          // MANDATORY: Force everything (hotspot and tun) to use the proxy
          {"type": "field", "network": "tcp,udp", "outboundTag": "proxy"}
        ]
      }
    };

    return jsonEncode(config);
  }
}
