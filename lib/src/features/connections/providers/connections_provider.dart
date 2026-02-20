import 'package:flutter/foundation.dart';
import '../models/connection_model.dart';
import '../../../core/services/storage_service.dart';

class ConnectionsProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<ConnectionModel> _connections = [];

  ConnectionsProvider(this._storageService) {
    _loadConnections();
  }

  List<ConnectionModel> get connections => _connections;

  void _loadConnections() {
    _connections = _storageService.getAllConnections();
    _migrateConnectionsIfNeeded();
    notifyListeners();
  }

  void _migrateConnectionsIfNeeded() {
    bool needsMigration = false;
    for (final conn in _connections) {
      if (conn.sortOrder == null) {
        needsMigration = true;
        break;
      }
    }

    if (needsMigration) {
      final withSortOrder =
          _connections.where((c) => c.sortOrder != null).toList()
            ..sort((a, b) => a.sortOrder!.compareTo(b.sortOrder!));

      final withoutSortOrder = _connections
          .where((c) => c.sortOrder == null)
          .toList();

      final migratedConnections = <ConnectionModel>[];
      migratedConnections.addAll(withSortOrder);

      int nextSortOrder = migratedConnections.isEmpty
          ? 0
          : migratedConnections
                    .map((c) => c.sortOrder!)
                    .reduce((a, b) => a > b ? a : b) +
                1;

      for (final conn in withoutSortOrder) {
        migratedConnections.add(
          ConnectionModel(
            id: conn.id,
            name: conn.name,
            host: conn.host,
            port: conn.port,
            username: conn.username,
            password: conn.password,
            type: conn.type,
            sslEnabled: conn.sslEnabled,
            isConnected: conn.isConnected,
            useSsh: conn.useSsh,
            sshHost: conn.sshHost,
            sshPort: conn.sshPort,
            sshUsername: conn.sshUsername,
            sshPassword: conn.sshPassword,
            sshPrivateKey: conn.sshPrivateKey,
            sshKeyPassword: conn.sshKeyPassword,
            databaseName: conn.databaseName,
            customTag: conn.customTag,
            tag: conn.tag,
            sortOrder: nextSortOrder++,
          ),
        );
      }

      _connections = migratedConnections;

      for (final conn in _connections) {
        _storageService.saveConnection(conn);
      }
    }
  }

  Future<void> addConnection(ConnectionModel connection) async {
    final maxSortOrder = _connections.isEmpty
        ? 0
        : _connections
              .where((c) => c.sortOrder != null)
              .map((c) => c.sortOrder!)
              .reduce((a, b) => a > b ? a : b);
    final newConnection = ConnectionModel(
      id: connection.id,
      name: connection.name,
      host: connection.host,
      port: connection.port,
      username: connection.username,
      password: connection.password,
      type: connection.type,
      sslEnabled: connection.sslEnabled,
      isConnected: connection.isConnected,
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
      sortOrder: maxSortOrder + 1,
    );
    _connections.add(newConnection);
    await _storageService.saveConnection(newConnection);
    notifyListeners();
  }

  Future<void> updateConnection(ConnectionModel connection) async {
    final index = _connections.indexWhere((c) => c.id == connection.id);
    if (index != -1) {
      _connections[index] = connection;
      await _storageService.saveConnection(connection);
      notifyListeners();
    }
  }

  Future<void> removeConnection(String id) async {
    _connections.removeWhere((c) => c.id == id);
    await _storageService.deleteConnection(id);
    notifyListeners();
  }

  Future<void> reorderConnections(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    if (oldIndex < 0 || oldIndex >= _connections.length) {
      return;
    }

    final connection = _connections.removeAt(oldIndex);
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _connections.insert(adjustedNewIndex, connection);

    for (int i = 0; i < _connections.length; i++) {
      final currentConnection = _connections[i];
      if (currentConnection.sortOrder != i) {
        _connections[i] = ConnectionModel(
          id: currentConnection.id,
          name: currentConnection.name,
          host: currentConnection.host,
          port: currentConnection.port,
          username: currentConnection.username,
          password: currentConnection.password,
          type: currentConnection.type,
          sslEnabled: currentConnection.sslEnabled,
          isConnected: currentConnection.isConnected,
          useSsh: currentConnection.useSsh,
          sshHost: currentConnection.sshHost,
          sshPort: currentConnection.sshPort,
          sshUsername: currentConnection.sshUsername,
          sshPassword: currentConnection.sshPassword,
          sshPrivateKey: currentConnection.sshPrivateKey,
          sshKeyPassword: currentConnection.sshKeyPassword,
          databaseName: currentConnection.databaseName,
          customTag: currentConnection.customTag,
          tag: currentConnection.tag,
          sortOrder: i,
        );
      }
    }

    for (final conn in _connections) {
      await _storageService.saveConnection(conn);
    }

    notifyListeners();
  }
}
