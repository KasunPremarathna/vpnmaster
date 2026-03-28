import 'package:flutter/material.dart';
import '../../data/models/marketplace_item.dart';
import '../../data/models/user.dart';
import '../../services/marketplace_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemDetailsScreen extends StatefulWidget {
  final MarketplaceItem item;
  final AppUser? currentUser;
  const ItemDetailsScreen({super.key, required this.item, this.currentUser});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final MarketplaceService _marketplace = MarketplaceService();
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colors),
            const SizedBox(height: 32),
            _buildDetailRow('VPN Type', item.vpnType, Icons.security_rounded, colors),
            _buildDetailRow('SIM Type', item.simType, Icons.sim_card_rounded, colors),
            _buildDetailRow('Price', item.isFree ? 'FREE' : 'PAID', Icons.payments_rounded, colors),
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(item.description, style: TextStyle(color: Colors.grey.shade400, height: 1.5)),
            const SizedBox(height: 48),
            _buildActionButtons(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: colors.accent.withAlpha(25), shape: BoxShape.circle),
          child: Icon(Icons.vpn_lock_rounded, size: 48, color: colors.accent),
        ),
        const SizedBox(height: 16),
        Center(child: Text(widget.item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppColors colors) {
    if (widget.currentUser == null) {
      return const Center(child: Text('Login to request access', style: TextStyle(color: Colors.grey)));
    }

    if (widget.item.isFree) {
      final canImport = widget.item.configLink != null && widget.item.configLink!.isNotEmpty;
      return ElevatedButton.icon(
        onPressed: canImport ? () => _importConfig(widget.item.configLink) : null,
        icon: const Icon(Icons.download_rounded),
        label: Text(canImport ? 'IMPORT FREE CONFIG' : 'NO CONFIG LINK AVAILABLE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size(double.infinity, 56),
        ),
      );
    }

    return StreamBuilder<List>(
      stream: FirebaseFirestore.instance.collection('access_requests')
          .where('user_id', isEqualTo: widget.currentUser!.id)
          .where('item_id', isEqualTo: widget.item.id)
          .snapshots()
          .map((s) => s.docs),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Network error checking request status', style: TextStyle(color: Colors.red, fontSize: 12)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return ElevatedButton(
            onPressed: _isRequesting ? null : _requestAccess,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
            child: _isRequesting 
              ? const CircularProgressIndicator(color: Colors.white) 
              : const Text('REQUEST ACCESS'),
          );
        }

        final request = snapshot.data!.first.data() as Map<String, dynamic>;
        final status = request['status'];

        if (status == 'pending') {
          return const Center(child: Text('Request Pending Approval', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)));
        } else if (status == 'approved') {
          return ElevatedButton.icon(
            onPressed: () => _importConfig(MarketplaceService.decryptLink(request['access_link'])),
            icon: const Icon(Icons.download_rounded),
            label: const Text('IMPORT APPROVED CONFIG'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 56)),
          );
        } else {
          return const Center(child: Text('Request Rejected', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)));
        }
      },
    );
  }

  Future<void> _requestAccess() async {
    setState(() => _isRequesting = true);
    try {
      await _marketplace.requestAccess(widget.currentUser!.id, widget.item.id, widget.item.sellerId);
    } catch (e) {
      // ignore: prefer_const_constructors
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _importConfig(String? link) {
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid configuration link')));
      return;
    }
    // Logic to add to ConfigProvider would go here
    final displayLink = link.length > 15 ? '${link.substring(0, 15)}...' : link;
    // ignore: prefer_const_constructors
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully imported: $displayLink')));
  }
}
