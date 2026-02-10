import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';
import '../../utils/ssh_helper.dart';

class DatabaseService {
  SSHClient? _sshClient;
  ServerSocket? _serverSocket;
  int _localPort = 0;

  Future<void> testConnection(ConnectionModel config) async {
    if (config.type == ConnectionType.mysql) {
      await _testMySQL(config);
    } else {
      throw UnimplementedError('PostgreSQL not supported yet');
    }
  }

  Future<void> _testMySQL(ConnectionModel config) async {
    print('Testing MySQL connection...');
    String host = config.host;
    int port = config.port;

    // SSH Tunneling Logic
    if (config.useSsh && config.sshHost != null) {
      print(
        'SSH Tunnel: Connecting to ${config.sshHost}:${config.sshPort ?? 22}',
      );
      try {
        final socket = await SSHSocket.connect(
          config.sshHost!,
          config.sshPort ?? 22,
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

              // We need to check if nc actually started or failed immediately (e.g. command not found)
              // We'll give it a tiny bit of time to see if it closes with an error
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

  // --- New Methods ---

  Future<MySQLConnection> connect(ConnectionModel config) async {
    print('Connecting to MySQL...');
    String host = config.host;
    int port = config.port;

    // SSH Tunneling Logic
    if (config.useSsh && config.sshHost != null) {
      print(
        'SSH Tunnel: Connecting to ${config.sshHost}:${config.sshPort ?? 22}',
      );
      try {
        final socket = await SSHSocket.connect(
          config.sshHost!,
          config.sshPort ?? 22,
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

              // We need to check if nc actually started or failed immediately (e.g. command not found)
              // We'll give it a tiny bit of time to see if it closes with an error
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
      return conn;
    } catch (e) {
      print('MySQL: Connection error - $e');
      disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _serverSocket?.close();
    _serverSocket = null;
    if (_sshClient != null) {
      _sshClient!.close();
      _sshClient = null;
    }
  }

  Future<IResultSet> execute(MySQLConnection conn, String sql) async {
    return await conn.execute(sql);
  }

  Future<List<String>> getTables(MySQLConnection conn) async {
    final result = await conn.execute('SHOW TABLES');
    final List<String> tables = [];
    for (final row in result.rows) {
      tables.add(row.colAt(0)?.toString() ?? '');
    }
    return tables;
  }

  Future<List<String>> getDatabases(MySQLConnection conn) async {
    final result = await conn.execute('SHOW DATABASES');
    final List<String> databases = [];
    for (final row in result.rows) {
      databases.add(row.colAt(0)?.toString() ?? '');
    }
    return databases;
  }

  Future<void> useDatabase(MySQLConnection conn, String databaseName) async {
    await conn.execute('USE `$databaseName`');
  }

  Future<bool> isConnected(MySQLConnection conn) async {
    try {
      final result = await conn.execute('SELECT 1');
      return result != null;
    } catch (e) {
      return false;
    }
  }
}
