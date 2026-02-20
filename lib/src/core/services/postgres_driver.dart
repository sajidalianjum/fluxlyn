import 'dart:async';
import 'package:postgres/postgres.dart';
import '../../features/connections/models/connection_model.dart';
import 'database_driver.dart';
import 'ssh_tunnel_service.dart';

class PostgreSQLDriver implements DatabaseDriver {
  final SSHTunnelService _sshTunnel = SSHTunnelService();
  Connection? _connection;
  String? _currentDatabase;
  ConnectionModel? _config;

  @override
  Future<void> testConnection(ConnectionModel config) async {
    print('Testing PostgreSQL connection...');
    String host = config.host;
    int port = config.port;

    if (config.useSsh && config.sshHost != null) {
      await _sshTunnel.connect(config, config.host, config.port);
      host = _sshTunnel.localHost;
      port = _sshTunnel.localPort;
    }

    print('PostgreSQL: Creating connection to $host:$port');
    final conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: config.databaseName ?? 'postgres',
        username: config.username ?? 'postgres',
        password: config.password ?? '',
      ),
      settings: ConnectionSettings(
        sslMode: config.sslEnabled ? SslMode.require : SslMode.disable,
      ),
    );
    print('PostgreSQL: Connection object created, attempting to connect...');

    try {
      await conn.execute('SELECT 1');
      print('PostgreSQL: Connected successfully');
      await conn.close();
      print('PostgreSQL: Connection closed');
    } catch (e) {
      print('PostgreSQL: Connection error - $e');
      await disconnect();
      rethrow;
    }

    await disconnect();
    print('Test completed successfully');
  }

  @override
  Future<void> connect(ConnectionModel config) async {
    print('Connecting to PostgreSQL...');
    String host = config.host;
    int port = config.port;

    if (config.useSsh && config.sshHost != null) {
      await _sshTunnel.connect(config, config.host, config.port);
      host = _sshTunnel.localHost;
      port = _sshTunnel.localPort;
    }

    print('PostgreSQL: Creating connection to $host:$port');
    _connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: config.databaseName ?? 'postgres',
        username: config.username ?? 'postgres',
        password: config.password ?? '',
      ),
      settings: ConnectionSettings(
        sslMode: config.sslEnabled ? SslMode.require : SslMode.disable,
      ),
    );
    _currentDatabase = config.databaseName ?? 'postgres';
    _config = config;
    print('PostgreSQL: Connected successfully');
  }

  @override
  Future<void> disconnect() async {
    await _sshTunnel.disconnect();
    await _connection?.close();
    _connection = null;
    _currentDatabase = null;
  }

  @override
  Future<List<Map<String, dynamic>>> execute(String sql) async {
    if (_connection == null) {
      throw StateError('Not connected');
    }
    final results = await _connection!.execute(sql);
    final List<Map<String, dynamic>> rows = [];
    for (final row in results) {
      final rowMap = <String, dynamic>{};
      for (final column in row.toColumnMap().entries) {
        final value = _convertPostgresValue(column.value);
        rowMap[column.key] = value;
      }
      rows.add(rowMap);
    }
    return rows;
  }

  dynamic _convertPostgresValue(dynamic value) {
    if (value == null) return null;

    if (value is List<int>) {
      return value;
    }

    return value;
  }

  @override
  Future<List<String>> getTables() async {
    if (_currentDatabase == null) {
      throw StateError('No database selected');
    }
    final result = await execute(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public'",
    );
    final List<String> tables = [];
    for (final row in result) {
      tables.add(row['tablename']?.toString() ?? '');
    }
    return tables;
  }

  @override
  Future<List<String>> getDatabases() async {
    final result = await execute(
      "SELECT datname FROM pg_database WHERE datistemplate = false",
    );
    final List<String> databases = [];
    for (final row in result) {
      databases.add(row['datname']?.toString() ?? '');
    }
    return databases;
  }

  @override
  Future<void> useDatabase(String databaseName) async {
    if (_config == null) {
      throw StateError('Cannot switch database: not connected');
    }

    await disconnect();

    String host = _config!.host;
    int port = _config!.port;

    if (_config!.useSsh && _config!.sshHost != null) {
      await _sshTunnel.connect(_config!, _config!.host, _config!.port);
      host = _sshTunnel.localHost;
      port = _sshTunnel.localPort;
    }

    final conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: databaseName,
        username: _config!.username ?? 'postgres',
        password: _config!.password ?? '',
      ),
      settings: ConnectionSettings(
        sslMode: _config!.sslEnabled ? SslMode.require : SslMode.disable,
      ),
    );

    _connection = conn;
    _currentDatabase = databaseName;
    print('PostgreSQL: Switched to database $databaseName');
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
    final result = await execute('''
      SELECT 
        column_name, 
        data_type, 
        is_nullable, 
        column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' 
        AND table_name = '$tableName'
      ORDER BY ordinal_position
    ''');
    final List<ColumnInfo> columns = [];
    for (final row in result) {
      final colName = row['column_name']?.toString();
      final colType = row['data_type']?.toString() ?? '';
      final isNullable = row['is_nullable']?.toString() == 'YES';
      final defaultValue = row['column_default']?.toString();

      if (colName != null && colName.isNotEmpty) {
        columns.add(
          ColumnInfo(
            name: colName,
            type: colType,
            isNullable: isNullable,
            defaultValue: defaultValue,
          ),
        );
      }
    }
    return columns;
  }

  @override
  Future<String?> getPrimaryKeyColumn(String tableName) async {
    final result = await execute('''
      SELECT kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      WHERE tc.constraint_type = 'PRIMARY KEY'
        AND tc.table_schema = 'public'
        AND tc.table_name = '$tableName'
      LIMIT 1
    ''');

    if (result.isNotEmpty) {
      return result.first['column_name']?.toString();
    }
    return null;
  }

  Connection? get connection => _connection;
}
