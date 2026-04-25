import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'known_host_model.g.dart';

@HiveType(typeId: 5)
class KnownHostModel extends HiveObject {
  @HiveField(0)
  final String host;

  @HiveField(1)
  final int port;

  @HiveField(2)
  final String keyType;

  @HiveField(3)
  final String fingerprint;

  @HiveField(4)
  final String encodedKey;

  @HiveField(5)
  final DateTime addedAt;

  KnownHostModel({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.encodedKey,
    required this.addedAt,
  });

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String fingerprintToHex(Uint8List fingerprint) {
    return _bytesToHex(fingerprint);
  }

  static String fingerprintToDisplay(Uint8List fingerprint) {
    final hexStr = _bytesToHex(fingerprint);
    final parts = <String>[];
    for (var i = 0; i < hexStr.length; i += 2) {
      parts.add(hexStr.substring(i, i + 2));
    }
    return parts.join(':');
  }

  static Uint8List fingerprintFromHex(String hexStr) {
    final bytes = <int>[];
    for (var i = 0; i < hexStr.length; i += 2) {
      final hexByte = hexStr.substring(i, i + 2);
      bytes.add(int.parse(hexByte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  @override
  String get key {
    return '$host:$port';
  }

  String get displayFingerprint {
    final parts = <String>[];
    for (var i = 0; i < fingerprint.length; i += 2) {
      parts.add(fingerprint.substring(i, i + 2));
    }
    return parts.join(':');
  }
}