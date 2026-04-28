import 'dart:convert';
import 'dart:isolate';
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

class _DeriveKeyParams {
  final String password;
  final List<int> salt;

  _DeriveKeyParams(this.password, this.salt);
}

class _EncryptParams {
  final List<int> deviceKey;
  final String password;

  _EncryptParams(this.deviceKey, this.password);
}

class _DecryptParams {
  final MasterPasswordData data;
  final String password;

  _DecryptParams(this.data, this.password);
}

class _VerifyParams {
  final MasterPasswordData data;
  final String password;

  _VerifyParams(this.data, this.password);
}

const int _kSaltLength = 32;
const int _kKeyLength = 32;
const int _kIterations = 100000;
const String _kVerificationString = 'fluxlyn_verification_v1';

Uint8List _deriveKeyFromPasswordSync(String password, List<int> salt) {
  final passwordBytes = utf8.encode(password);
  final saltBytes = Uint8List.fromList(salt);

  final iterations = _kIterations;
  final keyLength = _kKeyLength;

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

Uint8List _deriveKeyIsolate(_DeriveKeyParams params) {
  return _deriveKeyFromPasswordSync(params.password, params.salt);
}

List<int>? _decryptIsolate(_DecryptParams params) {
  try {
    final derivedKey = _deriveKeyFromPasswordSync(params.password, params.data.salt);

    final verificationHash = _generateVerificationHashSync(derivedKey);
    if (verificationHash != params.data.verificationHash) {
      return null;
    }

    final key = encrypt.Key(derivedKey);
    final encryptIV = encrypt.IV(Uint8List.fromList(params.data.iv));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypt.Encrypted(Uint8List.fromList(params.data.encryptedKey));
    final decrypted = encrypter.decrypt(encrypted, iv: encryptIV);

    return decrypted.codeUnits;
  } catch (e) {
    return null;
  }
}

MasterPasswordData _encryptIsolate(_EncryptParams params) {
  final salt = List<int>.generate(_kSaltLength, (_) => Random.secure().nextInt(256));
  final iv = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final derivedKey = _deriveKeyFromPasswordSync(params.password, salt);

  final key = encrypt.Key(derivedKey);
  final encryptIV = encrypt.IV(Uint8List.fromList(iv));
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  final encrypted = encrypter.encrypt(
    String.fromCharCodes(params.deviceKey),
    iv: encryptIV,
  );

  final verificationKey = _deriveKeyFromPasswordSync(params.password, salt);
  final verificationHash = _generateVerificationHashSync(verificationKey);

  return MasterPasswordData(
    encryptedKey: encrypted.bytes.toList(),
    salt: salt,
    iv: iv,
    verificationHash: verificationHash,
  );
}

bool _verifyIsolate(_VerifyParams params) {
  final derivedKey = _deriveKeyFromPasswordSync(params.password, params.data.salt);
  final verificationHash = _generateVerificationHashSync(derivedKey);
  return verificationHash == params.data.verificationHash;
}

String _generateVerificationHashSync(Uint8List key) {
  final verificationBytes = utf8.encode(_kVerificationString);
  final hmac = Hmac(sha256, key);
  final hash = hmac.convert(verificationBytes);
  return hash.toString();
}

class MasterPasswordService {
  static List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(_kSaltLength, (_) => random.nextInt(256));
  }

  static List<int> generateIV() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  static Future<Uint8List> deriveKeyFromPassword(String password, List<int> salt) async {
    return await Isolate.run(() => _deriveKeyIsolate(_DeriveKeyParams(password, salt)));
  }

  static Future<MasterPasswordData> encryptDeviceKey(
    List<int> deviceKey,
    String password,
  ) async {
    return await Isolate.run(() => _encryptIsolate(_EncryptParams(deviceKey, password)));
  }

  static Future<List<int>?> decryptDeviceKey(
    MasterPasswordData data,
    String password,
  ) async {
    return await Isolate.run(() => _decryptIsolate(_DecryptParams(data, password)));
  }

  static Future<bool> verifyPassword(MasterPasswordData data, String password) async {
    return await Isolate.run(() => _verifyIsolate(_VerifyParams(data, password)));
  }
}