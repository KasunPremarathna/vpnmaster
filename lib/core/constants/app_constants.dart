// App-wide constants
class AppConstants {
  // Platform channel names
  static const String vpnChannel = 'com.vpnmaster/vpn';
  static const String statsChannel = 'com.vpnmaster/stats';

  // Config file extension
  static const String configExtension = '.vpm';

  // Encryption key length
  static const int aesKeyLength = 32; // 256-bit

  // Default DNS
  static const String defaultDns1 = '1.1.1.1';
  static const String defaultDns2 = '8.8.8.8';

  // Default proxy port
  static const int defaultProxyPort = 8080;
  static const int defaultSocksPort = 1080;

  // Reconnect settings
  static const int maxReconnectAttempts = 5;
  static const int reconnectDelaySeconds = 5;

  // URI schemes
  static const String nmVlessScheme = 'nm-vless://';
  static const String vmessScheme = 'vmess://';
  static const String vlessScheme = 'vless://';
  static const String trojanScheme = 'trojan://';
  static const String ssScheme = 'ss://';

  // Payload variable tokens
  static const String tokenHost = '[host]';
  static const String tokenPort = '[port]';
  static const String tokenUserAgent = '[user-agent]';

  // Default user agent
  static const String defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36';

  // Shared preferences keys
  static const String prefThemeMode = 'theme_mode';
  static const String prefActiveProfile = 'active_profile';
  static const String prefKillSwitch = 'kill_switch';
  static const String prefAutoReconnect = 'auto_reconnect';
  static const String prefAutoStart = 'auto_start';
  static const String prefCustomDns1 = 'custom_dns1';
  static const String prefCustomDns2 = 'custom_dns2';
  static const String prefSplitTunneling = 'split_tunneling';
  static const String prefExcludedApps = 'excluded_apps';
}
