import 'package:mysql_client/mysql_client.dart';
import '../../features/connections/models/connection_model.dart';

class DatabaseService {
  Future<void> testConnection(ConnectionModel config) async {
    if (config.type == ConnectionType.mysql) {
      await _testMySQL(config);
    } else {
      throw UnimplementedError('PostgreSQL not supported yet');
    }
  }

  Future<void> _testMySQL(ConnectionModel config) async {
    final conn = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: config.username ?? '',
      password: config.password ?? '',
      databaseName: '', // Optional for connection test
      secure: config.sslEnabled,
    );

    try {
      await conn.connect();
      await conn.close();
    } catch (e) {
      // Re-throw or handle specific errors
      rethrow;
    }
  }
}
