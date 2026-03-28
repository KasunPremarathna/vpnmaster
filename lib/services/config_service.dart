import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/utils/crypto_utils.dart';
import '../data/models/vpn_profile.dart';
import '../data/models/payload_config.dart';

class ExportBundle {
  final List<VpnProfile> profiles;
  final AppConfig appConfig;
  final List<PayloadConfig> payloads;
  final String? targetHwid;

  ExportBundle({
    required this.profiles,
    required this.appConfig,
    required this.payloads,
    this.targetHwid,
  });

  Map<String, dynamic> toJson() => {
        'version': 1,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'appConfig': appConfig.toJson(),
        'payloads': payloads.map((p) => p.toJson()).toList(),
        if (targetHwid != null) 'targetHwid': targetHwid,
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
        targetHwid: json['targetHwid'] as String?,
      );

  ExportBundle copyWith({String? targetHwid}) => ExportBundle(
        profiles: profiles,
        appConfig: appConfig,
        payloads: payloads,
        targetHwid: targetHwid ?? this.targetHwid,
      );
}

class ConfigService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final auth = await deviceInfo.androidInfo;
      return auth.id;
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor ?? 'unknown';
    }
    return 'unknown_device';
  }

  /// Export bundle to a .vpm file (optionally AES-encrypted and HWID locked).
  Future<String?> exportConfig({
    required ExportBundle bundle,
    String? password,
    bool lockToDevice = false,
  }) async {
    try {
      if (lockToDevice) {
        final hwid = await getDeviceId();
        bundle = bundle.copyWith(targetHwid: hwid);
      }

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

  /// Import bundle from a .vpm or .ehi file (optionally AES-encrypted).
  Future<ExportBundle?> importConfig({String? password}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) return null;

      String content;
      try {
        content = await File(path).readAsString();
      } catch (_) {
        throw Exception('The file is encrypted or in an unsupported binary format. Official HTTP Injector .ehi files cannot be natively imported. Only plain-text proxy URIs or .vpm config bundles are supported.');
      }

      // Try parsing as a raw URI text file first
      final singleProfile = parseClipboardUri(content);
      if (singleProfile != null) {
        return ExportBundle(
          profiles: [singleProfile],
          appConfig: AppConfig(),
          payloads: [],
        );
      }

      // Otherwise try as standard encrypted/plain JSON bundle
      String jsonStr;
      if (password != null && password.isNotEmpty) {
        jsonStr = CryptoUtils.decrypt(content, password);
      } else {
        jsonStr = content;
      }
      
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final bundle = ExportBundle.fromJson(json);

      if (bundle.targetHwid != null) {
        final currentHwid = await getDeviceId();
        if (bundle.targetHwid != currentHwid) {
          throw Exception('Hardware ID Mismatch: This configuration was explicitly locked to another device by the creator.');
        }
      }

      return bundle;
    } catch (e) {
      if (e.toString().contains('unsupported binary format')) rethrow;
      throw Exception('Import failed: $e');
    }
  }

  /// Share a config file via system share sheet.
  Future<void> shareConfig({
    required ExportBundle bundle,
    String? password,
    bool lockToDevice = false,
  }) async {
    final path = await exportConfig(bundle: bundle, password: password, lockToDevice: lockToDevice);
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: 'VPN Master Profile Config');
  }

  /// Parse any URI scheme from clipboard string.
  /// Returns a VpnProfile or null if unrecognised.
  static VpnProfile? parseClipboardUri(String text) {
    // Extract URI using RegEx so text like "Here is the profile: vless://..." is caught correctly.
    final regex = RegExp(r'(nm-vless|vless|vmess|trojan)://\S+');
    final match = regex.firstMatch(text.trim());
    
    if (match == null) return null;
    
    var trimmed = match.group(0)!;
    // Strip trailing quotes if the user copied them directly
    if (trimmed.endsWith('"') || trimmed.endsWith("'")) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

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
