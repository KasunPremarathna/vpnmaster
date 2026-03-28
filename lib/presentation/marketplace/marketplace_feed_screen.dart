import 'package:flutter/material.dart';
import '../../services/marketplace_service.dart';
import '../../data/models/marketplace_item.dart';
import '../../data/models/user.dart';
import '../../core/theme/app_theme.dart';
import 'item_details_screen.dart';
import 'seller_dashboard_screen.dart';

class MarketplaceFeedScreen extends StatefulWidget {
  final AppUser? currentUser;
  const MarketplaceFeedScreen({super.key, this.currentUser});

  @override
  State<MarketplaceFeedScreen> createState() => _MarketplaceFeedScreenState();
}

class _MarketplaceFeedScreenState extends State<MarketplaceFeedScreen> {
  final MarketplaceService _marketplace = MarketplaceService();
  String _selectedVpnType = 'All';
  String _selectedSimType = 'All';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isSeller = widget.currentUser?.role == 'seller';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (isSeller)
            IconButton(
              icon: const Icon(Icons.dashboard_rounded),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          SellerDashboardScreen(user: widget.currentUser!))),
              tooltip: 'Seller Dashboard',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(colors),
          Expanded(
            child: StreamBuilder<List<MarketplaceItem>>(
              stream: _marketplace.getItems(),
              builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _emptyState(colors, 'Network Error: Please check your connection');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState(colors);
                }

                final items = snapshot.data!.where((item) {
                  final vpnMatch = _selectedVpnType == 'All' ||
                      item.vpnType == _selectedVpnType;
                  final simMatch = _selectedSimType == 'All' ||
                      item.simType == _selectedSimType;
                  return vpnMatch && simMatch;
                }).toList();

                if (items.isEmpty) {
                  return _emptyState(colors, 'No items matching filters');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      _ItemCard(item: items[i], user: widget.currentUser),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.card.withAlpha(12),
      child: Row(
        children: [
          _filterChip(
              'VPN',
              ['All', 'VLESS', 'VMESS', 'Trojan'],
              _selectedVpnType,
              (val) => setState(() => _selectedVpnType = val)),
          const SizedBox(width: 8),
          _filterChip(
              'SIM',
              ['All', 'Dialog', 'Mobitel', 'Hutch', 'Airtel'],
              _selectedSimType,
              (val) => setState(() => _selectedSimType = val)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, List<String> options, String selected,
      Function(String) onSelect) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      // ignore: prefer_const_constructors
      child: Chip(
        // ignore: prefer_const_constructors
        label: Row(
          mainAxisSize: MainAxisSize.min,
          // ignore: prefer_const_literals_to_create_immutables
        ),
      ),
      itemBuilder: (context) => options
          .map((opt) => PopupMenuItem(value: opt, child: Text(opt)))
          .toList(),
    );
  }

  Widget _emptyState(AppColors colors, [String msg = 'No items available']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final MarketplaceItem item;
  final AppUser? user;
  const _ItemCard({required this.item, this.user});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ItemDetailsScreen(item: item, currentUser: user))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.vpn_lock_rounded, color: colors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('\${item.vpnType} • \${item.simType}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isFree
                          ? Colors.green.withAlpha(25)
                          : Colors.amber.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.isFree ? 'FREE' : 'PAID',
                      style: TextStyle(
                          color: item.isFree ? Colors.green : Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
