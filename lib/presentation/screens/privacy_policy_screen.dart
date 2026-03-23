import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policy for Velora VPN Proxy', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('Effective Date: March 2026', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 20),
            _section(context, colors, '1. Introduction',
                'Welcome to Velora VPN Proxy. We are deeply committed to protecting your privacy and ensuring your data remains secure. This Privacy Policy details exactly what information we collect, how it is used, and how we comply with Google Play Developer Policies.'),
            _section(context, colors, '2. Strict No-Logs Policy',
                'Velora VPN Proxy strictly adheres to a zero-logs policy. We do NOT track, collect, or store your browsing history, traffic destination, data content, or DNS queries. Your internet activity remains exclusively yours.'),
            _section(context, colors, '3. Permissions & Data Usage',
                '''To function legally and securely, this application requests the following Android permissions:

• VpnService (VPN): Core to the app. Used exclusively to create a secure, encrypted device-level tunnel to remote servers you configure. We do not extract, monitor, or manipulate personal data passing through this tunnel.
• Location & Nearby Devices: Requested ONLY when you activate the "Local WiFi Hotspot" feature to share your VPN connection. Android requires these permissions to securely broadcast a local AP network. We NEVER use these permissions to track your geographic location.
• Notifications: Used to provide essential foreground service indicators and push notifications regarding app updates via Firebase and OneSignal.'''),
            _section(context, colors, '4. Information We Collect',
                'We do not require you to create an account or provide personal information to use the core VPN. All VPN profile configurations, keys, and session metrics are encrypted and stored locally on your device. Firebase/OneSignal may collect aggregated, anonymous crash reports and device tokens solely for app stability and update notifications.'),
            _section(context, colors, '5. Third-Party Services',
                'We do not sell, rent, or trade your data. Velora VPN Proxy does not integrate third-party advertising or analytics SDKs that profile users. External tools (OneSignal, Firebase) are strictly utilized for delivery functionality and performance monitoring.'),
            _section(context, colors, '6. Security Measures',
                'All app data is encrypted via robust AES-256 protocols. Your configurations are safeguarded against unauthorized extraction. However, remember that no digital transmission is 100% immune; we urge users to enforce secure passwords and safe browsing.' ),
            _section(context, colors, '7. Children\'s Privacy',
                'Velora VPN Proxy is not intended for individuals under the age of 13. We do not knowingly collect personal information from children.'),
            _section(context, colors, '8. Changes to this Policy',
                'We reserve the right to modify this Privacy Policy as our services evolve or to comply with updated Google Play regulations. We will notify you of any material changes via in-app notifications.'),
            _section(context, colors, '9. Contact Us',
                'For privacy-related inquiries, data deletion requests, or support, please contact us at: privacy@veloravpn.app'),
            const SizedBox(height: 40),
            Center(
              child: Text('© 2026 Velora VPN Proxy. All rights reserved.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, AppColors colors, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.6, fontSize: 14)),
        ],
      ),
    );
  }
}
