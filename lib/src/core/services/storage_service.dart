import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../features/connections/models/connection_model.dart';
import '../../features/queries/models/query_model.dart';
import '../../core/models/settings_model.dart';
import '../../core/models/known_host_model.dart';
import '../utils/error_reporter.dart';
import '../../core/models/exceptions.dart';
import 'master_password_service.dart';

enum PasswordRequirement {
  notRequired,
  required,
  firstLaunch,
}

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
  static const String _keyBoxName = 'encryption_key';
  static const String _knownHostsBoxName = 'known_hosts';

  static const int _saltLength = 16;
  static const int _ivLength = 16;
  static const int _keyLength = 32;
  static const int _hmacKeyLength = 32;

  List<int>? _decryptedDeviceKey;
  bool _isInitialized = false;

  Future<PasswordRequirement> checkPasswordRequirement() async {
    await Hive.initFlutter();

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

    final keyBox = await Hive.openBox(_keyBoxName);
    final hasMasterPassword = keyBox.get('master_password_data') != null;

    if (hasMasterPassword) {
      return PasswordRequirement.required;
    }

    final settingsBox = await Hive.openBox(_settingsBoxName);
    final settingsJson = settingsBox.get('settings');
    bool hasShownPrompt = false;

    if (settingsJson != null) {
      try {
        final decoded = Map<String, dynamic>.from(settingsJson);
        hasShownPrompt = decoded['hasShownPasswordPrompt'] ?? false;
      } catch (_) {}
    }

    return hasShownPrompt ? PasswordRequirement.notRequired : PasswordRequirement.firstLaunch;
  }

  Future<void> init({String? masterPassword}) async {
    try {
      await Hive.initFlutter();

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
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(KnownHostModelAdapter());
      }

      final encryptionKey = await _getOrCreateEncryptionKey(masterPassword);

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
        Hive.openBox<KnownHostModel>(
          _knownHostsBoxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        ),
      ]);

      _isInitialized = true;
    } catch (e) {
      throw StorageException(
        'Failed to initialize storage: ${e.toString()}',
        operation: 'init',
        originalError: e,
      );
    }
  }

  bool get isInitialized => _isInitialized;

  Future<List<int>> _getOrCreateEncryptionKey(String? masterPassword) async {
    final keyBox = await Hive.openBox(_keyBoxName);

    final masterPasswordDataJson = keyBox.get('master_password_data');
    final hasMasterPassword = masterPasswordDataJson != null;

    if (hasMasterPassword) {
      if (masterPassword == null || masterPassword.isEmpty) {
        throw StorageException(
          'Master password required to unlock storage',
          operation: 'init',
        );
      }

      final data = MasterPasswordData.fromJson(
        jsonDecode(masterPasswordDataJson as String) as Map<String, dynamic>,
      );

      final decryptedKey = await MasterPasswordService.decryptDeviceKey(data, masterPassword);
      if (decryptedKey == null) {
        throw StorageException(
          'Invalid master password',
          operation: 'init',
        );
      }

      _decryptedDeviceKey = decryptedKey;
      return decryptedKey;
    }

    final existingKey = keyBox.get('device_key');
    if (existingKey != null && existingKey is List) {
      _decryptedDeviceKey = existingKey.cast<int>();
      return existingKey.cast<int>();
    }

    final random = Random.secure();
    final newKey = List<int>.generate(32, (_) => random.nextInt(256));

    await keyBox.put('device_key', newKey);
    _decryptedDeviceKey = newKey;

    ErrorReporter.info(
      'Generated new device-specific encryption key',
      'StorageService._getOrCreateEncryptionKey',
      'storage_service.dart',
    );

    return newKey;
  }

  List<int> get deviceKey {
    if (_decryptedDeviceKey == null) {
      throw StorageException(
        'Device key not available - storage not initialized',
        operation: 'getDeviceKey',
      );
    }
    return _decryptedDeviceKey!;
  }

  bool isMasterPasswordEnabled() {
    final keyBox = Hive.box(_keyBoxName);
    return keyBox.get('master_password_data') != null;
  }

  MasterPasswordData? getMasterPasswordData() {
    final keyBox = Hive.box(_keyBoxName);
    final dataJson = keyBox.get('master_password_data');
    if (dataJson == null) return null;
    return MasterPasswordData.fromJson(
      jsonDecode(dataJson as String) as Map<String, dynamic>,
    );
  }

  Future<void> enableMasterPassword(String password) async {
    if (_decryptedDeviceKey == null) {
      throw StorageException(
        'Device key not available',
        operation: 'enableMasterPassword',
      );
    }

    final keyBox = Hive.box(_keyBoxName);
    final data = await MasterPasswordService.encryptDeviceKey(
      _decryptedDeviceKey!,
      password,
    );

    await keyBox.put('master_password_data', jsonEncode(data.toJson()));
    await keyBox.delete('device_key');

    ErrorReporter.info(
      'Master password enabled - device key encrypted',
      'StorageService.enableMasterPassword',
      'storage_service.dart',
    );
  }

  Future<void> disableMasterPassword(String password) async {
    final data = getMasterPasswordData();
    if (data == null) {
      throw StorageException(
        'Master password not enabled',
        operation: 'disableMasterPassword',
      );
    }

    final decryptedKey = await MasterPasswordService.decryptDeviceKey(data, password);
    if (decryptedKey == null) {
      throw StorageException(
        'Invalid master password',
        operation: 'disableMasterPassword',
      );
    }

    final keyBox = Hive.box(_keyBoxName);
    await keyBox.put('device_key', decryptedKey);
    await keyBox.delete('master_password_data');

    _decryptedDeviceKey = decryptedKey;

    ErrorReporter.info(
      'Master password disabled - device key stored unencrypted',
      'StorageService.disableMasterPassword',
      'storage_service.dart',
    );
  }

  Future<void> changeMasterPassword(String oldPassword, String newPassword) async {
    final data = getMasterPasswordData();
    if (data == null) {
      throw StorageException(
        'Master password not enabled',
        operation: 'changeMasterPassword',
      );
    }

    final decryptedKey = await MasterPasswordService.decryptDeviceKey(data, oldPassword);
    if (decryptedKey == null) {
      throw StorageException(
        'Invalid old password',
        operation: 'changeMasterPassword',
      );
    }

    final newData = await MasterPasswordService.encryptDeviceKey(decryptedKey, newPassword);
    final keyBox = Hive.box(_keyBoxName);
    await keyBox.put('master_password_data', jsonEncode(newData.toJson()));

    ErrorReporter.info(
      'Master password changed',
      'StorageService.changeMasterPassword',
      'storage_service.dart',
    );
  }

  Future<bool> verifyMasterPassword(String password) async {
    final data = getMasterPasswordData();
    if (data == null) return false;
    return await MasterPasswordService.verifyPassword(data, password);
  }

  Future<void> clearAllData() async {
    final keyBox = await Hive.openBox(_keyBoxName);
    await keyBox.clear();

    if (Hive.isBoxOpen(_connectionsBoxName)) {
      await Hive.box<ConnectionModel>(_connectionsBoxName).clear();
    } else {
      await Hive.deleteBoxFromDisk(_connectionsBoxName);
    }

    if (Hive.isBoxOpen(_queriesBoxName)) {
      await Hive.box<QueryModel>(_queriesBoxName).clear();
    } else {
      await Hive.deleteBoxFromDisk(_queriesBoxName);
    }

    if (Hive.isBoxOpen(_queryHistoryBoxName)) {
      await Hive.box<QueryHistoryEntry>(_queryHistoryBoxName).clear();
    } else {
      await Hive.deleteBoxFromDisk(_queryHistoryBoxName);
    }

    if (Hive.isBoxOpen(_settingsBoxName)) {
      await Hive.box(_settingsBoxName).clear();
    } else {
      await Hive.deleteBoxFromDisk(_settingsBoxName);
    }

    _decryptedDeviceKey = null;

    ErrorReporter.info(
      'All data cleared due to forgotten password',
      'StorageService.clearAllData',
      'storage_service.dart',
    );
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
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Failed to load settings, using defaults: $e',
        stackTrace,
        'StorageService.loadSettings',
        'storage_service.dart:257',
      );
      return AppSettings.defaultSettings();
    }
  }

  // Known Hosts
  Box<KnownHostModel> get knownHostsBox =>
      Hive.box<KnownHostModel>(_knownHostsBoxName);

  Future<void> saveKnownHost(KnownHostModel knownHost) async {
    await knownHostsBox.put(knownHost.key, knownHost);
    notifyListeners();
  }

  KnownHostModel? getKnownHost(String host, int port) {
    return knownHostsBox.get('$host:$port');
  }

  Future<void> deleteKnownHost(String host, int port) async {
    await knownHostsBox.delete('$host:$port');
    notifyListeners();
  }

  List<KnownHostModel> getAllKnownHosts() {
    return knownHostsBox.values.toList();
  }

  Future<void> clearAllKnownHosts() async {
    await knownHostsBox.clear();
    notifyListeners();
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

      final random = Random.secure();
      final salt = Uint8List.fromList(
        List<int>.generate(_saltLength, (_) => random.nextInt(256)),
      );
      final iv = Uint8List.fromList(
        List<int>.generate(_ivLength, (_) => random.nextInt(256)),
      );

      final aesKey = await _deriveKey(password, salt, _keyLength);
      final hmacKey = await _deriveKey(password, salt, _hmacKeyLength);

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
        'version': '2.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'includePasswords': includePasswords,
        'includeSettings': includeSettings,
        'connections': connectionsToExport.map((c) => c.toJson()).toList(),
      };

      if (includeSettings && settings != null) {
        connectionsJson['settings'] = settings.toJson();
      }

      final jsonString = jsonEncode(connectionsJson);
      final plaintext = utf8.encode(jsonString);

      final encryptKey = encrypt.Key(aesKey);
      final encryptIv = encrypt.IV(iv);
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));
      final encrypted = encrypter.encryptBytes(plaintext, iv: encryptIv);
      final ciphertext = Uint8List.fromList(encrypted.bytes);

      final hmac = _computeHmac(hmacKey, salt, iv, ciphertext);

      final fileContent = jsonEncode({
        'version': '2.0',
        'salt': _bytesToBase64(salt),
        'iv': _bytesToBase64(iv),
        'data': _bytesToBase64(ciphertext),
        'hmac': _bytesToBase64(hmac),
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

      final version = encryptedData['version'] as String?;
      if (version != '2.0') {
        throw StorageException(
          'Invalid or outdated export file version',
          filePath: filePath,
          operation: 'checkImportFile',
        );
      }

      if (!encryptedData.containsKey('salt') ||
          !encryptedData.containsKey('iv') ||
          !encryptedData.containsKey('data') ||
          !encryptedData.containsKey('hmac')) {
        throw StorageException(
          'Invalid export file format: missing required fields',
          filePath: filePath,
          operation: 'checkImportFile',
        );
      }

      final salt = _base64ToBytes(encryptedData['salt'] as String);
      final iv = _base64ToBytes(encryptedData['iv'] as String);
      final ciphertext = _base64ToBytes(encryptedData['data'] as String);
      final storedHmac = _base64ToBytes(encryptedData['hmac'] as String);

      final aesKey = await _deriveKey(password, salt, _keyLength);
      final hmacKey = await _deriveKey(password, salt, _hmacKeyLength);

      final computedHmac = _computeHmac(hmacKey, salt, iv, ciphertext);

      if (!const DeepCollectionEquality().equals(computedHmac, storedHmac)) {
        throw StorageException(
          'Export file integrity check failed. File may be corrupted or tampered with.',
          filePath: filePath,
          operation: 'checkImportFile',
        );
      }

      final encryptKey = encrypt.Key(aesKey);
      final encryptIv = encrypt.IV(iv);
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));

      try {
        final encrypted = encrypt.Encrypted(ciphertext);
        final decrypted = encrypter.decrypt(encrypted, iv: encryptIv);
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

  Future<Uint8List> _deriveKey(String password, Uint8List salt, int keyLength) async {
    return await Isolate.run(
      () => _deriveKeySync(_DeriveKeyParamsExport(password, salt, keyLength)),
    );
  }

  Uint8List _computeHmac(Uint8List key, Uint8List salt, Uint8List iv, Uint8List ciphertext) {
    final hmac = Hmac(sha256, key);
    final data = Uint8List.fromList([...salt, ...iv, ...ciphertext]);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  String _bytesToBase64(Uint8List bytes) => base64Encode(bytes);

  Uint8List _base64ToBytes(String base64Str) => base64Decode(base64Str);
}

class _DeriveKeyParamsExport {
  final String password;
  final Uint8List salt;
  final int keyLength;

  _DeriveKeyParamsExport(this.password, this.salt, this.keyLength);
}

Uint8List _intToBytesExport(int value) {
  return Uint8List(4)
    ..[0] = (value >> 24) & 0xFF
    ..[1] = (value >> 16) & 0xFF
    ..[2] = (value >> 8) & 0xFF
    ..[3] = value & 0xFF;
}

Uint8List _deriveKeySync(_DeriveKeyParamsExport params) {
  final passwordBytes = utf8.encode(params.password);
  final result = <int>[];
  var blockIndex = 1;

  while (result.length < params.keyLength) {
    final blockData = Uint8List.fromList([...params.salt, ..._intToBytesExport(blockIndex)]);
    var u = Hmac(sha256, passwordBytes).convert(blockData);
    final block = List<int>.from(u.bytes);

    for (var i = 1; i < 100000; i++) {
      u = Hmac(sha256, passwordBytes).convert(u.bytes);
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u.bytes[j];
      }
    }

    result.addAll(block);
    blockIndex++;
  }

  return Uint8List.fromList(result.sublist(0, params.keyLength));
}
