import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../features/connections/models/connection_model.dart';
import '../../features/queries/models/query_model.dart';
import '../../core/models/settings_model.dart';

class StorageService {
  static const String _connectionsBoxName = 'connections';
  static const String _queriesBoxName = 'queries';
  static const String _queryHistoryBoxName = 'query_history';
  static const String _settingsBoxName = 'settings';
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
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ConnectionTagAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ConnectionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(QueryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(QueryHistoryEntryAdapter());
    }

    // Derive Encryption Key (32 bytes for AES-256)
    final encryptionKey = _deriveEncryptionKey();

    // Open Encrypted Boxes
    await Hive.openBox<ConnectionModel>(
      _connectionsBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    await Hive.openBox<QueryModel>(
      _queriesBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    await Hive.openBox<QueryHistoryEntry>(
      _queryHistoryBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    await Hive.openBox(
      _settingsBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  List<int> _deriveEncryptionKey() {
    // Generate a consistent 32-byte key from our internal salt
    return sha256.convert(utf8.encode(_internalSalt)).bytes;
  }

  // Connections
  Box<ConnectionModel> get connectionsBox =>
      Hive.box<ConnectionModel>(_connectionsBoxName);

  Future<void> saveConnection(ConnectionModel connection) async {
    await connectionsBox.put(connection.id, connection);
  }

  Future<void> deleteConnection(String id) async {
    await connectionsBox.delete(id);
  }

  List<ConnectionModel> getAllConnections() {
    final connections = connectionsBox.values.toList();
    final sortedConnections = <ConnectionModel>[];

    final withSortOrder = connections.where((c) => c.sortOrder != null).toList()
      ..sort((a, b) => a.sortOrder!.compareTo(b.sortOrder!));

    final withoutSortOrder = connections
        .where((c) => c.sortOrder == null)
        .toList();

    sortedConnections.addAll(withSortOrder);
    sortedConnections.addAll(withoutSortOrder);

    return sortedConnections;
  }

  ConnectionModel? getConnectionById(String id) {
    return connectionsBox.get(id);
  }

  // Queries
  Box<QueryModel> get queriesBox => Hive.box<QueryModel>(_queriesBoxName);

  Future<void> saveQuery(QueryModel query) async {
    await queriesBox.put(query.id, query);
  }

  Future<void> deleteQuery(String id) async {
    await queriesBox.delete(id);
  }

  List<QueryModel> getSavedQueries(String connectionId) {
    return queriesBox.values
        .where((q) => q.connectionId == connectionId)
        .toList();
  }

  List<QueryModel> getFavoriteQueries(String connectionId) {
    return queriesBox.values
        .where((q) => q.connectionId == connectionId && q.isFavorite)
        .toList();
  }

  List<QueryModel> getAllSavedQueries() {
    return queriesBox.values.toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  // Query History
  Box<QueryHistoryEntry> get queryHistoryBox =>
      Hive.box<QueryHistoryEntry>(_queryHistoryBoxName);

  Future<void> addToHistory(QueryHistoryEntry entry) async {
    await queryHistoryBox.put(entry.id, entry);
    // Keep only last 100 entries per connection
    await _cleanupHistory(entry.connectionId);
  }

  Future<void> _cleanupHistory(String connectionId) async {
    final entries =
        queryHistoryBox.values
            .where((e) => e.connectionId == connectionId)
            .toList()
          ..sort((a, b) => b.executedAt.compareTo(a.executedAt));

    if (entries.length > 100) {
      final toDelete = entries.sublist(100);
      for (final entry in toDelete) {
        await queryHistoryBox.delete(entry.id);
      }
    }
  }

  List<QueryHistoryEntry> getQueryHistory(String connectionId) {
    return queryHistoryBox.values
        .where((e) => e.connectionId == connectionId)
        .toList()
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
  }

  List<QueryHistoryEntry> getAllQueryHistory() {
    return queryHistoryBox.values.toList()
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
  }

  Future<void> deleteHistoryEntry(String id) async {
    await queryHistoryBox.delete(id);
  }

  Future<void> clearHistory(String connectionId) async {
    final entries = queryHistoryBox.values
        .where((e) => e.connectionId == connectionId)
        .toList();
    for (final entry in entries) {
      await queryHistoryBox.delete(entry.id);
    }
  }

  // Settings
  Box get settingsBox => Hive.box(_settingsBoxName);

  Future<void> saveSettings(AppSettings settings) async {
    final settingsJson = settings.toJson();
    await settingsBox.put('settings', jsonEncode(settingsJson));
  }

  AppSettings loadSettings() {
    final settingsJson = settingsBox.get('settings');
    if (settingsJson == null) {
      return AppSettings.defaultSettings();
    }
    try {
      return AppSettings.fromJson(
        jsonDecode(settingsJson as String) as Map<String, dynamic>,
      );
    } catch (e) {
      return AppSettings.defaultSettings();
    }
  }

  Future<void> exportConnections(
    String savePath,
    String password,
    List<ConnectionModel> connections,
  ) async {
    final key = encrypt.Key.fromUtf8(_padPassword(password));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final connectionsJson = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'connections': connections.map((c) => c.toJson()).toList(),
    };

    final jsonString = jsonEncode(connectionsJson);
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    final fileContent = jsonEncode({'iv': iv.base64, 'data': encrypted.base64});

    final file = File(savePath);
    await file.writeAsString(fileContent);
  }

  Future<List<ConnectionModel>> importConnections(
    String filePath,
    String password,
  ) async {
    final file = File(filePath);
    final fileContent = await file.readAsString();

    final encryptedData = jsonDecode(fileContent) as Map<String, dynamic>;
    final iv = encrypt.IV.fromBase64(encryptedData['iv'] as String);
    final encrypted = encrypt.Encrypted.fromBase64(
      encryptedData['data'] as String,
    );

    final key = encrypt.Key.fromUtf8(_padPassword(password));
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    try {
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      final connectionsJson = jsonDecode(decrypted) as Map<String, dynamic>;
      final connectionsList = connectionsJson['connections'] as List;

      final uuid = const Uuid();
      return connectionsList.map((json) {
        final connection = ConnectionModel.fromJson(
          json as Map<String, dynamic>,
        );
        return ConnectionModel(
          id: uuid.v4(),
          name: connection.name,
          host: connection.host,
          port: connection.port,
          username: connection.username,
          password: connection.password,
          type: connection.type,
          sslEnabled: connection.sslEnabled,
          isConnected: false,
          useSsh: connection.useSsh,
          sshHost: connection.sshHost,
          sshPort: connection.sshPort,
          sshUsername: connection.sshUsername,
          sshPassword: connection.sshPassword,
          sshPrivateKey: connection.sshPrivateKey,
          sshKeyPassword: connection.sshKeyPassword,
          databaseName: connection.databaseName,
          customTag: connection.customTag,
          tag: connection.tag,
          sortOrder: null,
        );
      }).toList();
    } catch (e) {
      throw Exception(
        'Failed to decrypt connections. Invalid password or corrupted file.',
      );
    }
  }

  String _padPassword(String password) {
    if (password.length >= 32) {
      return password.substring(0, 32);
    }
    return password.padRight(32, '0');
  }
}
