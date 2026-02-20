import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';
import '../../utils/ssh_helper.dart';
import '../constants/app_constants.dart';
import 'database_driver.dart';

class MySQLDriver implements DatabaseDriver {
  SSHClient? _sshClient;
  ServerSocket? _serverSocket;
  int _localPort = 0;
  MySQLConnection? _connection;

  @override
  Future<void> testConnection(ConnectionModel config) async {
    print('Testing MySQL connection...');
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
        print('SSH Tunnel: Ready to connect MySQL via $host:$port');
      } catch (e) {
        print('SSH Tunnel: Error - $e');
        disconnect();
        throw Exception('SSH Connection Failed: $e');
      }
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
      disconnect();
      rethrow;
    }

    disconnect();
    print('Test completed successfully');
  }

  @override
  Future<void> connect(ConnectionModel config) async {
    print('Connecting to MySQL...');
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
        print('SSH Tunnel: Ready to connect MySQL via $host:$port');
      } catch (e) {
        print('SSH Tunnel: Error - $e');
        disconnect();
        throw Exception('SSH Connection Failed: $e');
      }
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
      disconnect();
      rethrow;
    }
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
