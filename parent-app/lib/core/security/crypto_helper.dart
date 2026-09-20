import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CryptoHelper {
  static const String prefix = 'enc:v1:';
  static String familyPassphrase = 'ParentSecretPassphrase2026';
  static final _salt = utf8.encode('ParentalControlSalt2026');
  static SecretKey? _cachedKey;

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  static final _aesGcm = AesGcm.with256bits();

  static void setFamilyPassphrase(String passphrase) {
    if (passphrase.trim().isNotEmpty && passphrase != familyPassphrase) {
      familyPassphrase = passphrase.trim();
      _cachedKey = null;
    }
  }

  static Future<SecretKey> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(familyPassphrase)),
      nonce: _salt,
    );
    _cachedKey = secretKey;
    return secretKey;
  }

  /// Encrypt plaintext to `enc:v1:<iv_b64>:<cipher_b64>`
  static Future<String> encrypt(String plaintext) async {
    if (plaintext.trim().isEmpty) return plaintext;
    try {
      final key = await _getOrCreateKey();
      final plainBytes = utf8.encode(plaintext);
      final secretBox = await _aesGcm.encrypt(plainBytes, secretKey: key);

      final ivB64 = base64Encode(secretBox.nonce);
      // Combine ciphertext and 16-byte MAC tag to match Java/WebCrypto standard GCM output
      final combined = <int>[...secretBox.cipherText, ...secretBox.mac.bytes];
      final cipherB64 = base64Encode(combined);

      return '$prefix$ivB64:$cipherB64';
    } catch (_) {
      return plaintext;
    }
  }

  /// Decrypt `enc:v1:<iv_b64>:<cipher_b64>` back to plaintext
  static Future<String> decrypt(String text) async {
    if (!text.startsWith(prefix)) return text;
    try {
      final parts = text.substring(prefix.length).split(':');
      if (parts.length != 2) return text;

      final iv = base64Decode(parts[0]);
      final combined = base64Decode(parts[1]);
      if (combined.length < 16) return text;

      final cipherOnly = combined.sublist(0, combined.length - 16);
      final macBytes = combined.sublist(combined.length - 16);

      final key = await _getOrCreateKey();
      final secretBox = SecretBox(
        cipherOnly,
        nonce: iv,
        mac: Mac(macBytes),
      );

      final decryptedBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      return utf8.decode(decryptedBytes);
    } catch (_) {
      return text;
    }
  }
}
