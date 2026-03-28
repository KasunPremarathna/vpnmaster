import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../data/models/marketplace_item.dart';
import '../data/models/access_request.dart';

class MarketplaceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Use a fixed key for demonstration. In production, this should be more secure.
  static final _key = encrypt.Key.fromUtf8('32_chars_long_key_for_aes_enc_32');
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static String encryptLink(String link) {
    return _encrypter.encrypt(link, iv: _iv).base64;
  }

  static String decryptLink(String encrypted) {
    try {
      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      // If decryption fails, it's likely already plain text (migration case)
      return encrypted;
    }
  }

  // ── Items ──────────────────────────────────────────────────
  Stream<List<MarketplaceItem>> getItems() {
    return _db.collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarketplaceItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addItem(MarketplaceItem item) async {
    final data = item.toMap();
    if (item.configLink != null) {
      data['config_link'] = encryptLink(item.configLink!);
    }
    await _db.collection('items').add(data);
  }

  Future<void> deleteItem(String itemId) async {
    await _db.collection('items').doc(itemId).delete();
  }

  Stream<List<MarketplaceItem>> getSellerItems(String sellerId) {
    return _db.collection('items')
        .where('seller_id', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MarketplaceItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ── Access Requests ─────────────────────────────────────────
  Stream<List<AccessRequest>> getUserRequests(String userId) {
    return _db.collection('access_requests')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AccessRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<AccessRequest>> getSellerRequests(String sellerId) {
    return _db.collection('access_requests')
        .where('seller_id', isEqualTo: sellerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AccessRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> requestAccess(String userId, String itemId, String sellerId) async {
    await _db.collection('access_requests').add({
      'user_id': userId,
      'item_id': itemId,
      'seller_id': sellerId,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRequest(String requestId, String configLink) async {
    final encrypted = encryptLink(configLink);
    await _db.collection('access_requests').doc(requestId).update({
      'status': 'approved',
      'access_link': encrypted,
      'approved_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await _db.collection('access_requests').doc(requestId).update({
      'status': 'rejected',
    });
  }
}
