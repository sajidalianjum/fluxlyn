import 'dart:async';
import 'package:postgres/postgres.dart';
import '../../features/connections/models/connection_model.dart';
import 'database_driver.dart';
import 'ssh_tunnel_service.dart';
import '../models/exceptions.dart';
import '../utils/error_reporter.dart';

class PostgresExecutionResult {
  final List<Map<String, dynamic>> rows;
  final int? affectedRowCount;

  PostgresExecutionResult({required this.rows, this.affectedRowCount});
}

class PostgreSQLDriver implements DatabaseDriver {
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const Duration _sshTimeout = Duration(seconds: 30);

  final SSHTunnelService _sshTunnel = SSHTunnelService();
  Connection? _connection;
  String? _currentDatabase;
  ConnectionModel? _config;
  bool _isConnecting = false;
  String? _currentConnectionName;

  @override
  Future<void> testConnection(
    ConnectionModel config,
    HostKeyVerifyCallback? hostKeyVerify,
  ) async {
    _currentConnectionName = config.name;
    ErrorReporter.info(
      'Testing PostgreSQL connection to ${config.host}:${config.port}',
      'PostgreSQLDriver.testConnection',
      'postgres_driver.dart:30',
    );
    String host = config.host;
    int port = config.port;

    try {
      if (config.useSsh && config.sshHost != null) {
        await _sshTunnel.connect(
          config,
          config.host,
          config.port,
          hostKeyVerify,
        );
        host = _sshTunnel.localHost;
        port = _sshTunnel.localPort;
      }

      ErrorReporter.info(
        'PostgreSQL: Creating connection to $host:$port',
        'PostgreSQLDriver.testConnection',
        'postgres_driver.dart:41',
      );
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
          connectTimeout: config.useSsh ? _sshTimeout : _defaultTimeout,
        ),
      );

      try {
        await conn
            .execute('SELECT 1')
            .timeout(
              config.useSsh ? _sshTimeout : _defaultTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Connection timeout after ${(config.useSsh ? _sshTimeout : _defaultTimeout).inSeconds} seconds',
                  timeout: config.useSsh ? _sshTimeout : _defaultTimeout,
                  operation: 'testConnection',
                );
              },
            );
        ErrorReporter.info(
          'PostgreSQL: Connected successfully',
          'PostgreSQLDriver.testConnection',
          'postgres_driver.dart:69',
        );
        await conn.close();
        ErrorReporter.info(
          'PostgreSQL: Connection closed',
          'PostgreSQLDriver.testConnection',
          'postgres_driver.dart:71',
        );
      } catch (e) {
        ErrorReporter.error(
          'PostgreSQL: Connection error - $e',
          StackTrace.current,
          'PostgreSQLDriver.testConnection',
          'postgres_driver.dart:73',
        );
        await conn.close().catchError((_) {});
        throw ConnectionException(
          'Failed to connect to PostgreSQL: ${e.toString()}',
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
  Future<void> connect(
    ConnectionModel config,
    HostKeyVerifyCallback? hostKeyVerify,
  ) async {
    if (_isConnecting) {
      throw ConnectionException(
        'Connection already in progress',
        connectionName: config.name,
      );
    }

    _isConnecting = true;
    _currentConnectionName = config.name;
    ErrorReporter.info(
      'Connecting to PostgreSQL',
      'PostgreSQLDriver.connect',
      'postgres_driver.dart:111',
    );
    String host = config.host;
    int port = config.port;

    try {
      if (_connection != null) {
        await disconnect().catchError((_) {});
      }

      if (config.useSsh && config.sshHost != null) {
        await _sshTunnel.connect(
          config,
          config.host,
          config.port,
          hostKeyVerify,
        );
        host = _sshTunnel.localHost;
        port = _sshTunnel.localPort;
      }

      ErrorReporter.info(
        'PostgreSQL: Creating connection to $host:$port',
        'PostgreSQLDriver.connect',
        'postgres_driver.dart:126',
      );
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
          connectTimeout: config.useSsh ? _sshTimeout : _defaultTimeout,
        ),
      );

      final timeout = config.useSsh ? _sshTimeout : _defaultTimeout;
      await _connection!
          .execute('SELECT 1')
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout after ${timeout.inSeconds} seconds',
                timeout: timeout,
                operation: 'connect',
              );
            },
          );

      _currentDatabase = config.databaseName ?? 'postgres';
      _config = config;
      ErrorReporter.info(
        'PostgreSQL: Connected successfully',
        'PostgreSQLDriver.connect',
        'postgres_driver.dart:157',
      );
    } on TimeoutException {
      await _cleanupResources();
      rethrow;
    } on ConnectionException {
      rethrow;
    } catch (e) {
      await _cleanupResources();
      throw ConnectionException(
        'Failed to connect to PostgreSQL: ${e.toString()}',
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
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error disconnecting SSH tunnel: $e',
        stackTrace,
        'PostgreSQLDriver.disconnect',
        'postgres_driver.dart:182',
      );
    }
    try {
      await _connection?.close();
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error closing PostgreSQL connection: $e',
        stackTrace,
        'PostgreSQLDriver.disconnect',
        'postgres_driver.dart:187',
      );
    }
    _connection = null;
    _currentDatabase = null;
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
  Future<PostgresExecutionResult> execute(String sql) async {
    if (_connection == null) {
      throw DatabaseException(
        'Not connected to database',
        operation: 'execute',
        connectionName: _currentConnectionName,
      );
    }

    try {
      final results = await _connection!
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

      final List<Map<String, dynamic>> rows = [];
      int? affectedRowCount;

      for (final row in results) {
        final rowMap = <String, dynamic>{};
        for (final column in row.toColumnMap().entries) {
          final value = _convertPostgresValue(column.value);
          rowMap[column.key] = value;
        }
        rows.add(rowMap);
      }

      return PostgresExecutionResult(
        rows: rows,
        affectedRowCount: affectedRowCount,
      );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw QueryException(
        'Failed to execute query: ${e.toString()}',
        query: sql.length > 500 ? '${sql.substring(0, 500)}...' : sql,
        database: _currentDatabase,
        originalError: e,
      );
    }
  }

  dynamic _convertPostgresValue(dynamic value) {
    if (value == null) return null;

    if (value is List<int>) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is num) {
      if (value is int) return value;
      return value.toDouble();
    }

    final typeName = value.runtimeType.toString();

    if (typeName.contains('UndecodedBytes')) {
      try {
        final bytes = _extractBytesFromUndecodedBytes(value);
        if (bytes != null && bytes.isNotEmpty) {
          return String.fromCharCodes(bytes);
        }
      } catch (e) {
        return value.toString();
      }
      return value.toString();
    }

    if (typeName.contains('Time') && value is! String) {
      try {
        final hour = (value.hour as int).toString().padLeft(2, '0');
        final minute = (value.minute as int).toString().padLeft(2, '0');
        final second = (value.second as int).toString().padLeft(2, '0');
        final microsecond = (value.microsecond as int).toString().padLeft(
          6,
          '0',
        );
        return '$hour:$minute:$second.$microsecond';
      } catch (_) {
        return value.toString();
      }
    }

    return value.toString();
  }

  List<int>? _extractBytesFromUndecodedBytes(dynamic undecodedBytes) {
    try {
      if (undecodedBytes is! Map &&
          undecodedBytes is! List &&
          undecodedBytes is! String &&
          undecodedBytes is! num) {
        try {
          final dynamic bytesField = (undecodedBytes as dynamic).bytes;
          if (bytesField is List<int>) {
            return bytesField;
          }
        } catch (_) {}
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<String>> getTables() async {
    if (_currentDatabase == null) {
      throw DatabaseException(
        'No database selected',
        operation: 'getTables',
        connectionName: _currentConnectionName,
      );
    }

    try {
      final result = await execute(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public'",
      );
      final List<String> tables = [];
      for (final row in result.rows) {
        final tableName = row['tablename']?.toString() ?? '';
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
      final result = await execute(
        "SELECT datname FROM pg_database WHERE datistemplate = false",
      );
      final List<String> databases = [];
      for (final row in result.rows) {
        final dbName = row['datname']?.toString() ?? '';
        if (dbName.isNotEmpty &&
            dbName != 'postgres' &&
            dbName != 'template0' &&
            dbName != 'template1') {
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
    if (_config == null) {
      throw DatabaseException(
        'Cannot switch database: not connected',
        operation: 'useDatabase',
        connectionName: _currentConnectionName,
      );
    }

    try {
      await disconnect();

      String host = _config!.host;
      int port = _config!.port;

      if (_config!.useSsh && _config!.sshHost != null) {
        await _sshTunnel.connect(
          _config!,
          _config!.host,
          _config!.port,
          null,
        );
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
          connectTimeout: _config!.useSsh ? _sshTimeout : _defaultTimeout,
        ),
      );

      final timeout = _config!.useSsh ? _sshTimeout : _defaultTimeout;
      await conn
          .execute('SELECT 1')
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout after ${timeout.inSeconds} seconds',
                timeout: timeout,
                operation: 'useDatabase',
              );
            },
          );

      _connection = conn;
      _currentDatabase = databaseName;
      ErrorReporter.info(
        'PostgreSQL: Switched to database $databaseName',
        'PostgreSQLDriver.useDatabase',
        'postgres_driver.dart:438',
      );
    } on TimeoutException {
      await _cleanupResources();
      rethrow;
    } catch (e) {
      await _cleanupResources();
      throw DatabaseException(
        'Failed to switch to database $databaseName: ${e.toString()}',
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
      for (final row in result.rows) {
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

      if (result.rows.isNotEmpty) {
        return result.rows.first['column_name']?.toString();
      }
      return null;
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;
      ErrorReporter.warning(
        'Error getting primary key for $tableName: $e',
        stackTrace,
        'PostgreSQLDriver.getPrimaryKeyColumn',
        'postgres_driver.dart:529',
      );
      return null;
    }
  }

  @override
  Future<Map<String, List<String>>> getEnumColumns(String tableName) async {
    try {
      final result = await execute('''
      SELECT
        c.column_name,
        t.typname as enum_type_name
      FROM information_schema.columns c
      JOIN pg_type t ON c.udt_name = t.typname
      WHERE c.table_schema = 'public'
        AND c.table_name = '$tableName'
        AND t.typtype = 'e'
      ORDER BY c.ordinal_position
    ''');

      final Map<String, List<String>> enumColumns = {};

      for (final row in result.rows) {
        final columnName = row['column_name']?.toString();
        final enumTypeName = row['enum_type_name']?.toString();

        if (columnName != null && enumTypeName != null) {
          final enumValues = await _getEnumValues(enumTypeName);
          if (enumValues.isNotEmpty) {
            enumColumns[columnName] = enumValues;
          }
        }
      }

      return enumColumns;
    } catch (e, stackTrace) {
      if (e is DatabaseException) rethrow;
      ErrorReporter.warning(
        'Error getting enum columns for $tableName: $e',
        stackTrace,
        'PostgreSQLDriver.getEnumColumns',
        'postgres_driver.dart:566',
      );
      return {};
    }
  }

  Future<List<String>> _getEnumValues(String enumTypeName) async {
    try {
      final result = await execute('''
      SELECT e.enumlabel
      FROM pg_enum e
      JOIN pg_type t ON e.enumtypid = t.oid
      WHERE t.typname = '$enumTypeName'
      ORDER BY e.enumsortorder
    ''');

      final List<String> enumValues = [];
      for (final row in result.rows) {
        final enumLabel = row['enumlabel']?.toString();
        if (enumLabel != null && enumLabel.isNotEmpty) {
          enumValues.add(enumLabel);
        }
      }

      return enumValues;
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error getting enum values for $enumTypeName: $e',
        stackTrace,
        'PostgreSQLDriver._getEnumValues',
        'postgres_driver.dart:591',
      );
      return [];
    }
  }

  Connection? get connection => _connection;
}
