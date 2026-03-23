import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Tutorial & Guide', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildHeroHeader(colors),
          const SizedBox(height: 24),
          _buildExpansionTile(
            context: context,
            icon: Icons.power_rounded,
            title: '1. Connecting to the VPN',
            content: 'To use the app, first open the drawer menu and go to the "Servers" list to select a VPN profile. You can either pick a default server or build your own custom profile using the "Payload Builder". Once selected, return to the Home Screen and tap the large CONNECT button.',
          ),
          const SizedBox(height: 12),
          _buildExpansionTile(
            context: context,
            icon: Icons.security_rounded,
            title: '2. SSH vs Xray (V2Ray)',
            content: '• Secure Shell (SSH): Great for basic tunneling and bypassing firewalls using HTTP custom payloads.\n• V2Ray / Xray: Modern proxy protocols like VMess, VLess, and Trojan. These offer better encryption, multiplexing, and advanced transport masking (like gRPC and WebSockets). If you are bypassing deep packet inspection, V2Ray options are recommended.',
          ),
          const SizedBox(height: 12),
          _buildExpansionTile(
            context: context,
            icon: Icons.code_rounded,
            title: '3. What is a Custom Payload?',
            content: 'A custom payload is a special HTTP injection string used to trick your ISP\'s firewall or billing system into thinking you are accessing allowed zero-rated websites (like social media or university sites), while actually tunneling internet traffic directly to the VPN.\n\nThe Custom Payload field allows you to type raw HTTP headers before the SSH handshake happens.',
          ),
          const SizedBox(height: 12),
          _buildExpansionTile(
            context: context,
            icon: Icons.build_circle_rounded,
            title: '4. How to write a Payload',
            content: 'A standard HTTP Proxy CONNECT payload looks like this:\n\nCONNECT [host_port] HTTP/1.1[crlf]Host: zero-rated-domain.com[crlf]X-Online-Host: zero-rated-domain.com[crlf]Connection: Keep-Alive[crlf][crlf]\n\n• [host_port] is automatically replaced by your VPN server IP and port.\n• [crlf] translates to the standard carriage-return line-feed used in HTTP definitions.\n• "zero-rated-domain.com" should be exactly replaced by the website URL that your ISP allows you to browse for free.',
          ),
          const SizedBox(height: 12),
          _buildExpansionTile(
            context: context,
            icon: Icons.router_rounded,
            title: '5. Transport Protocols',
            content: 'When configuring Xray protocols, you must choose a transport protocol within the Profile Edit screen:\n\n• TCP: Standard raw internet traffic stream.\n• WS (WebSocket): Disguises proxy traffic as standard website WebSockets (like a chat app). Can be placed behind Cloudflare CDNs effortlessly.\n• gRPC (Best): A modern, low-latency stream. Highly recommended for heavy multimedia tracking or gaming due to built-in multiplexing.\n• XHTTP: HTTP/2+ masking.',
          ),
          const SizedBox(height: 32),
          Center(
            child: Text('Velora VPN Proxy v1.0', 
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ]
      ),
      child: Column(
        children: [
          Icon(Icons.school_rounded, size: 64, color: colors.accent),
          const SizedBox(height: 16),
          const Text(
            'Master your Connection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Learn how to properly secure, mask, and bypass network restrictions using advanced payload routing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: colors.accent, size: 26),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          iconColor: colors.accentGreen,
          collapsedIconColor: Colors.grey.shade500,
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                content,
                style: TextStyle(color: Colors.grey.shade300, height: 1.6, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
