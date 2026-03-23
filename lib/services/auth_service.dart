import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String role; // 'user' or 'agent'

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.role = 'user',
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      role: data['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
    };
  }
}

class AuthService {
  final firebase.FirebaseAuth _auth = firebase.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<AppUser?> get userStream {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      final doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, doc.id);
      } else {
        // Create new user profile on first login
        final newUser = AppUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Unknown',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
          role: 'user',
        );
        await _db.collection('users').doc(firebaseUser.uid).set(newUser.toMap());
        return newUser;
      }
    });
  }

  /// Google Sign-In using the standard OAuth credential flow
  Future<void> signInWithGoogle() async {
    try {
      // Use Firebase Auth's built-in Google provider for web-compatible flow
      final googleProvider = firebase.GoogleAuthProvider();
      await _auth.signInWithProvider(googleProvider);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
