import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class AgentDashboardScreen extends StatelessWidget {
  final AppUser currentUser;

  const AgentDashboardScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agent Control Panel'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_to_drive_rounded), text: 'Upload Server'),
              Tab(icon: Icon(Icons.mark_email_unread_rounded), text: 'Pending Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UploadServerTab(agent: currentUser),
            _PendingRequestsTab(agent: currentUser),
          ],
        ),
      ),
    );
  }
}

class _UploadServerTab extends StatefulWidget {
  final AppUser agent;
  const _UploadServerTab({required this.agent});

  @override
  State<_UploadServerTab> createState() => _UploadServerTabState();
}

class _UploadServerTabState extends State<_UploadServerTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController();
  final _imageCtrl = TextEditingController(); // For simplicity, accepting Image URLs directly
  bool _isFree = true;
  bool _isUploading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      await FirebaseFirestore.instance.collection('marketplace_items').add({
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
        'imageUrl': _imageCtrl.text,
        'isFree': _isFree,
        'payloadData': _isFree ? _payloadCtrl.text : '', // Hide payload if paid
        'agentId': widget.agent.id,
        'agentName': widget.agent.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server Uploaded!'), backgroundColor: Colors.green));
      _titleCtrl.clear();
      _descCtrl.clear();
      _payloadCtrl.clear();
      _imageCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Publish New Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Listing Title', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description / Features', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageCtrl,
              decoration: const InputDecoration(labelText: 'Banner Image URL (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Is this a Free Server?'),
              subtitle: Text(_isFree ? 'Users can one-click import this payload.' : 'Users must request access. Payload is hidden.'),
              value: _isFree,
              onChanged: (v) => setState(() => _isFree = v),
            ),
            const SizedBox(height: 16),
            if (_isFree)
              TextFormField(
                controller: _payloadCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Paste vmess:// or vless:// URI here', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty && _isFree ? 'Required for free nodes' : null,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isUploading ? const CircularProgressIndicator() : const Text('PUBLISH TO MARKETPLACE', style: TextStyle(fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}

class _PendingRequestsTab extends StatelessWidget {
  final AppUser agent;
  const _PendingRequestsTab({required this.agent});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('purchase_requests')
          .where('agentId', isEqualTo: agent.id)
          .where('status', isEqualTo: 'PENDING')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No pending requests.'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text('${data['itemTitle']} Request'),
              subtitle: Text('From: ${data['userName']} (${data['userEmail']})'),
              trailing: ElevatedButton(
                onPressed: () => _approvePrompt(context, doc.id),
                child: const Text('Approve'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approvePrompt(BuildContext context, String requestId) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the secure payload (vless/vmess) you generated specific to this user.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              final nav = Navigator.of(context);
              await FirebaseFirestore.instance.collection('purchase_requests').doc(requestId).update({
                'status': 'APPROVED',
                'payloadData': ctrl.text,
                'approvedAt': FieldValue.serverTimestamp(),
              });
              nav.pop();
            },
            child: const Text('Submit Approval'),
          )
        ],
      ),
    );
  }
}
