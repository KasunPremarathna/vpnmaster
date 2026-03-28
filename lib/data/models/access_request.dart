import 'package:cloud_firestore/cloud_firestore.dart';

class AccessRequest {
  final String id;
  final String userId;
  final String itemId;
  final String sellerId;
  final String status; // pending, approved, rejected
  final String? accessLink; // encrypted
  final DateTime createdAt;
  final DateTime? approvedAt;

  AccessRequest({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.sellerId,
    required this.status,
    this.accessLink,
    DateTime? createdAt,
    this.approvedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AccessRequest.fromMap(Map<String, dynamic> data, String id) {
    return AccessRequest(
      id: id,
      userId: data['user_id'] ?? '',
      itemId: data['item_id'] ?? '',
      sellerId: data['seller_id'] ?? '',
      status: data['status'] ?? 'pending',
      accessLink: data['access_link'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (data['approved_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'item_id': itemId,
      'seller_id': sellerId,
      'status': status,
      'access_link': accessLink,
      'created_at': Timestamp.fromDate(createdAt),
      'approved_at': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    };
  }
}
