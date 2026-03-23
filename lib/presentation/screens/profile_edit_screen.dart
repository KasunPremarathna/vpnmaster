import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/vpn_profile.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  final VpnProfile? profile;
  const ProfileEditScreen({super.key, this.profile});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _server, _port, _user, _pass, _key, _sni, _dns, _payload;
  late VpnProtocol _protocol;
  late AuthType _authType;
  String _transportProtocol = 'tcp';

  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _server = TextEditingController(text: p?.server ?? '');
    _port = TextEditingController(text: p?.port.toString() ?? '22');
    _user = TextEditingController(text: p?.username ?? '');
    _pass = TextEditingController(text: p?.password ?? '');
    _key = TextEditingController(text: p?.privateKey ?? '');
    _sni = TextEditingController(text: p?.sni ?? '');
    _dns = TextEditingController(text: p?.dns ?? '');
    _payload = TextEditingController(text: p?.payload ?? '');
    _protocol = p?.protocol ?? VpnProtocol.ssh;
    _authType = p?.authType ?? AuthType.password;
    _transportProtocol = p?.xrayConfig?.network ?? 'tcp';
  }

  @override
  void dispose() {
    for (final c in [_name, _server, _port, _user, _pass, _key, _sni, _dns, _payload]) {
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
          TextButton(
            onPressed: _save,
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
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
            _field(_server, 'Server / Host', icon: Icons.dns_rounded,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            _field(_port, 'Port', icon: Icons.numbers, keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v!) == null ? 'Invalid port' : null),
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
                _field(_pass, 'Password', icon: Icons.lock_rounded, obscure: !_showPass,
                    suffix: IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPass = !_showPass)))
              else
                _field(_key, 'Private Key (PEM)', icon: Icons.key_rounded,
                    maxLines: 6, obscure: false),
            ],

            if (_protocol == VpnProtocol.vless ||
                _protocol == VpnProtocol.vmess ||
                _protocol == VpnProtocol.trojan) ...[
              _section('XRAY / Credentials'),
              _field(_user, 'UUID / Password', icon: Icons.fingerprint),
              const SizedBox(height: 16),
              _section('Transport Protocol'),
              _transportSelector(),
            ],

            const SizedBox(height: 16),
            _section('Optional'),
            _field(_payload, 'Custom Payload', icon: Icons.code_rounded, maxLines: 3),
            _field(_sni, 'SNI Override', icon: Icons.security_rounded),
            _field(_dns, 'Custom DNS', icon: Icons.wifi_rounded, hint: '1.1.1.1'),
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
            side: BorderSide(color: selected ? accent : Colors.grey.withValues(alpha: .3)),
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
                label: Text(a == AuthType.password ? 'Password' : 'Private Key'),
                selected: selected,
                selectedColor: accent.withValues(alpha: .2),
                side: BorderSide(color: selected ? accent : Colors.grey.withValues(alpha: .3)),
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
          label: Text(opt['label']!, style: TextStyle(fontWeight: selected ? FontWeight.bold : null)),
          selected: selected,
          selectedColor: accent.withValues(alpha: .2),
          side: BorderSide(color: selected ? accent : Colors.grey.withValues(alpha: .3)),
          labelStyle: TextStyle(color: selected ? accent : null),
          onSelected: (_) => setState(() => _transportProtocol = opt['value']!),
        );
      }).toList(),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final config = context.read<ConfigProvider>();
    XrayConfig? newXrayConfig = widget.profile?.xrayConfig;
    if (newXrayConfig != null) {
      newXrayConfig = XrayConfig(
        type: newXrayConfig.type,
        address: _server.text.trim(),
        port: int.parse(_port.text.trim()),
        uuid: _user.text.trim(),
        alterId: newXrayConfig.alterId,
        security: newXrayConfig.security,
        network: _transportProtocol,
        tls: newXrayConfig.tls,
        sni: _sni.text.trim().isEmpty ? newXrayConfig.sni : _sni.text.trim(),
        host: newXrayConfig.host,
        path: newXrayConfig.path,
        flow: newXrayConfig.flow,
        password: newXrayConfig.password,
        method: newXrayConfig.method,
        remark: newXrayConfig.remark,
      );
    } else if (_protocol == VpnProtocol.vless || _protocol == VpnProtocol.vmess || _protocol == VpnProtocol.trojan) {
      XrayType xtype = XrayType.vless;
      if (_protocol == VpnProtocol.vmess) xtype = XrayType.vmess;
      if (_protocol == VpnProtocol.trojan) xtype = XrayType.trojan;
      newXrayConfig = XrayConfig(
        type: xtype,
        address: _server.text.trim(),
        port: int.parse(_port.text.trim()),
        uuid: _user.text.trim(),
        network: _transportProtocol,
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
