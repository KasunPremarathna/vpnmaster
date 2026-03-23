import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/vpn_profile.dart';
import '../data/models/payload_config.dart';
import '../services/config_service.dart';
import '../services/log_service.dart';
import 'dart:convert';

class ConfigProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _log = LogService();

  List<VpnProfile> _profiles = [];
  List<PayloadConfig> _payloads = [];
  AppConfig _appConfig = AppConfig();
  String? _selectedProfileId;

  List<VpnProfile> get profiles => List.unmodifiable(_profiles);
  List<PayloadConfig> get payloads => List.unmodifiable(_payloads);
  AppConfig get appConfig => _appConfig;
  VpnProfile? get selectedProfile =>
      _profiles.where((p) => p.id == _selectedProfileId).firstOrNull;

  Future<void> loadAll() async {
    await Future.wait([_loadProfiles(), _loadPayloads(), _loadAppConfig()]);
    notifyListeners();
  }

  // ── Profiles ───────────────────────────────────────────────
  Future<void> _loadProfiles() async {
    try {
      final raw = await _storage.read(key: 'profiles');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _profiles = list.map((e) => VpnProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
      _selectedProfileId = await _storage.read(key: 'selected_profile');
    } catch (e) {
      _log.error('Failed to load profiles: $e');
    }
  }

  Future<void> _saveProfiles() async {
    final raw = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    await _storage.write(key: 'profiles', value: raw);
  }

  void addProfile(VpnProfile profile) {
    _profiles.add(profile);
    _saveProfiles();
    notifyListeners();
    _log.info('Profile added: ${profile.name}');
  }

  void updateProfile(VpnProfile profile) {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _profiles[idx] = profile;
      _saveProfiles();
      notifyListeners();
    }
  }

  void deleteProfile(String id) {
    _profiles.removeWhere((p) => p.id == id);
    if (_selectedProfileId == id) _selectedProfileId = null;
    _saveProfiles();
    notifyListeners();
    _log.info('Profile deleted: $id');
  }

  void selectProfile(String id) {
    _selectedProfileId = id;
    _storage.write(key: 'selected_profile', value: id);
    notifyListeners();
  }

  void duplicateProfile(String id) {
    final original = _profiles.firstWhere((p) => p.id == id);
    final copy = original.copyWith(name: '${original.name} (copy)');
    addProfile(copy);
  }

  /// Import a profile parsed from clipboard URI
  void importFromClipboard(String clipText) {
    final profile = ConfigService.parseClipboardUri(clipText);
    if (profile != null) {
      addProfile(profile);
      _log.info('Imported from clipboard: ${profile.name}');
    } else {
      _log.warning('No recognisable VPN URI in clipboard');
      throw Exception('Unrecognised URI format in clipboard');
    }
  }

  // ── Payloads ───────────────────────────────────────────────
  Future<void> _loadPayloads() async {
    try {
      final raw = await _storage.read(key: 'payloads');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _payloads = list.map((e) => PayloadConfig.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _log.error('Failed to load payloads: $e');
    }
  }

  Future<void> _savePayloads() async {
    final raw = jsonEncode(_payloads.map((p) => p.toJson()).toList());
    await _storage.write(key: 'payloads', value: raw);
  }

  void addPayload(PayloadConfig p) {
    _payloads.add(p);
    _savePayloads();
    notifyListeners();
  }

  void updatePayload(PayloadConfig p) {
    final idx = _payloads.indexWhere((x) => x.id == p.id);
    if (idx >= 0) {
      _payloads[idx] = p;
      _savePayloads();
      notifyListeners();
    }
  }

  void deletePayload(String id) {
    _payloads.removeWhere((p) => p.id == id);
    _savePayloads();
    notifyListeners();
  }

  // ── AppConfig ──────────────────────────────────────────────
  Future<void> _loadAppConfig() async {
    try {
      final raw = await _storage.read(key: 'app_config');
      if (raw != null) {
        _appConfig = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> saveAppConfig(AppConfig config) async {
    _appConfig = config;
    await _storage.write(key: 'app_config', value: jsonEncode(config.toJson()));
    notifyListeners();
  }

  // ── Import/Export ──────────────────────────────────────────
  Future<void> exportAll(ConfigService svc, {String? password}) async {
    final bundle = ExportBundle(
      profiles: _profiles,
      appConfig: _appConfig,
      payloads: _payloads,
    );
    await svc.exportConfig(bundle: bundle, password: password);
    _log.info('Config exported successfully');
  }

  Future<void> importAll(ConfigService svc, {String? password}) async {
    final bundle = await svc.importConfig(password: password);
    if (bundle == null) return;
    _profiles = bundle.profiles;
    _payloads = bundle.payloads;
    _appConfig = bundle.appConfig;
    await _saveProfiles();
    await _savePayloads();
    await saveAppConfig(_appConfig);
    _log.info('Config imported: ${_profiles.length} profiles');
    notifyListeners();
  }
}
