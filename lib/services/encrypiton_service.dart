import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  // Use a secure 32-character key for AES-256
  final String _secretKey = 'my32lengthsupersecretkeyultratight!';

  String encryptData(String plainText) {
    final key = encrypt.Key.fromUtf8(_secretKey);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Combine IV and encrypted bytes for safe storage/transport
    return '${iv.base64}:${encrypted.base64}';
  }

  String decryptData(String encryptedText) {
    final parts = encryptedText.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

    final key = encrypt.Key.fromUtf8(_secretKey);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    return encrypter.decrypt(encrypted, iv: iv);
  }
}
