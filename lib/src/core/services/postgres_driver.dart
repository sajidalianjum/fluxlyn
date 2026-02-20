import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';
import '../../utils/ssh_helper.dart';
import '../constants/app_constants.dart';
import 'database_driver.dart';

class PostgreSQLDriver implements DatabaseDriver {
  SSHClient? _sshClient;
  ServerSocket? _serverSocket;
  int _localPort = 0;
  Connection? _connection;
  String? _currentDatabase;
  ConnectionModel? _config;

  @override
  Future<void> testConnection(ConnectionModel config) async {
    print('Testing PostgreSQL connection...');
    String host = config.host;
    int port = config.port;

    if (config.useSsh && config.sshHost != null) {
      print(
        'SSH Tunnel: Connecting to ${config.sshHost}:${config.sshPort ?? AppConstants.portSSH}',
      );
      try {
        final socket = await SSHSocket.connect(
          config.sshHost!,
          config.sshPort ?? AppConstants.portSSH,
          timeout: const Duration(seconds: 10),
        );
        print('SSH Tunnel: Socket connected');

        final List<SSHKeyPair> keys = [];
        if (config.sshPrivateKey != null) {
          final keyText = config.sshPrivateKey!;
          if (keyText.startsWith('-----')) {
            final decryptedKeys = await compute(decryptSSHKeyPairs, [
              keyText,
              config.sshKeyPassword ?? '',
            ]);
            keys.addAll(decryptedKeys);
          } else {
            final file = File(keyText);
            if (file.existsSync()) {
              final keyContent = await file.readAsString();
              final decryptedKeys = await compute(decryptSSHKeyPairs, [
                keyContent,
                config.sshKeyPassword ?? '',
              ]);
              keys.addAll(decryptedKeys);
            }
          }
        }

        _sshClient = SSHClient(
          socket,
          username: config.sshUsername ?? '',
          onPasswordRequest: () => config.sshPassword,
          identities: keys,
          onVerifyHostKey: (host, key) => true,
          keepAliveInterval: const Duration(seconds: 30),
        );
        print('SSH Tunnel: Client created, waiting for authentication...');

        await _sshClient!.authenticated;
        print('SSH Tunnel: Authenticated successfully');

        _serverSocket = await ServerSocket.bind('127.0.0.1', 0);
        _localPort = _serverSocket!.port;
        print('SSH Tunnel: ServerSocket bound to 127.0.0.1:$_localPort');

        _serverSocket!.listen((socket) async {
          try {
            print(
              'SSH Tunnel: New connection received, creating forward channel to ${config.host}:${config.port}',
            );

            final remoteHost = config.host == 'localhost'
                ? '127.0.0.1'
                : config.host;

            try {
              print('SSH Tunnel: Attempting connection via netcat...');
              final session = await _sshClient!.execute(
                'nc $remoteHost ${config.port}',
              );

              bool ncFailed = false;
              session.stderr.listen((data) {
                final err = String.fromCharCodes(data).toLowerCase();
                if (err.contains('not found') ||
                    err.contains('not recognized')) {
                  ncFailed = true;
                }
              });

              await Future.delayed(const Duration(milliseconds: 200));

              if (ncFailed) {
                throw Exception('nc not found');
              }

              print('SSH Tunnel: Netcat session started');
              socket.setOption(SocketOption.tcpNoDelay, true);

              session.stdout.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => session.stdin.add(data),
                onDone: () => session.stdin.close(),
                onError: (e) => session.stdin.close(),
              );

              await session.done;
              print('SSH Tunnel: Netcat session closed');
            } catch (e) {
              print(
                'SSH Tunnel: Netcat failed or not found ($e), falling back to direct-tcpip...',
              );

              final forward = await _sshClient!.forwardLocal(
                remoteHost,
                config.port,
              );
              print('SSH Tunnel: Direct forward channel created');

              socket.setOption(SocketOption.tcpNoDelay, true);

              forward.stream.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => forward.sink.add(data),
                onDone: () => forward.sink.close(),
                onError: (e) => forward.sink.close(),
              );

              await forward.done;
              print('SSH Tunnel: Direct forward channel closed');
            }
          } catch (e) {
            print('SSH Tunnel: Forward error - $e');
            socket.close();
          }
        });
        print('SSH Tunnel: Listener started');

        host = '127.0.0.1';
        port = _localPort;
        print('SSH Tunnel: Ready to connect PostgreSQL via $host:$port');
      } catch (e) {
        print('SSH Tunnel: Error - $e');
        disconnect();
        throw Exception('SSH Connection Failed: $e');
      }
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
      disconnect();
      rethrow;
    }

    disconnect();
    print('Test completed successfully');
  }

  @override
  Future<void> connect(ConnectionModel config) async {
    print('Connecting to PostgreSQL...');
    String host = config.host;
    int port = config.port;

    if (config.useSsh && config.sshHost != null) {
      print(
        'SSH Tunnel: Connecting to ${config.sshHost}:${config.sshPort ?? AppConstants.portSSH}',
      );
      try {
        final socket = await SSHSocket.connect(
          config.sshHost!,
          config.sshPort ?? AppConstants.portSSH,
          timeout: const Duration(seconds: 10),
        );
        print('SSH Tunnel: Socket connected');

        final List<SSHKeyPair> keys = [];
        if (config.sshPrivateKey != null) {
          final keyText = config.sshPrivateKey!;
          if (keyText.startsWith('-----')) {
            final decryptedKeys = await compute(decryptSSHKeyPairs, [
              keyText,
              config.sshKeyPassword ?? '',
            ]);
            keys.addAll(decryptedKeys);
          } else {
            final file = File(keyText);
            if (file.existsSync()) {
              final keyContent = await file.readAsString();
              final decryptedKeys = await compute(decryptSSHKeyPairs, [
                keyContent,
                config.sshKeyPassword ?? '',
              ]);
              keys.addAll(decryptedKeys);
            }
          }
        }

        _sshClient = SSHClient(
          socket,
          username: config.sshUsername ?? '',
          onPasswordRequest: () => config.sshPassword,
          identities: keys,
          onVerifyHostKey: (host, key) => true,
          keepAliveInterval: const Duration(seconds: 30),
        );
        print('SSH Tunnel: Client created, waiting for authentication...');

        await _sshClient!.authenticated;
        print('SSH Tunnel: Authenticated successfully');

        _serverSocket = await ServerSocket.bind('127.0.0.1', 0);
        _localPort = _serverSocket!.port;
        print('SSH Tunnel: ServerSocket bound to 127.0.0.1:$_localPort');

        _serverSocket!.listen((socket) async {
          try {
            print(
              'SSH Tunnel: New connection received, creating forward channel to ${config.host}:${config.port}',
            );

            final remoteHost = config.host == 'localhost'
                ? '127.0.0.1'
                : config.host;

            try {
              print('SSH Tunnel: Attempting connection via netcat...');
              final session = await _sshClient!.execute(
                'nc $remoteHost ${config.port}',
              );

              bool ncFailed = false;
              session.stderr.listen((data) {
                final err = String.fromCharCodes(data).toLowerCase();
                if (err.contains('not found') ||
                    err.contains('not recognized')) {
                  ncFailed = true;
                }
              });

              await Future.delayed(const Duration(milliseconds: 200));

              if (ncFailed) {
                throw Exception('nc not found');
              }

              print('SSH Tunnel: Netcat session started');
              socket.setOption(SocketOption.tcpNoDelay, true);

              session.stdout.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => session.stdin.add(data),
                onDone: () => session.stdin.close(),
                onError: (e) => session.stdin.close(),
              );

              await session.done;
              print('SSH Tunnel: Netcat session closed');
            } catch (e) {
              print(
                'SSH Tunnel: Netcat failed or not found ($e), falling back to direct-tcpip...',
              );

              final forward = await _sshClient!.forwardLocal(
                remoteHost,
                config.port,
              );
              print('SSH Tunnel: Direct forward channel created');

              socket.setOption(SocketOption.tcpNoDelay, true);

              forward.stream.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => forward.sink.add(data),
                onDone: () => forward.sink.close(),
                onError: (e) => forward.sink.close(),
              );

              await forward.done;
              print('SSH Tunnel: Direct forward channel closed');
            }
          } catch (e) {
            print('SSH Tunnel: Forward error - $e');
            socket.close();
          }
        });
        print('SSH Tunnel: Listener started');

        host = '127.0.0.1';
        port = _localPort;
        print('SSH Tunnel: Ready to connect PostgreSQL via $host:$port');
      } catch (e) {
        print('SSH Tunnel: Error - $e');
        disconnect();
        throw Exception('SSH Connection Failed: $e');
      }
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
    await _serverSocket?.close();
    _serverSocket = null;
    if (_sshClient != null) {
      _sshClient!.close();
      _sshClient = null;
    }
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
      print(
        'SSH Tunnel: Connecting to ${_config!.sshHost}:${_config!.sshPort ?? AppConstants.portSSH}',
      );
      try {
        final socket = await SSHSocket.connect(
          _config!.sshHost!,
          _config!.sshPort ?? AppConstants.portSSH,
          timeout: const Duration(seconds: 10),
        );
        print('SSH Tunnel: Socket connected');

        final List<SSHKeyPair> keys = [];
        if (_config!.sshPrivateKey != null) {
          final keyText = _config!.sshPrivateKey!;
          if (keyText.startsWith('-----')) {
            final decryptedKeys = await compute(decryptSSHKeyPairs, [
              keyText,
              _config!.sshKeyPassword ?? '',
            ]);
            keys.addAll(decryptedKeys);
          } else {
            final file = File(keyText);
            if (file.existsSync()) {
              final keyContent = await file.readAsString();
              final decryptedKeys = await compute(decryptSSHKeyPairs, [
                keyContent,
                _config!.sshKeyPassword ?? '',
              ]);
              keys.addAll(decryptedKeys);
            }
          }
        }

        _sshClient = SSHClient(
          socket,
          username: _config!.sshUsername ?? '',
          onPasswordRequest: () => _config!.sshPassword,
          identities: keys,
          onVerifyHostKey: (host, key) => true,
          keepAliveInterval: const Duration(seconds: 30),
        );
        print('SSH Tunnel: Client created, waiting for authentication...');

        await _sshClient!.authenticated;
        print('SSH Tunnel: Authenticated successfully');

        _serverSocket = await ServerSocket.bind('127.0.0.1', 0);
        _localPort = _serverSocket!.port;
        print('SSH Tunnel: ServerSocket bound to 127.0.0.1:$_localPort');

        _serverSocket!.listen((socket) async {
          try {
            print(
              'SSH Tunnel: New connection received, creating forward channel to ${_config!.host}:${_config!.port}',
            );

            final remoteHost = _config!.host == 'localhost'
                ? '127.0.0.1'
                : _config!.host;

            try {
              print('SSH Tunnel: Attempting connection via netcat...');
              final session = await _sshClient!.execute(
                'nc $remoteHost ${_config!.port}',
              );

              bool ncFailed = false;
              session.stderr.listen((data) {
                final err = String.fromCharCodes(data).toLowerCase();
                if (err.contains('not found') ||
                    err.contains('not recognized')) {
                  ncFailed = true;
                }
              });

              await Future.delayed(const Duration(milliseconds: 200));

              if (ncFailed) {
                throw Exception('nc not found');
              }

              print('SSH Tunnel: Netcat session started');
              socket.setOption(SocketOption.tcpNoDelay, true);

              session.stdout.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => session.stdin.add(data),
                onDone: () => session.stdin.close(),
                onError: (e) => session.stdin.close(),
              );

              await session.done;
              print('SSH Tunnel: Netcat session closed');
            } catch (e) {
              print(
                'SSH Tunnel: Netcat failed or not found ($e), falling back to direct-tcpip...',
              );

              final forward = await _sshClient!.forwardLocal(
                remoteHost,
                _config!.port,
              );
              print('SSH Tunnel: Direct forward channel created');

              socket.setOption(SocketOption.tcpNoDelay, true);

              forward.stream.listen(
                (data) => socket.add(data),
                onDone: () => socket.close(),
                onError: (e) => socket.close(),
              );

              socket.listen(
                (data) => forward.sink.add(data),
                onDone: () => forward.sink.close(),
                onError: (e) => forward.sink.close(),
              );

              await forward.done;
              print('SSH Tunnel: Direct forward channel closed');
            }
          } catch (e) {
            print('SSH Tunnel: Forward error - $e');
            socket.close();
          }
        });
        print('SSH Tunnel: Listener started');

        host = '127.0.0.1';
        port = _localPort;
        print('SSH Tunnel: Ready to connect PostgreSQL via $host:$port');
      } catch (e) {
        print('SSH Tunnel: Error - $e');
        disconnect();
        throw Exception('SSH Connection Failed: $e');
      }
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
