import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/vpn_profile.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/config_service.dart';
import '../../data/models/payload_config.dart';

class ProfileEditScreen extends StatefulWidget {
  final VpnProfile? profile;
  const ProfileEditScreen({super.key, this.profile});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name,
      _server,
      _port,
      _user,
      _pass,
      _key,
      _sni,
      _dns,
      _payload,
      _wsPath,
      _wsHost;
  late VpnProtocol _protocol;
  late AuthType _authType;
  String _transportProtocol = 'tcp';
  String _tls = 'none';

  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _server = TextEditingController(text: p?.server ?? '');
    _port = TextEditingController(text: p?.port.toString() ?? '443');
    _user = TextEditingController(text: p?.username ?? '');
    _pass = TextEditingController(text: p?.password ?? '');
    _key = TextEditingController(text: p?.privateKey ?? '');
    _sni = TextEditingController(text: p?.sni ?? '');
    _dns = TextEditingController(text: p?.dns ?? '');
    _payload = TextEditingController(text: p?.payload ?? '');
    _wsPath = TextEditingController(text: p?.xrayConfig?.path ?? '');
    _wsHost = TextEditingController(text: p?.xrayConfig?.host ?? '');
    _protocol = p?.protocol ?? VpnProtocol.ssh;
    _authType = p?.authType ?? AuthType.password;
    _transportProtocol = p?.xrayConfig?.network ?? 'tcp';
    _tls = p?.xrayConfig?.tls ?? 'none';
    if (_tls.isEmpty) _tls = 'none';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _server,
      _port,
      _user,
      _pass,
      _key,
      _sni,
      _dns,
      _payload,
      _wsPath,
      _wsHost
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.profile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Profile' : 'New Profile'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.share_rounded, size: 22),
              tooltip: 'Export Profile',
              onPressed: () => _showExportDialog(context, widget.profile!),
            ),
          TextButton(
            onPressed: _save,
            child: const Text('SAVE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Basic'),
            _field(_name, 'Profile Name', icon: Icons.label_rounded),
            _field(_server, 'Server / Host',
                icon: Icons.dns_rounded,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            _field(_port, 'Port',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v!) == null ? 'Invalid port' : null),
            const SizedBox(height: 16),
            _section('Protocol'),
            _protocolSelector(),
            const SizedBox(height: 16),
            if (_protocol == VpnProtocol.ssh) ...[
              _section('Authentication'),
              _authTypeSelector(),
              const SizedBox(height: 8),
              _field(_user, 'Username', icon: Icons.person_rounded),
              if (_authType == AuthType.password)
                _field(_pass, 'Password',
                    icon: Icons.lock_rounded,
                    obscure: !_showPass,
                    suffix: IconButton(
                        icon: Icon(_showPass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _showPass = !_showPass)))
              else
                _field(_key, 'Private Key (PEM)',
                    icon: Icons.key_rounded, maxLines: 6, obscure: false),
            ],
            if (_protocol == VpnProtocol.vless ||
                _protocol == VpnProtocol.vmess ||
                _protocol == VpnProtocol.trojan) ...[
              _section('XRAY / Credentials'),
              _field(_user, 'UUID / Password', icon: Icons.fingerprint),
              const SizedBox(height: 16),
              _section('Transport Protocol'),
              _transportSelector(),
              if (_transportProtocol == 'ws') ...[
                const SizedBox(height: 16),
                _field(_wsHost, 'WebSocket Host', icon: Icons.cloud_outlined),
                _field(_wsPath, 'WebSocket Path',
                    icon: Icons.http_rounded, hint: '/path'),
              ],
              const SizedBox(height: 16),
              _section('TLS / Security'),
              _tlsSelector(),
            ],
            const SizedBox(height: 16),
            _section('Optional'),
            _field(_payload, 'Custom Payload',
                icon: Icons.code_rounded, maxLines: 3),
            _field(_sni, 'SNI Override (Comma separated for Auto Rotate)',
                icon: Icons.security_rounded, hint: 'sni1.com, sni2.com'),
            _field(_dns, 'Custom DNS',
                icon: Icons.wifi_rounded, hint: '1.1.1.1'),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).extension<AppColors>()!.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
    String? hint,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            suffixIcon: suffix,
          ),
        ),
      );

  Widget _protocolSelector() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: VpnProtocol.values.map((p) {
          final selected = _protocol == p;
          final accent = Theme.of(context).extension<AppColors>()!.accent;
          return ChoiceChip(
            label: Text(p.name.toUpperCase()),
            selected: selected,
            selectedColor: accent.withValues(alpha: .2),
            side: BorderSide(
                color: selected ? accent : Colors.grey.withValues(alpha: .3)),
            labelStyle: TextStyle(color: selected ? accent : null),
            onSelected: (_) => setState(() => _protocol = p),
          );
        }).toList(),
      );

  Widget _authTypeSelector() => Row(
        children: AuthType.values.map((a) {
          final selected = _authType == a;
          final accent = Theme.of(context).extension<AppColors>()!.accent;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label:
                    Text(a == AuthType.password ? 'Password' : 'Private Key'),
                selected: selected,
                selectedColor: accent.withValues(alpha: .2),
                side: BorderSide(
                    color:
                        selected ? accent : Colors.grey.withValues(alpha: .3)),
                labelStyle: TextStyle(color: selected ? accent : null),
                onSelected: (_) => setState(() => _authType = a),
              ),
            ),
          );
        }).toList(),
      );

  Widget _transportSelector() {
    final options = [
      {'label': 'TCP', 'value': 'tcp'},
      {'label': 'WS', 'value': 'ws'},
      {'label': 'gRPC (Best)', 'value': 'grpc'},
      {'label': 'XHTTP', 'value': 'xhttp'},
    ];
    final accent = Theme.of(context).extension<AppColors>()!.accent;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = _transportProtocol == opt['value'];
        return ChoiceChip(
          label: Text(opt['label']!,
              style: TextStyle(fontWeight: selected ? FontWeight.bold : null)),
          selected: selected,
          selectedColor: accent.withValues(alpha: .2),
          side: BorderSide(
              color: selected ? accent : Colors.grey.withValues(alpha: .3)),
          labelStyle: TextStyle(color: selected ? accent : null),
          onSelected: (_) => setState(() => _transportProtocol = opt['value']!),
        );
      }).toList(),
    );
  }

  Widget _tlsSelector() {
    final options = ['none', 'tls', 'xtls', 'reality'];
    final accent = Theme.of(context).extension<AppColors>()!.accent;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = _tls == opt;
        return ChoiceChip(
          label: Text(opt.toUpperCase(),
              style: TextStyle(fontWeight: selected ? FontWeight.bold : null)),
          selected: selected,
          selectedColor: accent.withValues(alpha: .2),
          side: BorderSide(
              color: selected ? accent : Colors.grey.withValues(alpha: .3)),
          labelStyle: TextStyle(color: selected ? accent : null),
          onSelected: (_) => setState(() => _tls = opt),
        );
      }).toList(),
    );
  }

  void _showExportDialog(BuildContext context, VpnProfile profile) {
    bool lockHwid = false;
    String password = '';

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Export Config',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Securely share your payload and configurations as an encrypted .VPM file.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Password (Optional)',
                      prefixIcon: Icon(Icons.password_rounded, size: 18),
                    ),
                    obscureText: true,
                    onChanged: (v) => password = v.trim(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Lock to this Device (HWID)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'Prevents stealing. Payload can only be imported back onto this exact phone.',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    value: lockHwid,
                    onChanged: (v) => setDialogState(() => lockHwid = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final bundle = ExportBundle(
                      profiles: [profile],
                      appConfig: AppConfig(),
                      payloads: [],
                    );
                    try {
                      await ConfigService().shareConfig(
                        bundle: bundle,
                        password: password,
                        lockToDevice: lockHwid,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: const Text('SHARE .VPM'),
                ),
              ],
            );
          });
        });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final config = context.read<ConfigProvider>();
    XrayConfig? newXrayConfig = widget.profile?.xrayConfig;
    final oldXray = newXrayConfig;
    if (oldXray != null) {
      newXrayConfig = XrayConfig(
        type: oldXray.type,
        address: _server.text.trim(),
        port: int.parse(_port.text.trim()),
        uuid: _user.text.trim(),
        alterId: oldXray.alterId,
        security: oldXray.security,
        network: _transportProtocol,
        tls: _tls == 'none' ? '' : _tls,
        sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
        host: _wsHost.text.trim().isEmpty ? null : _wsHost.text.trim(),
        path: _wsPath.text.trim().isEmpty ? null : _wsPath.text.trim(),
        flow: oldXray.flow,
        password: oldXray.password,
        method: oldXray.method,
        remark: oldXray.remark,
      );
    }

    final profile = VpnProfile(
      id: widget.profile?.id,
      name: _name.text.trim().isEmpty ? _server.text : _name.text.trim(),
      server: _server.text.trim(),
      port: int.parse(_port.text.trim()),
      protocol: _protocol,
      authType: _authType,
      username: _user.text.trim(),
      password: _pass.text,
      privateKey: _key.text.trim(),
      payload: _payload.text.trim().isEmpty ? null : _payload.text.trim(),
      sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
      dns: _dns.text.trim().isEmpty ? null : _dns.text.trim(),
      xrayConfig: newXrayConfig,
    );

    if (widget.profile != null) {
      config.updateProfile(profile);
    } else {
      config.addProfile(profile);
    }
    Navigator.pop(context);
  }
}
