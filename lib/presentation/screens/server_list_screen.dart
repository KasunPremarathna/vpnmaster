import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../data/models/vpn_profile.dart';
import '../../core/theme/app_theme.dart';
import 'profile_edit_screen.dart';
import '../../providers/vpn_provider.dart' as import_vpn_provider;

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});
  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servers'),
        actions: [
          // Clipboard import button
          IconButton(
            icon: const Icon(Icons.content_paste_rounded),
            tooltip: 'Import from Clipboard',
            onPressed: () => _importFromClipboard(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Server',
            onPressed: () => _openEdit(context, null),
          ),
        ],
      ),
      body: config.profiles.isEmpty
          ? _emptyState(colors)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: config.profiles.length,
              itemBuilder: (context, i) {
                final profile = config.profiles[i];
                final isSelected = config.selectedProfile?.id == profile.id;
                return _ProfileCard(
                  profile: profile,
                  isSelected: isSelected,
                  onTap: () {
                    config.selectProfile(profile.id);
                    Navigator.pop(context);
                  },
                  onEdit: () => _openEdit(context, profile),
                  onDelete: () => _confirmDelete(context, config, profile),
                  onDuplicate: () => config.duplicateProfile(profile.id),
                );
              },
            ),
    );
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    final config = context.read<ConfigProvider>();
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (!context.mounted) return;
        _snack(context, 'Clipboard is empty');
        return;
      }
      config.importFromClipboard(text);
      if (!context.mounted) return;
      _snack(context, '✓ Profile imported from clipboard!');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Failed: $e');
    }
  }

  void _openEdit(BuildContext context, VpnProfile? profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditScreen(profile: profile)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, ConfigProvider config, VpnProfile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Delete "${profile.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) config.deleteProfile(profile.id);
  }

  Widget _emptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 72, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text('No servers yet',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Tap + to add a server or paste from clipboard',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ProfileCard extends StatefulWidget {
  final VpnProfile profile;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _ProfileCard({
    required this.profile,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _isPinging = false;
  int? _lastPingMs;

  Future<void> _doPing() async {
    if (_isPinging) return;
    setState(() { _isPinging = true; _lastPingMs = null; });
    final vpn = context.read<import_vpn_provider.VpnProvider>();
    final ms = await vpn.checkPing(widget.profile);
    if (!mounted) return;
    setState(() {
      _isPinging = false;
      _lastPingMs = ms;
    });
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected ? colors.accent.withValues(alpha: .15) : colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: widget.isSelected ? colors.accent : colors.accent.withValues(alpha: .1),
                width: widget.isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              _ProtocolBadge(protocol: widget.profile.protocolLabel),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.profile.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${widget.profile.server}:${widget.profile.port}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                    if (widget.profile.sni != null && widget.profile.sni!.isNotEmpty)
                      Text('SNI: ${widget.profile.sni}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (widget.isSelected) Icon(Icons.check_circle_rounded, color: colors.accent),
              if (!widget.isSelected)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPinging)
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_lastPingMs != null)
                      Text(
                        _lastPingMs! < 0 ? 'Timeout' : '${_lastPingMs}ms',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _lastPingMs! < 0
                                ? Colors.red
                                : _lastPingMs! < 300
                                    ? Colors.green
                                    : Colors.orange),
                      ),
                    IconButton(
                      icon: const Icon(Icons.network_ping_rounded, size: 20),
                      color: Colors.grey.shade600,
                      onPressed: _doPing,
                    ),
                  ],
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  switch (v) {
                    case 'edit': widget.onEdit(); break;
                    case 'duplicate': widget.onDuplicate(); break;
                    case 'delete': widget.onDelete(); break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  final String protocol;
  const _ProtocolBadge({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final color = _colorForProtocol(protocol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Text(protocol,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Color _colorForProtocol(String p) {
    switch (p) {
      case 'SSH': return const Color(0xFF00D4FF);
      case 'VMess': return const Color(0xFFFF9800);
      case 'VLess': return const Color(0xFF9C27B0);
      case 'Trojan': return const Color(0xFFF44336);
      case 'SS': return const Color(0xFF4CAF50);
      default: return const Color(0xFF607D8B);
    }
  }
}
