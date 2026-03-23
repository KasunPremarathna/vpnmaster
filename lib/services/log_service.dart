import 'dart:async';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  String get levelTag {
    switch (level) {
      case LogLevel.debug: return '[D]';
      case LogLevel.info: return '[I]';
      case LogLevel.warning: return '[W]';
      case LogLevel.error: return '[E]';
    }
  }

  String get formattedTime {
    final t = timestamp;
    return '${_p(t.hour)}:${_p(t.minute)}:${_p(t.second)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  @override
  String toString() => '$formattedTime $levelTag $message';
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final _controller = StreamController<LogEntry>.broadcast();
  final List<LogEntry> _history = [];

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get history => List.unmodifiable(_history);

  void log(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );
    _history.add(entry);
    if (_history.length > 2000) _history.removeAt(0);
    _controller.add(entry);
  }

  void debug(String msg) => log(msg, level: LogLevel.debug);
  void info(String msg) => log(msg, level: LogLevel.info);
  void warning(String msg) => log(msg, level: LogLevel.warning);
  void error(String msg) => log(msg, level: LogLevel.error);

  void clear() => _history.clear();

  void dispose() => _controller.close();
}
