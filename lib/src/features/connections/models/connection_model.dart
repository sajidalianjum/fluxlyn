import 'package:uuid/uuid.dart';

enum ConnectionType { mysql, postgresql }

class ConnectionModel {
  final String id;
  final String name;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final ConnectionType type;
  final bool sslEnabled;
  final bool isConnected; // UI state primarily

  ConnectionModel({
    String? id,
    required this.name,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.type = ConnectionType.mysql,
    this.sslEnabled = false,
    this.isConnected = false,
  }) : id = id ?? const Uuid().v4();

  // For persistence (simple JSON map)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'type': type.toString(),
      'sslEnabled': sslEnabled,
    };
  }
}
