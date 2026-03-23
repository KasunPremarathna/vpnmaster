import 'package:uuid/uuid.dart';

enum PayloadMethod { get, post, connect }

class PayloadConfig {
  final String id;
  String name;
  PayloadMethod method;
  Map<String, String> headers;
  String body;
  bool useSni;
  String? sniOverride;

  PayloadConfig({
    String? id,
    required this.name,
    this.method = PayloadMethod.connect,
    Map<String, String>? headers,
    this.body = '',
    this.useSni = false,
    this.sniOverride,
  })  : id = id ?? const Uuid().v4(),
        headers = headers ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'method': method.name,
        'headers': headers,
        'body': body,
        'useSni': useSni,
        'sniOverride': sniOverride,
      };

  factory PayloadConfig.fromJson(Map<String, dynamic> json) => PayloadConfig(
        id: json['id'] as String?,
        name: json['name'] as String,
        method: PayloadMethod.values.firstWhere(
          (e) => e.name == json['method'],
          orElse: () => PayloadMethod.connect,
        ),
        headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
        body: json['body'] as String? ?? '',
        useSni: json['useSni'] as bool? ?? false,
        sniOverride: json['sniOverride'] as String?,
      );

  /// Replace dynamic tokens: [host], [port], [user-agent]
  String buildPayload({
    required String host,
    required String port,
    String userAgent = 'Mozilla/5.0 (Linux; Android 12)',
  }) {
    var result = body
        .replaceAll('[host]', host)
        .replaceAll('[port]', port)
        .replaceAll('[user-agent]', userAgent);

    if (useSni && sniOverride != null && sniOverride!.isNotEmpty) {
      result = result.replaceAll('[sni]', sniOverride!);
    }
    return result;
  }

  String get methodString => method.name.toUpperCase();
}

class AppConfig {
  bool killSwitch;
  bool splitTunneling;
  List<String> excludedApps;
  bool autoReconnect;
  bool autoStart;
  String dns1;
  String dns2;
  bool darkMode;

  AppConfig({
    this.killSwitch = false,
    this.splitTunneling = false,
    List<String>? excludedApps,
    this.autoReconnect = true,
    this.autoStart = false,
    this.dns1 = '1.1.1.1',
    this.dns2 = '8.8.8.8',
    this.darkMode = true,
  }) : excludedApps = excludedApps ?? [];

  Map<String, dynamic> toJson() => {
        'killSwitch': killSwitch,
        'splitTunneling': splitTunneling,
        'excludedApps': excludedApps,
        'autoReconnect': autoReconnect,
        'autoStart': autoStart,
        'dns1': dns1,
        'dns2': dns2,
        'darkMode': darkMode,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        killSwitch: json['killSwitch'] as bool? ?? false,
        splitTunneling: json['splitTunneling'] as bool? ?? false,
        excludedApps: List<String>.from(json['excludedApps'] as List? ?? []),
        autoReconnect: json['autoReconnect'] as bool? ?? true,
        autoStart: json['autoStart'] as bool? ?? false,
        dns1: json['dns1'] as String? ?? '1.1.1.1',
        dns2: json['dns2'] as String? ?? '8.8.8.8',
        darkMode: json['darkMode'] as bool? ?? true,
      );
}
