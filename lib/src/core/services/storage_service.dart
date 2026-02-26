import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../features/connections/models/connection_model.dart';
import '../../features/queries/models/query_model.dart';
import '../../core/models/settings_model.dart';
import '../../core/models/exceptions.dart';

class ImportResult {
  final List<ConnectionModel> connections;
  final bool hasSettings;
  final AppSettings? settings;

  ImportResult({
    required this.connections,
    required this.hasSettings,
    this.settings,
  });
}

class StorageService extends ChangeNotifier {
  static const String _connectionsBoxName = 'connections';
  static const String _queriesBoxName = 'queries';
  static const String _queryHistoryBoxName = 'query_history';
  static const String _settingsBoxName = 'settings';
  // Note: This salt is stored in the binary. For extreme security,
  // a hardware-backed keychain is better. But this overcomes
  // sandbox entitlement issues while keeping data encrypted as requested.
  static const String _internalSalt = "fluxlyn_key_derivation_v1_2024_internal";

  Future<void> init() async {
    try {
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

      // Open Encrypted Boxes (parallel for faster startup)
      await Future.wait([
        Hive.openBox<ConnectionModel>(
          _connectionsBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
        Hive.openBox<QueryModel>(
          _queriesBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
        Hive.openBox<QueryHistoryEntry>(
          _queryHistoryBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
        Hive.openBox(
          _settingsBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
      ]);
    } catch (e) {
      throw StorageException(
        'Failed to initialize storage: ${e.toString()}',
        operation: 'init',
        originalError: e,
      );
    }
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
    notifyListeners();
  }

  Future<void> deleteConnection(String id) async {
    await connectionsBox.delete(id);
    await _deleteQueriesForConnection(id);
    await _deleteHistoryForConnection(id);
    notifyListeners();
  }

  Future<void> _deleteQueriesForConnection(String connectionId) async {
    final queries = queriesBox.values
        .where((q) => q.connectionId == connectionId)
        .toList();
    for (final query in queries) {
      await queriesBox.delete(query.id);
    }
  }

  Future<void> _deleteHistoryForConnection(String connectionId) async {
    final entries = queryHistoryBox.values
        .where((e) => e.connectionId == connectionId)
        .toList();
    for (final entry in entries) {
      await queryHistoryBox.delete(entry.id);
    }
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
    notifyListeners();
  }

  Future<void> deleteQuery(String id) async {
    await queriesBox.delete(id);
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> clearHistory(String connectionId) async {
    final entries = queryHistoryBox.values
        .where((e) => e.connectionId == connectionId)
        .toList();
    for (final entry in entries) {
      await queryHistoryBox.delete(entry.id);
    }
    notifyListeners();
  }

  // Settings
  Box get settingsBox => Hive.box(_settingsBoxName);

  Future<void> saveSettings(AppSettings settings) async {
    try {
      final settingsJson = settings.toJson();
      await settingsBox.put('settings', jsonEncode(settingsJson));
      notifyListeners();
    } catch (e) {
      throw StorageException(
        'Failed to save settings: ${e.toString()}',
        operation: 'saveSettings',
        originalError: e,
      );
    }
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
      debugPrint('Failed to load settings, using defaults: $e');
      return AppSettings.defaultSettings();
    }
  }

  Future<void> exportConnections(
    String savePath,
    String password,
    List<ConnectionModel> connections, {
    bool includePasswords = true,
    bool includeSettings = false,
    AppSettings? settings,
  }) async {
    try {
      if (password.isEmpty) {
        throw ValidationException(
          'Password cannot be empty',
          field: 'password',
        );
      }

      final file = File(savePath);
      final directory = file.parent;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final key = encrypt.Key.fromUtf8(_padPassword(password));
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      List<ConnectionModel> connectionsToExport = connections;
      if (!includePasswords) {
        connectionsToExport = connections.map((c) {
          return ConnectionModel(
            id: c.id,
            name: c.name,
            host: c.host,
            port: c.port,
            username: c.username,
            password: null,
            type: c.type,
            sslEnabled: c.sslEnabled,
            isConnected: false,
            useSsh: c.useSsh,
            sshHost: c.sshHost,
            sshPort: c.sshPort,
            sshUsername: c.sshUsername,
            sshPassword: null,
            sshPrivateKey: null,
            sshKeyPassword: null,
            databaseName: c.databaseName,
            customTag: c.customTag,
            tag: c.tag,
            sortOrder: null,
          );
        }).toList();
      }

      final connectionsJson = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'includePasswords': includePasswords,
        'includeSettings': includeSettings,
        'connections': connectionsToExport.map((c) => c.toJson()).toList(),
      };

      if (includeSettings && settings != null) {
        connectionsJson['settings'] = settings.toJson();
      }

      final jsonString = jsonEncode(connectionsJson);
      final encrypted = encrypter.encrypt(jsonString, iv: iv);

      final fileContent = jsonEncode({
        'iv': iv.base64,
        'data': encrypted.base64,
      });

      await file.writeAsString(fileContent);
    } catch (e) {
      if (e is StorageException || e is ValidationException) rethrow;
      throw StorageException(
        'Failed to export connections: ${e.toString()}',
        filePath: savePath,
        operation: 'exportConnections',
        originalError: e,
      );
    }
  }

  Future<ImportResult> checkImportFile(String filePath, String password) async {
    try {
      if (password.isEmpty) {
        throw ValidationException(
          'Password cannot be empty',
          field: 'password',
        );
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        throw StorageException(
          'Import file does not exist: $filePath',
          filePath: filePath,
          operation: 'checkImportFile',
        );
      }

      final fileContent = await file.readAsString();

      if (fileContent.isEmpty) {
        throw StorageException(
          'Import file is empty',
          filePath: filePath,
          operation: 'checkImportFile',
        );
      }

      final encryptedData = jsonDecode(fileContent) as Map<String, dynamic>;

      if (!encryptedData.containsKey('iv') ||
          !encryptedData.containsKey('data')) {
        throw StorageException(
          'Invalid export file format',
          filePath: filePath,
          operation: 'checkImportFile',
        );
      }

      final iv = encrypt.IV.fromBase64(encryptedData['iv'] as String);
      final encrypted = encrypt.Encrypted.fromBase64(
        encryptedData['data'] as String,
      );

      final key = encrypt.Key.fromUtf8(_padPassword(password));
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      try {
        final decrypted = encrypter.decrypt(encrypted, iv: iv);
        final connectionsJson = jsonDecode(decrypted) as Map<String, dynamic>;

        if (!connectionsJson.containsKey('connections')) {
          throw StorageException(
            'Invalid export file: missing connections',
            filePath: filePath,
            operation: 'checkImportFile',
          );
        }

        final hasSettings = connectionsJson.containsKey('settings');
        AppSettings? settings;

        if (hasSettings) {
          settings = AppSettings.fromJson(
            connectionsJson['settings'] as Map<String, dynamic>,
          );
        }

        final connectionsList = connectionsJson['connections'] as List;

        final uuid = const Uuid();
        final connections = connectionsList.map((json) {
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

        return ImportResult(
          connections: connections,
          hasSettings: hasSettings,
          settings: settings,
        );
      } catch (e) {
        throw StorageException(
          'Failed to decrypt connections. Invalid password or corrupted file.',
          filePath: filePath,
          operation: 'checkImportFile',
          originalError: e,
        );
      }
    } catch (e) {
      if (e is StorageException || e is ValidationException) rethrow;
      throw StorageException(
        'Failed to check import file: ${e.toString()}',
        filePath: filePath,
        operation: 'checkImportFile',
        originalError: e,
      );
    }
  }

  Future<List<ConnectionModel>> importConnections(
    String filePath,
    String password, {
    bool overwriteSettings = false,
  }) async {
    try {
      final result = await checkImportFile(filePath, password);

      if (overwriteSettings && result.settings != null) {
        await saveSettings(result.settings!);
      }

      return result.connections;
    } catch (e) {
      if (e is StorageException || e is ValidationException) rethrow;
      throw StorageException(
        'Failed to import connections: ${e.toString()}',
        filePath: filePath,
        operation: 'importConnections',
        originalError: e,
      );
    }
  }

  String _padPassword(String password) {
    try {
      if (password.length >= 32) {
        return password.substring(0, 32);
      }
      return password.padRight(32, '0');
    } catch (e) {
      throw StorageException(
        'Failed to pad password: ${e.toString()}',
        operation: 'padPassword',
        originalError: e,
      );
    }
  }
}
