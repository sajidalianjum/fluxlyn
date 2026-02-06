import 'package:flutter/foundation.dart';
import '../models/connection_model.dart';

class ConnectionsProvider extends ChangeNotifier {
  final List<ConnectionModel> _connections = [
    // Dummy data for initial UI matching
    ConnectionModel(
      name: 'Production DB',
      host: 'db-mysql.host.com',
      port: 3306,
      type: ConnectionType.mysql,
      isConnected: true,
    ),
    ConnectionModel(
      name: 'Analytics Warehouse',
      host: '192.168.1.50',
      port: 5432,
      type: ConnectionType.postgresql,
      isConnected: true,
    ),
    ConnectionModel(
      name: 'Staging Environment',
      host: 'staging-pg.internal',
      port: 5432,
      type: ConnectionType.postgresql,
      isConnected: false, // Orange/Yellow state in screenshot logic
    ),
  ];

  List<ConnectionModel> get connections => _connections;

  void addConnection(ConnectionModel connection) {
    _connections.add(connection);
    notifyListeners();
  }

  void removeConnection(String id) {
    _connections.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
