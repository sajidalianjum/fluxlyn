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
    notifyListeners();
  }

  Future<void> addConnection(ConnectionModel connection) async {
    _connections.add(connection);
    await _storageService.saveConnection(connection);
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
}
