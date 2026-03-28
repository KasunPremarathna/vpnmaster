import 'package:flutter/material.dart';
import '../../services/marketplace_service.dart';
import '../../data/models/access_request.dart';
import '../../data/models/marketplace_item.dart';
import '../../data/models/user.dart';
import 'create_item_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final AppUser user;
  const SellerDashboardScreen({super.key, required this.user});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final MarketplaceService _marketplace = MarketplaceService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seller Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'REQUESTS'),
              Tab(text: 'MY ITEMS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsTab(),
            _buildItemsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateItemScreen(seller: widget.user)),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<List<AccessRequest>>(
      stream: _marketplace.getSellerRequests(widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No access requests yet', style: TextStyle(color: Colors.grey.shade500)));
        }

        final requests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, i) => _RequestCard(request: requests[i]),
        );
      },
    );
  }

  Widget _buildItemsTab() {
    return StreamBuilder<List<MarketplaceItem>>(
      stream: _marketplace.getSellerItems(widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('You haven\'t listed any items yet', style: TextStyle(color: Colors.grey.shade500)));
        }

        final items = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${item.vpnType} • ${item.simType} • ${item.isFree ? 'FREE' : 'PAID'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(item.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String itemId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This will permanently remove the listing from the marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              _marketplace.deleteItem(itemId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AccessRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 16),
                const SizedBox(width: 8),
                // ignore: prefer_const_constructors
                Text('User: \${request.userId.length > 8 ? request.userId.substring(0, 8) : request.userId}...', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                _statusBadge(request.status),
              ],
            ),
            const SizedBox(height: 12),
            // ignore: prefer_const_constructors
            Text('Item ID: \${request.itemId}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => MarketplaceService().rejectRequest(request.id),
                      child: const Text('REJECT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showApproveDialog(context),
                      child: const Text('APPROVE'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'approved') color = Colors.green;
    if (status == 'rejected') color = Colors.red;
    if (status == 'pending') color = Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showApproveDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Access'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Config Link (VLESS/VMESS)', hintText: 'vless://...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                MarketplaceService().approveRequest(request.id, controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SUBMIT & APPROVE'),
          ),
        ],
      ),
    );
  }
}
