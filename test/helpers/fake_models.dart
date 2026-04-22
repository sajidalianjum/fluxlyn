import 'package:fluxlyn/src/features/connections/models/connection_model.dart';
import 'package:fluxlyn/src/features/queries/models/query_model.dart';
import 'package:fluxlyn/src/core/models/settings_model.dart';

class FakeConnectionModel {
  static ConnectionModel create({
    String? id,
    String name = 'Test Connection',
    String host = 'localhost',
    int port = 3306,
    String? username = 'root',
    String? password = 'password',
    ConnectionType type = ConnectionType.mysql,
    bool sslEnabled = true,
    bool isConnected = false,
    bool useSsh = false,
    String? sshHost,
    int? sshPort = 22,
    String? sshUsername,
    String? sshPassword,
    String? sshPrivateKey,
    String? sshKeyPassword,
    String? databaseName,
    ConnectionTag? tag,
    String? customTag,
    int? sortOrder,
  }) {
    return ConnectionModel(
      id: id,
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      type: type,
      sslEnabled: sslEnabled,
      isConnected: isConnected,
      useSsh: useSsh,
      sshHost: sshHost,
      sshPort: sshPort,
      sshUsername: sshUsername,
      sshPassword: sshPassword,
      sshPrivateKey: sshPrivateKey,
      sshKeyPassword: sshKeyPassword,
      databaseName: databaseName,
      tag: tag,
      customTag: customTag,
      sortOrder: sortOrder,
    );
  }

  static List<ConnectionModel> createList(int count) {
    return List.generate(
      count,
      (i) => create(
        name: 'Connection $i',
        port: 3306 + i,
      ),
    );
  }
}

class FakeQueryModel {
  static QueryModel create({
    String? id,
    String name = 'Test Query',
    String query = 'SELECT * FROM users',
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool isFavorite = false,
    String? connectionId,
    String? databaseName,
  }) {
    return QueryModel(
      id: id ?? 'query-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      query: query,
      createdAt: createdAt ?? DateTime.now(),
      modifiedAt: modifiedAt ?? DateTime.now(),
      isFavorite: isFavorite,
      connectionId: connectionId ?? 'test-connection',
      databaseName: databaseName,
    );
  }

  static List<QueryModel> createList(int count, {String? connectionId}) {
    return List.generate(
      count,
      (i) => create(
        name: 'Query $i',
        query: 'SELECT * FROM table_$i',
        connectionId: connectionId,
      ),
    );
  }
}

class FakeAppSettings {
  static AppSettings create({
    bool lock = true,
    bool readOnlyMode = false,
    AIProvider provider = AIProvider.openai,
    String apiKey = '',
    String? endpoint,
    String modelName = '',
  }) {
    return AppSettings(
      lock: lock,
      readOnlyMode: readOnlyMode,
      provider: provider,
      apiKey: apiKey,
      endpoint: endpoint ?? provider.defaultEndpoint,
      modelName: modelName,
    );
  }
}