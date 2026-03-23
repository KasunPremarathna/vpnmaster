import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/log_service.dart';

class LogProvider extends ChangeNotifier {
  final LogService _logService = LogService();
  final List<LogEntry> _entries = [];
  LogLevel? _filter;

  List<LogEntry> get entries => _filter == null
      ? List.unmodifiable(_entries)
      : _entries.where((e) => e.level == _filter).toList();

  LogLevel? get filter => _filter;

  LogProvider() {
    _entries.addAll(_logService.history);
    _logService.stream.listen((entry) {
      _entries.add(entry);
      if (_entries.length > 2000) _entries.removeAt(0);
      notifyListeners();
    });
  }

  void setFilter(LogLevel? level) {
    _filter = level;
    notifyListeners();
  }

  void clear() {
    _logService.clear();
    _entries.clear();
    notifyListeners();
  }
}

class ThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final raw = await _storage.read(key: 'theme_mode');
    _themeMode = raw == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> toggle() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _storage.write(
        key: 'theme_mode', value: isDark ? 'dark' : 'light');
    notifyListeners();
  }
}
