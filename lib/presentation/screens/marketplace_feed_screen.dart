import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/config_provider.dart';
import '../../data/models/vpn_profile.dart';
import 'agent_dashboard_screen.dart';
import 'user_requests_screen.dart';

class MarketplaceFeedScreen extends StatelessWidget {
  final AppUser currentUser;

  const MarketplaceFeedScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'My Premium Requests',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserRequestsScreen(currentUser: currentUser))),
          ),
          if (currentUser.role == 'agent')
            IconButton(
              icon: const Icon(Icons.dashboard_customize_rounded),
              tooltip: 'Agent Dashboard',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentDashboardScreen(currentUser: currentUser))),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('marketplace_items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load marketplace.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No servers available yet.\nCheck back later!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _MarketplaceItemCard(
                id: docs[index].id,
                data: data,
                currentUser: currentUser,
              );
            },
          );
        },
      ),
    );
  }
}

class _MarketplaceItemCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final AppUser currentUser;

  const _MarketplaceItemCard({required this.id, required this.data, required this.currentUser});

  @override
  State<_MarketplaceItemCard> createState() => _MarketplaceItemCardState();
}

class _MarketplaceItemCardState extends State<_MarketplaceItemCard> {
  bool _isRequesting = false;

  Future<void> _handleImport(BuildContext context) async {
    final payload = widget.data['payloadData'] as String?;
    if (payload == null || payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid config payload.')));
      return;
    }

    try {
      final configProvider = context.read<ConfigProvider>();
      final importedProfile = VpnProfile.fromUri(payload);
      configProvider.addProfile(importedProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server added to your list!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _requestPaidAccess(BuildContext context) async {
    setState(() => _isRequesting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final requestRef = FirebaseFirestore.instance.collection('purchase_requests').doc();
      await requestRef.set({
        'itemId': widget.id,
        'itemTitle': widget.data['title'],
        'agentId': widget.data['agentId'],
        'userId': widget.currentUser.id,
        'userName': widget.currentUser.name,
        'userEmail': widget.currentUser.email,
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Request sent to Agent! Awaiting approval.'), backgroundColor: Colors.blueAccent),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Request failed: $e')));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] ?? 'Unknown Server';
    final desc = widget.data['description'] ?? '';
    final isFree = widget.data['isFree'] ?? true;
    final agentName = widget.data['agentName'] ?? 'Unknown Agent';
    final imageUrl = widget.data['imageUrl'];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null && imageUrl.toString().isNotEmpty)
            Image.network(
              imageUrl,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 50, color: Colors.grey[800], child: const Icon(Icons.image_not_supported)),
            )
          else
            Container(
              height: 80,
              color: Colors.blueGrey[900],
              child: const Center(child: Icon(Icons.cloud, size: 40, color: Colors.white24)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFree ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isFree ? 'FREE' : 'PREMIUM',
                        style: TextStyle(
                          color: isFree ? Colors.green : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('By $agentName', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isFree
                      ? ElevatedButton.icon(
                          onPressed: () => _handleImport(context),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('One-Click Import'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _isRequesting ? null : () => _requestPaidAccess(context),
                          icon: _isRequesting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_open_rounded),
                          label: Text(_isRequesting ? 'Requesting...' : 'Request Access'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                        ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
