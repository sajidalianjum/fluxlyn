import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'connection_model.g.dart';

@HiveType(typeId: 4)
enum ConnectionTag {
  @HiveField(0)
  none,
  @HiveField(1)
  development,
  @HiveField(2)
  production,
  @HiveField(3)
  testing,
  @HiveField(4)
  staging,
  @HiveField(5)
  local,
  @HiveField(6)
  custom,
}

@HiveType(typeId: 1)
enum ConnectionType {
  @HiveField(0)
  mysql,
  @HiveField(1)
  postgresql,
}

@HiveType(typeId: 0)
class ConnectionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String host;

  @HiveField(3)
  final int port;

  @HiveField(4)
  final String? username;

  @HiveField(5)
  final String? password;

  @HiveField(6)
  final ConnectionType type;

  @HiveField(7)
  final bool sslEnabled;

  @HiveField(8)
  final bool isConnected;

  // SSH Fields
  @HiveField(9)
  final bool useSsh;

  @HiveField(10)
  final String? sshHost;

  @HiveField(11)
  final int? sshPort;

  @HiveField(12)
  final String? sshUsername;

  @HiveField(13)
  final String? sshPassword;

  @HiveField(14)
  final String? sshPrivateKey;

  @HiveField(15)
  final String? sshKeyPassword;

  @HiveField(16)
  final String? databaseName;

  @HiveField(17)
  final String? customTag;

  @HiveField(18)
  final ConnectionTag? tag;

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
    this.useSsh = false,
    this.sshHost,
    this.sshPort = AppConstants.portSSH,
    this.sshUsername,
    this.sshPassword,
    this.sshPrivateKey,
    this.sshKeyPassword,
    this.databaseName,
    this.customTag,
    ConnectionTag? tag,
  }) : tag = tag ?? ConnectionTag.none,
       id = id ?? const Uuid().v4();

  // Keep toJson for potential exports
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'type': type.toString(),
      'sslEnabled': sslEnabled,
      'useSsh': useSsh,
      'sshHost': sshHost,
      'sshPort': sshPort,
      'sshUsername': sshUsername,
      'databaseName': databaseName,
      'tag': tag.toString(),
      'customTag': customTag,
    };
  }
}
