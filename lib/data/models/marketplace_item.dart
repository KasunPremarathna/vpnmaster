import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/marketplace_service.dart';

class MarketplaceItem {
  final String id;
  final String name;
  final String description;
  final String vpnType; // VLESS, VMESS, TROJAN
  final String simType; // Dialog, Mobitel, etc.
  final bool isFree;
  final String sellerId;
  final String? contactLink;
  final String? configLink;
  final DateTime createdAt;

  MarketplaceItem({
    required this.id,
    required this.name,
    required this.description,
    required this.vpnType,
    required this.simType,
    required this.isFree,
    required this.sellerId,
    this.contactLink,
    this.configLink,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MarketplaceItem.fromMap(Map<String, dynamic> data, String id) {
    return MarketplaceItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      vpnType: data['vpn_type'] ?? '',
      simType: data['sim_type'] ?? '',
      isFree: data['is_free'] ?? false,
      sellerId: data['seller_id'] ?? '',
      contactLink: data['contact_link'],
      configLink: data['config_link'] != null ? MarketplaceService.decryptLink(data['config_link']) : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'vpn_type': vpnType,
      'sim_type': simType,
      'is_free': isFree,
      'seller_id': sellerId,
      'contact_link': contactLink,
      'config_link': configLink,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
