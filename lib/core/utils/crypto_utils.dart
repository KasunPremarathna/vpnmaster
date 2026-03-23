import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/digests/sha256.dart';

class CryptoUtils {
  /// Derives a 256-bit key from a password using SHA-256.
  static Uint8List deriveKey(String password) {
    final digest = SHA256Digest();
    final data = Uint8List.fromList(utf8.encode(password));
    return digest.process(data);
  }

  /// Encrypts [plainText] with AES-256-CBC using [password].
  /// Returns base64(iv + ciphertext).
  static String encrypt(String plainText, String password) {
    final keyBytes = deriveKey(password);
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Prepend IV to ciphertext
    final combined = Uint8List(16 + encrypted.bytes.length)
      ..setRange(0, 16, iv.bytes)
      ..setRange(16, 16 + encrypted.bytes.length, encrypted.bytes);
    return base64Encode(combined);
  }

  /// Decrypts base64(iv + ciphertext) with AES-256-CBC using [password].
  static String decrypt(String encryptedBase64, String password) {
    final keyBytes = deriveKey(password);
    final key = enc.Key(keyBytes);
    final combined = base64Decode(encryptedBase64);
    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final cipherBytes = Uint8List.fromList(combined.sublist(16));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
  }

  /// Decrypts a base64 encoded string using the hardcoded NetMod AES-ECB key.
  static String decryptNetmod(String base64Str) {
    try {
      final key = enc.Key.fromUtf8('_netsyna_netmod_');
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: 'PKCS7'));
      final encryptedBytes = enc.Encrypted.fromBase64(base64Str);
      return encrypter.decrypt(encryptedBytes);
    } catch (_) {
      return '';
    }
  }
}
