import 'dart:typed_data';
import '../models/known_host_model.dart';
import '../services/storage_service.dart';

enum HostKeyVerificationResult {
  trusted,
  unknown,
  mismatch,
}

class HostKeyVerificationInfo {
  final String host;
  final int port;
  final String keyType;
  final Uint8List fingerprint;
  final KnownHostModel? storedKey;

  HostKeyVerificationInfo({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    this.storedKey,
  });

  String get displayFingerprint =>
      KnownHostModel.fingerprintToDisplay(fingerprint);

  String get storedDisplayFingerprint =>
      storedKey?.displayFingerprint ?? '';
}

class HostKeyVerificationService {
  final StorageService _storageService;

  HostKeyVerificationService(this._storageService);

  HostKeyVerificationResult verify(
    String host,
    int port,
    String keyType,
    Uint8List fingerprint,
  ) {
    final storedKey = _storageService.getKnownHost(host, port);

    if (storedKey == null) {
      return HostKeyVerificationResult.unknown;
    }

    final storedFingerprint = KnownHostModel.fingerprintFromHex(storedKey.fingerprint);

    if (_fingerprintsMatch(fingerprint, storedFingerprint) &&
        storedKey.keyType == keyType) {
      return HostKeyVerificationResult.trusted;
    }

    return HostKeyVerificationResult.mismatch;
  }

  HostKeyVerificationInfo getVerificationInfo(
    String host,
    int port,
    String keyType,
    Uint8List fingerprint,
  ) {
    final storedKey = _storageService.getKnownHost(host, port);
    return HostKeyVerificationInfo(
      host: host,
      port: port,
      keyType: keyType,
      fingerprint: fingerprint,
      storedKey: storedKey,
    );
  }

  Future<void> trustHost(
    String host,
    int port,
    String keyType,
    Uint8List fingerprint,
  ) async {
    final knownHost = KnownHostModel(
      host: host,
      port: port,
      keyType: keyType,
      fingerprint: KnownHostModel.fingerprintToHex(fingerprint),
      encodedKey: '',
      addedAt: DateTime.now(),
    );
    await _storageService.saveKnownHost(knownHost);
  }

  Future<void> removeTrustedHost(String host, int port) async {
    await _storageService.deleteKnownHost(host, port);
  }

  bool _fingerprintsMatch(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}