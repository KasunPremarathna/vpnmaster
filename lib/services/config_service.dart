import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/crypto_utils.dart';
import '../data/models/vpn_profile.dart';
import '../data/models/payload_config.dart';

class ExportBundle {
  final List<VpnProfile> profiles;
  final AppConfig appConfig;
  final List<PayloadConfig> payloads;

  ExportBundle({
    required this.profiles,
    required this.appConfig,
    required this.payloads,
  });

  Map<String, dynamic> toJson() => {
        'version': 1,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'appConfig': appConfig.toJson(),
        'payloads': payloads.map((p) => p.toJson()).toList(),
      };

  factory ExportBundle.fromJson(Map<String, dynamic> json) => ExportBundle(
        profiles: (json['profiles'] as List? ?? [])
            .map((e) => VpnProfile.fromJson(e as Map<String, dynamic>))
            .toList(),
        appConfig: json['appConfig'] != null
            ? AppConfig.fromJson(json['appConfig'] as Map<String, dynamic>)
            : AppConfig(),
        payloads: (json['payloads'] as List? ?? [])
            .map((e) => PayloadConfig.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ConfigService {
  /// Export bundle to a .vpm file (optionally AES-encrypted).
  Future<String?> exportConfig({
    required ExportBundle bundle,
    String? password,
  }) async {
    try {
      final json = jsonEncode(bundle.toJson());
      final content = password != null && password.isNotEmpty
          ? CryptoUtils.encrypt(json, password)
          : json;

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/vpnmaster_$timestamp.vpm');
      await file.writeAsString(content);
      return file.path;
    } catch (e) {
      throw Exception('Export failed: $e');
    }
  }

  /// Import bundle from a .vpm file (optionally AES-encrypted).
  Future<ExportBundle?> importConfig({String? password}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) return null;

      final content = await File(path).readAsString();
      String jsonStr;
      if (password != null && password.isNotEmpty) {
        jsonStr = CryptoUtils.decrypt(content, password);
      } else {
        jsonStr = content;
      }
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ExportBundle.fromJson(json);
    } catch (e) {
      throw Exception('Import failed: $e');
    }
  }

  /// Share a config file via system share sheet.
  Future<void> shareConfig({
    required ExportBundle bundle,
    String? password,
  }) async {
    final path = await exportConfig(bundle: bundle, password: password);
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: 'VPN Master Config');
  }

  /// Parse any URI scheme from clipboard string.
  /// Returns a VpnProfile or null if unrecognised.
  static VpnProfile? parseClipboardUri(String text) {
    var trimmed = text.trim();
    if (trimmed.startsWith('"') || trimmed.startsWith("'")) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.endsWith('"') || trimmed.endsWith("'")) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    trimmed = trimmed.trim();

    if (trimmed.startsWith('nm-vless://')) {
      return VpnProfile.fromNmVless(trimmed);
    } else if (trimmed.startsWith('vless://')) {
      return VpnProfile.fromVlessUri(trimmed);
    } else if (trimmed.startsWith('vmess://')) {
      final xray = XrayConfig.fromVmessUri(trimmed);
      if (xray == null) return null;
      return VpnProfile(
        name: xray.remark ?? 'VMess Import',
        server: xray.address,
        port: xray.port,
        protocol: VpnProtocol.vmess,
        username: xray.uuid,
        xrayConfig: xray,
      );
    } else if (trimmed.startsWith('trojan://')) {
      final xray = XrayConfig.fromTrojanUri(trimmed);
      if (xray == null) return null;
      return VpnProfile(
        name: xray.remark ?? 'Trojan Import',
        server: xray.address,
        port: xray.port,
        protocol: VpnProtocol.trojan,
        password: xray.password ?? '',
        xrayConfig: xray,
      );
    }
    return null;
  }
}
