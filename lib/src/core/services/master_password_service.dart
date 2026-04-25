import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class MasterPasswordData {
  final List<int> encryptedKey;
  final List<int> salt;
  final List<int> iv;
  final String verificationHash;

  MasterPasswordData({
    required this.encryptedKey,
    required this.salt,
    required this.iv,
    required this.verificationHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'encryptedKey': base64Encode(encryptedKey),
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'verificationHash': verificationHash,
    };
  }

  factory MasterPasswordData.fromJson(Map<String, dynamic> json) {
    return MasterPasswordData(
      encryptedKey: base64Decode(json['encryptedKey'] as String),
      salt: base64Decode(json['salt'] as String),
      iv: base64Decode(json['iv'] as String),
      verificationHash: json['verificationHash'] as String,
    );
  }
}

class MasterPasswordService {
  static const int _saltLength = 32;
  static const int _keyLength = 32;
  static const int _iterations = 100000;
  static const String _verificationString = 'fluxlyn_verification_v1';

  static List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  static List<int> generateIV() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  static Uint8List deriveKeyFromPassword(String password, List<int> salt) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = Uint8List.fromList(salt);
    
    final iterations = _iterations;
    final keyLength = _keyLength;
    
    final result = Uint8List(keyLength);
    var block = Uint8List(saltBytes.length + 4);
    block.setRange(0, saltBytes.length, saltBytes);
    
    var remaining = keyLength;
    var blockIndex = 1;
    var offset = 0;
    
    while (remaining > 0) {
      block[saltBytes.length] = (blockIndex >> 24) & 0xFF;
      block[saltBytes.length + 1] = (blockIndex >> 16) & 0xFF;
      block[saltBytes.length + 2] = (blockIndex >> 8) & 0xFF;
      block[saltBytes.length + 3] = blockIndex & 0xFF;
      
      var u = Hmac(sha256, passwordBytes).convert(block).bytes;
      var derivedBlock = Uint8List.fromList(u);
      
      for (var i = 1; i < iterations; i++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (var j = 0; j < derivedBlock.length; j++) {
          derivedBlock[j] ^= u[j];
        }
      }
      
      final copyLen = remaining < derivedBlock.length ? remaining : derivedBlock.length;
      result.setRange(offset, offset + copyLen, derivedBlock);
      
      remaining -= copyLen;
      offset += copyLen;
      blockIndex++;
    }
    
    return result;
  }

  static MasterPasswordData encryptDeviceKey(
    List<int> deviceKey,
    String password,
  ) {
    final salt = generateSalt();
    final iv = generateIV();
    final derivedKey = deriveKeyFromPassword(password, salt);

    final key = encrypt.Key(derivedKey);
    final encryptIV = encrypt.IV(Uint8List.fromList(iv));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(
      String.fromCharCodes(deviceKey),
      iv: encryptIV,
    );

    final verificationKey = deriveKeyFromPassword(password, salt);
    final verificationHash = _generateVerificationHash(verificationKey);

    return MasterPasswordData(
      encryptedKey: encrypted.bytes.toList(),
      salt: salt,
      iv: iv,
      verificationHash: verificationHash,
    );
  }

  static List<int>? decryptDeviceKey(
    MasterPasswordData data,
    String password,
  ) {
    try {
      final derivedKey = deriveKeyFromPassword(password, data.salt);

      final verificationHash = _generateVerificationHash(derivedKey);
      if (verificationHash != data.verificationHash) {
        return null;
      }

      final key = encrypt.Key(derivedKey);
      final encryptIV = encrypt.IV(Uint8List.fromList(data.iv));
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypt.Encrypted(Uint8List.fromList(data.encryptedKey));
      final decrypted = encrypter.decrypt(encrypted, iv: encryptIV);

      return decrypted.codeUnits;
    } catch (e) {
      return null;
    }
  }

  static bool verifyPassword(MasterPasswordData data, String password) {
    final derivedKey = deriveKeyFromPassword(password, data.salt);
    final verificationHash = _generateVerificationHash(derivedKey);
    return verificationHash == data.verificationHash;
  }

  static String _generateVerificationHash(Uint8List key) {
    final verificationBytes = utf8.encode(_verificationString);
    final hmac = Hmac(sha256, key);
    final hash = hmac.convert(verificationBytes);
    return hash.toString();
  }
}