import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mysql_dart/mysql_dart.dart';
import '../../features/connections/models/connection_model.dart';
import 'database_driver.dart';
import 'ssh_tunnel_service.dart';
import '../models/exceptions.dart';

class MySQLDriver implements DatabaseDriver {
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const Duration _sshTimeout = Duration(seconds: 30);

  final SSHTunnelService _sshTunnel = SSHTunnelService();
  MySQLConnection? _connection;
  bool _isConnecting = false;
  String? _currentConnectionName;

  @override
  Future<void> testConnection(ConnectionModel config) async {
    _currentConnectionName = config.name;
    print('Testing MySQL connection to ${config.host}:${config.port}...');
    String host = config.host;
    int port = config.port;

    try {
      if (config.useSsh && config.sshHost != null) {
        await _sshTunnel.connect(config, config.host, config.port);
        host = _sshTunnel.localHost;
        port = _sshTunnel.localPort;
      }

      final conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: config.username ?? '',
        password: config.password ?? '',
        databaseName: config.databaseName ?? '',
        secure: config.sslEnabled,
      );

      try {
        final timeoutMs = config.useSsh ? _sshTimeout : _defaultTimeout;
        await conn.connect(timeoutMs: timeoutMs.inMilliseconds);
        print('MySQL: Connected successfully');
        await conn.close();
        print('MySQL: Connection closed');
      } catch (e) {
        print('MySQL: Connection error - $e');
        await conn.close().catchError((_) {});
        throw ConnectionException(
          'Failed to connect to MySQL: ${e.toString()}',
          connectionName: config.name,
          host: host,
          port: port,
          originalError: e,
        );
      }
    } on ConnectionException {
      rethrow;
    } catch (e) {
      await _sshTunnel.disconnect().catchError((_) {});
      throw ConnectionException(
        'Connection test failed: ${e.toString()}',
        connectionName: config.name,
        host: host,
        port: port,
        originalError: e,
      );
    } finally {
      await _sshTunnel.disconnect().catchError((_) {});
      _currentConnectionName = null;
    }
  }

  @override
  Future<void> connect(ConnectionModel config) async {
    if (_isConnecting) {
      throw ConnectionException(
        'Connection already in progress',
        connectionName: config.name,
      );
    }

    _isConnecting = true;
    _currentConnectionName = config.name;
    print('Connecting to MySQL...');
    String host = config.host;
    int port = config.port;

    try {
      if (_connection != null) {
        await disconnect().catchError((_) {});
      }

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

      final timeoutMs = config.useSsh ? _sshTimeout : _defaultTimeout;
      await _connection!
          .connect(timeoutMs: timeoutMs.inMilliseconds)
          .timeout(
            timeoutMs,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout after ${timeoutMs.inSeconds} seconds',
                timeout: timeoutMs,
                operation: 'connect',
              );
            },
          );

      print('MySQL: Connected successfully');
    } on TimeoutException {
      await _cleanupResources();
      rethrow;
    } on ConnectionException {
      rethrow;
    } catch (e) {
      await _cleanupResources();
      throw ConnectionException(
        'Failed to connect to MySQL: ${e.toString()}',
        connectionName: config.name,
        host: host,
        port: port,
        originalError: e,
      );
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _sshTunnel.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting SSH tunnel: $e');
    }

    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (e) {
        debugPrint('Error closing MySQL connection: $e');
      }
    }
    _connection = null;
    _currentConnectionName = null;
  }

  Future<void> _cleanupResources() async {
    try {
      if (_connection != null) {
        await _connection!.close().catchError((_) {});
      }
    } catch (_) {}
    try {
      await _sshTunnel.disconnect().catchError((_) {});
    } catch (_) {}
    _connection = null;
  }

  @override
  Future<IResultSet> execute(String sql) async {
    if (_connection == null) {
      throw DatabaseException(
        'Not connected to database',
        operation: 'execute',
        connectionName: _currentConnectionName,
      );
    }

    try {
      return await _connection!
          .execute(sql)
          .timeout(
            _defaultTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Query timeout after ${_defaultTimeout.inSeconds} seconds',
                timeout: _defaultTimeout,
                operation: 'execute',
              );
            },
          );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw QueryException(
        'Failed to execute query: ${e.toString()}',
        query: sql.length > 500 ? '${sql.substring(0, 500)}...' : sql,
        database: _currentConnectionName,
        originalError: e,
      );
    }
  }

  @override
  Future<List<String>> getTables() async {
    try {
      final result = await execute('SHOW TABLES');
      final List<String> tables = [];
      for (final row in result.rows) {
        final tableName = row.colAt(0)?.toString() ?? '';
        if (tableName.isNotEmpty) {
          tables.add(tableName);
        }
      }
      return tables;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to get tables: ${e.toString()}',
        operation: 'getTables',
        connectionName: _currentConnectionName,
        originalError: e,
      );
    }
  }

  @override
  Future<List<String>> getDatabases() async {
    try {
      final result = await execute('SHOW DATABASES');
      final List<String> databases = [];
      for (final row in result.rows) {
        final dbName = row.colAt(0)?.toString() ?? '';
        if (dbName.isNotEmpty &&
            dbName != 'information_schema' &&
            dbName != 'mysql' &&
            dbName != 'performance_schema' &&
            dbName != 'sys') {
          databases.add(dbName);
        }
      }
      return databases;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to get databases: ${e.toString()}',
        operation: 'getDatabases',
        connectionName: _currentConnectionName,
        originalError: e,
      );
    }
  }

  @override
  Future<void> useDatabase(String databaseName) async {
    try {
      await execute('USE `$databaseName`');
    } catch (e) {
      throw DatabaseException(
        'Failed to select database: ${e.toString()}',
        operation: 'useDatabase',
        connectionName: _currentConnectionName,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isConnected() async {
    if (_connection == null) return false;
    try {
      await execute('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ColumnInfo>> getColumns(String tableName) async {
    try {
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
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to get columns for table $tableName: ${e.toString()}',
        operation: 'getColumns',
        connectionName: _currentConnectionName,
        originalError: e,
      );
    }
  }

  @override
  Future<String?> getPrimaryKeyColumn(String tableName) async {
    try {
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
    } catch (e) {
      if (e is DatabaseException) rethrow;
      debugPrint('Error getting primary key for $tableName: $e');
      return null;
    }
  }

  MySQLConnection? get connection => _connection;
}
