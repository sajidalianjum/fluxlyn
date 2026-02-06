import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/connections/models/connection_model.dart';

class StorageService {
  static const String _connectionsBoxName = 'connections';
  // Note: This salt is stored in the binary. For extreme security,
  // a hardware-backed keychain is better. But this overcomes
  // sandbox entitlement issues while keeping data encrypted as requested.
  static const String _internalSalt = "fluxlyn_key_derivation_v1_2024_internal";
  
  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConnectionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ConnectionModelAdapter());
    }
    
    // Derive Encryption Key (32 bytes for AES-256)
    final encryptionKey = _deriveEncryptionKey();
    
    // Open Encrypted Box
    await Hive.openBox<ConnectionModel>(
      _connectionsBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  List<int> _deriveEncryptionKey() {
    // Generate a consistent 32-byte key from our internal salt
    return sha256.convert(utf8.encode(_internalSalt)).bytes;
  }

  Box<ConnectionModel> get connectionsBox => Hive.box<ConnectionModel>(_connectionsBoxName);

  Future<void> saveConnection(ConnectionModel connection) async {
    await connectionsBox.put(connection.id, connection);
  }

  Future<void> deleteConnection(String id) async {
    await connectionsBox.delete(id);
  }

  List<ConnectionModel> getAllConnections() {
    return connectionsBox.values.toList();
  }
}
