import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../screens/marketplace_feed_screen.dart';

class MarketplaceSection extends StatelessWidget {
  const MarketplaceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.userStream,
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.hasData && snapshot.data != null;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 32, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'VPN Marketplace',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isLoggedIn && snapshot.data!.role == 'agent')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AGENT',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Discover premium high-speed servers and VIP payloads uploaded by verified Community Agents.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (!isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await authService.signInWithGoogle();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to sign in: $e')),
                        );
                      }
                    },
                    icon: SizedBox(
                      width: 24,
                      height: 24,
                      child: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                        errorBuilder: (_, __, ___) => const Icon(Icons.login),
                      ),
                    ),
                    label: const Text(
                      'Sign In to Access',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MarketplaceFeedScreen(currentUser: snapshot.data!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.explore_rounded, color: Colors.white),
                    label: const Text(
                      'Open Marketplace Feed',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
