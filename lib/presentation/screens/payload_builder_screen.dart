import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/payload_config.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class PayloadBuilderScreen extends StatefulWidget {
  final PayloadConfig? existing;
  const PayloadBuilderScreen({super.key, this.existing});
  @override
  State<PayloadBuilderScreen> createState() => _PayloadBuilderScreenState();
}

class _PayloadBuilderScreenState extends State<PayloadBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _sniCtrl = TextEditingController();
  final _previewCtrl = TextEditingController();
  final _testHost = TextEditingController(text: 'example.com');
  final _testPort = TextEditingController(text: '443');

  PayloadMethod _method = PayloadMethod.connect;
  bool _useSni = false;
  Map<String, String> _headers = {};

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _bodyCtrl.text = e.body;
      _sniCtrl.text = e.sniOverride ?? '';
      _method = e.method;
      _useSni = e.useSni;
      _headers = Map.from(e.headers);
    }
    _bodyCtrl.addListener(_updatePreview);
    _testHost.addListener(_updatePreview);
    _testPort.addListener(_updatePreview);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _bodyCtrl, _sniCtrl, _previewCtrl, _testHost, _testPort]) {
      c.dispose();
    }
    super.dispose();
  }

  void _updatePreview() {
    final payload = PayloadConfig(
      name: '',
      method: _method,
      body: _bodyCtrl.text,
      useSni: _useSni,
      sniOverride: _sniCtrl.text,
    );
    _previewCtrl.text = payload.buildPayload(
      host: _testHost.text,
      port: _testPort.text,
      userAgent: AppConstants.defaultUserAgent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payload Builder'),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Name
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Payload Name',
              prefixIcon: Icon(Icons.label_rounded),
            ),
          ),
          const SizedBox(height: 20),

          // Method selector
          _sectionLabel('Method', colors),
          Row(
            children: PayloadMethod.values.map((m) {
              final sel = _method == m;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m.name.toUpperCase()),
                    selected: sel,
                    selectedColor: colors.accent.withValues(alpha: .2),
                    side: BorderSide(color: sel ? colors.accent : Colors.grey.withValues(alpha: .3)),
                    labelStyle: TextStyle(color: sel ? colors.accent : null),
                    onSelected: (_) => setState(() { _method = m; _updatePreview(); }),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Body editor
          _sectionLabel('Payload Body', colors),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Token buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      AppConstants.tokenHost,
                      AppConstants.tokenPort,
                      AppConstants.tokenUserAgent,
                      '[sni]',
                    ].map((token) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(token,
                            style: TextStyle(color: colors.accent, fontSize: 12)),
                        backgroundColor: colors.accent.withValues(alpha: .1),
                        side: BorderSide(color: colors.accent.withValues(alpha: .3)),
                        onPressed: () {
                          final ctrl = _bodyCtrl;
                          final pos = ctrl.selection.baseOffset;
                          final text = ctrl.text;
                          final newText = pos < 0
                              ? text + token
                              : text.substring(0, pos) + token + text.substring(pos);
                          ctrl.value = ctrl.value.copyWith(
                            text: newText,
                            selection: TextSelection.collapsed(offset: pos < 0 ? newText.length : pos + token.length),
                          );
                          _updatePreview();
                        },
                      ),
                    )).toList(),
                  ),
                ),
                const Divider(height: 1),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 6,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'CONNECT [host]:[port] HTTP/1.1\nHost: [host]',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SNI Override
          Row(
            children: [
              Expanded(child: _sectionLabel('SNI Override', colors)),
              Switch(value: _useSni, onChanged: (v) => setState(() { _useSni = v; _updatePreview(); })),
            ],
          ),
          if (_useSni)
            TextFormField(
              controller: _sniCtrl,
              decoration: const InputDecoration(
                labelText: 'SNI Hostname',
                prefixIcon: Icon(Icons.security_rounded),
              ),
            ),
          const SizedBox(height: 20),

          // Preview
          _sectionLabel('Preview', colors),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _testHost,
                  decoration: const InputDecoration(labelText: 'Test Host'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _testPort,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _previewCtrl.text.isEmpty ? 'Preview appears here' : _previewCtrl.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: _previewCtrl.text.isEmpty ? Colors.grey : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: _previewCtrl.text)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, AppColors colors) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );

  void _save() {
    final config = context.read<ConfigProvider>();
    final payload = PayloadConfig(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim().isEmpty ? 'Payload ${DateTime.now().millisecondsSinceEpoch}' : _nameCtrl.text.trim(),
      method: _method,
      headers: _headers,
      body: _bodyCtrl.text,
      useSni: _useSni,
      sniOverride: _useSni ? _sniCtrl.text.trim() : null,
    );

    if (widget.existing != null) {
      config.updatePayload(payload);
    } else {
      config.addPayload(payload);
    }
    Navigator.pop(context);
  }
}
