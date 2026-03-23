import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/log_provider.dart';
import '../../services/log_service.dart';
import '../../core/theme/app_theme.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<LogProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          // Filter chip
          PopupMenuButton<LogLevel?>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: logs.setFilter,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: LogLevel.debug, child: Text('Debug')),
              const PopupMenuItem(value: LogLevel.info, child: Text('Info')),
              const PopupMenuItem(value: LogLevel.warning, child: Text('Warning')),
              const PopupMenuItem(value: LogLevel.error, child: Text('Error')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy all',
            onPressed: () {
              final text = logs.entries.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear',
            onPressed: logs.clear,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor:
            _autoScroll ? colors.accent : colors.card,
        onPressed: () => setState(() => _autoScroll = !_autoScroll),
        child: Icon(
          _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
          color: Colors.white,
          size: 18,
        ),
      ),
      body: logs.entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 60, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  Text('No logs yet', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: logs.entries.length,
              itemBuilder: (ctx, i) {
                final entry = logs.entries[i];
                return _LogTile(entry: entry);
              },
            ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(entry.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.formattedTime,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontFamily: 'monospace')),
          const SizedBox(width: 6),
          Text(entry.levelTag,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(entry.message,
                style: TextStyle(color: color.withValues(alpha: .85), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Color _colorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return Colors.grey;
      case LogLevel.info: return const Color(0xFF00D4FF);
      case LogLevel.warning: return const Color(0xFFFF9800);
      case LogLevel.error: return const Color(0xFFFF5252);
    }
  }
}
