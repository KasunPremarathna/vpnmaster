import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/config_provider.dart';
import '../../data/models/vpn_profile.dart';

class UserRequestsScreen extends StatelessWidget {
  final AppUser currentUser;

  const UserRequestsScreen({super.key, required this.currentUser});

  Future<void> _handleImport(BuildContext context, String payload) async {
    try {
      final configProvider = context.read<ConfigProvider>();
      final importedProfile = VpnProfile.fromUri(payload);
      configProvider.addProfile(importedProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VIP Server imported to your list!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Premium Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('purchase_requests')
            .where('userId', isEqualTo: currentUser.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have not requested any paid servers yet.', style: TextStyle(color: Colors.grey)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final isApproved = data['status'] == 'APPROVED';

              return ListTile(
                tileColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  isApproved ? Icons.verified_user_rounded : Icons.hourglass_empty_rounded,
                  color: isApproved ? Colors.green : Colors.amber,
                ),
                title: Text(data['itemTitle'] ?? 'Premium Node'),
                subtitle: Text('Status: ${data['status']}'),
                trailing: isApproved
                    ? ElevatedButton.icon(
                        onPressed: () => _handleImport(context, data['payloadData']),
                        icon: const Icon(Icons.download),
                        label: const Text('Import'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
