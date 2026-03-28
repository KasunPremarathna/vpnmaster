import 'package:flutter/material.dart';
import '../../services/marketplace_service.dart';
import '../../data/models/marketplace_item.dart';
import '../../data/models/user.dart';
import '../../core/theme/app_theme.dart';

class CreateItemScreen extends StatefulWidget {
  final AppUser seller;
  const CreateItemScreen({super.key, required this.seller});

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final MarketplaceService _marketplace = MarketplaceService();
  
  String _name = '';
  String _description = '';
  String _vpnType = 'VLESS';
  String _simType = 'Dialog';
  bool _isFree = false;
  String _contactLink = '';
  String _configLink = '';
  bool _isSaving = false;

  final List<String> _vpnTypes = ['VLESS', 'VMESS', 'Trojan'];
  final List<String> _simTypes = ['Dialog', 'Mobitel', 'Hutch', 'SLT', 'Airtel', 'Other'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);
    try {
      final item = MarketplaceItem(
        id: '', // Firestore will assign an ID
        name: _name,
        description: _description,
        vpnType: _vpnType,
        simType: _simType,
        isFree: _isFree,
        sellerId: widget.seller.id,
        contactLink: _contactLink.isNotEmpty ? _contactLink : null,
        configLink: _configLink.isNotEmpty ? _configLink : null,
      );

      await _marketplace.addItem(item);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('List New Config')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Basic Info'),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g., Dialog Unlimited VLESS'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Explain server speed, locations, etc.'),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _description = v!,
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle('Technical Details'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _vpnType,
                      decoration: const InputDecoration(labelText: 'VPN Type'),
                      items: _vpnTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _vpnType = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _simType,
                      decoration: const InputDecoration(labelText: 'SIM Type'),
                      items: _simTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _simType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('Pricing & Contact'),
              SwitchListTile(
                title: const Text('Is Free?'),
                subtitle: const Text('If false, users must request access.'),
                value: _isFree,
                onChanged: (v) => setState(() => _isFree = v),
                activeThumbColor: colors.accent,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Contact Link (Optional)', hintText: 't.me/yourusername or wa.me/...'),
                onSaved: (v) => _contactLink = v ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'VPN Config Link', hintText: 'vless://... or vmess://...'),
                validator: (v) {
                  if (_isFree && (v == null || v.isEmpty)) return 'Required for free items';
                  return null;
                },
                onSaved: (v) => _configLink = v ?? '',
              ),
              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('CREATE LISTING', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
    );
  }
}
