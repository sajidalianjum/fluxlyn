import 'dart:async';
import 'package:mysql_dart/mysql_dart.dart';
import '../../features/connections/models/connection_model.dart';
import 'database_driver.dart';
import 'ssh_tunnel_service.dart';

class MySQLDriver implements DatabaseDriver {
  final SSHTunnelService _sshTunnel = SSHTunnelService();
  MySQLConnection? _connection;

  @override
  Future<void> testConnection(ConnectionModel config) async {
    print('Testing MySQL connection...');
    String host = config.host;
    int port = config.port;

    if (config.useSsh && config.sshHost != null) {
      await _sshTunnel.connect(config, config.host, config.port);
      host = _sshTunnel.localHost;
      port = _sshTunnel.localPort;
    }

    print('MySQL: Creating connection to $host:$port');
    final conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: config.username ?? '',
      password: config.password ?? '',
      databaseName: config.databaseName ?? '',
      secure: config.sslEnabled,
    );
    print('MySQL: Connection object created, attempting to connect...');

    try {
      await conn.connect(timeoutMs: config.useSsh ? 30000 : 10000);
      print('MySQL: Connected successfully');
      await conn.close();
      print('MySQL: Connection closed');
    } catch (e) {
      print('MySQL: Connection error - $e');
      await disconnect();
      rethrow;
    }

    await disconnect();
    print('Test completed successfully');
  }

  @override
  Future<void> connect(ConnectionModel config) async {
    print('Connecting to MySQL...');
    String host = config.host;
    int port = config.port;

    if (config.useSsh && config.sshHost != null) {
      await _sshTunnel.connect(config, config.host, config.port);
      host = _sshTunnel.localHost;
      port = _sshTunnel.localPort;
    }

    print('MySQL: Creating connection to $host:$port');
    _connection = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: config.username ?? '',
      password: config.password ?? '',
      databaseName: config.databaseName ?? '',
      secure: config.sslEnabled,
    );
    print('MySQL: Connection object created, attempting to connect...');

    try {
      await _connection!.connect(timeoutMs: config.useSsh ? 30000 : 10000);
      print('MySQL: Connected successfully');
    } catch (e) {
      print('MySQL: Connection error - $e');
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _sshTunnel.disconnect();
    } catch (_) {}

    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {
        // Connection may be in invalid state, ignore close error
      }
    }
    _connection = null;
  }

  @override
  Future<IResultSet> execute(String sql) async {
    if (_connection == null) {
      throw StateError('Not connected');
    }
    return await _connection!.execute(sql);
  }

  @override
  Future<List<String>> getTables() async {
    final result = await execute('SHOW TABLES');
    final List<String> tables = [];
    for (final row in result.rows) {
      tables.add(row.colAt(0)?.toString() ?? '');
    }
    return tables;
  }

  @override
  Future<List<String>> getDatabases() async {
    final result = await execute('SHOW DATABASES');
    final List<String> databases = [];
    for (final row in result.rows) {
      databases.add(row.colAt(0)?.toString() ?? '');
    }
    return databases;
  }

  @override
  Future<void> useDatabase(String databaseName) async {
    await execute('USE `$databaseName`');
  }

  @override
  Future<bool> isConnected() async {
    if (_connection == null) return false;
    try {
      await execute('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<ColumnInfo>> getColumns(String tableName) async {
    final result = await execute('SHOW COLUMNS FROM `$tableName`');
    final List<ColumnInfo> columns = [];
    for (final row in result.rows) {
      final colName = row.colByName('Field')?.toString();
      final colTypeRaw = row.colByName('Type');
      final nullable = row.colByName('Null')?.toString() == 'YES';
      final defaultValue = row.colByName('Default')?.toString();
      final extra = row.colByName('Extra')?.toString();

      String colType = '';
      if (colTypeRaw is List<int>) {
        colType = String.fromCharCodes(colTypeRaw);
      } else if (colTypeRaw != null) {
        colType = colTypeRaw.toString();
      }

      if (colName != null && colName.isNotEmpty) {
        columns.add(
          ColumnInfo(
            name: colName,
            type: colType,
            isNullable: nullable,
            defaultValue: defaultValue,
            extra: extra,
          ),
        );
      }
    }
    return columns;
  }

  @override
  Future<String?> getPrimaryKeyColumn(String tableName) async {
    final result = await execute(
      "SHOW KEYS FROM `$tableName` WHERE Key_name = 'PRIMARY'",
    );
    for (final row in result.rows) {
      final pkColumn = row.colByName('Column_name')?.toString();
      if (pkColumn != null && pkColumn.isNotEmpty) {
        return pkColumn;
      }
    }
    return null;
  }

  MySQLConnection? get connection => _connection;
}
