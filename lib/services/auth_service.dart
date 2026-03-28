import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/models/user.dart';

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
        // New user - default to 'pending' role to trigger role selection
        return AppUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'New User',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL,
          role: 'pending', 
        );
      }
    });
  }

  Future<void> createUserProfile(AppUser user, String selectedRole) async {
    final newUser = AppUser(
      id: user.id,
      name: user.name,
      email: user.email,
      photoUrl: user.photoUrl,
      role: selectedRole,
    );
    await _db.collection('users').doc(user.id).set(newUser.toMap());
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final firebase.AuthCredential credential = firebase.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Google Sign-In failed. Please ensure SHA-1 [E6:92:D5:D7:12:AD:11:0B:51:7A:F9:BD:C5:79:98:CC:13:C4:70:E0] is added to Firebase.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
