import 'dart:async';
import 'dart:io';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';

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
            keys.addAll(SSHKeyPair.fromPem(keyText, config.sshKeyPassword));
          } else {
            final file = File(keyText);
            if (file.existsSync()) {
              keys.addAll(
                SSHKeyPair.fromPem(
                  file.readAsStringSync(),
                  config.sshKeyPassword,
                ),
              );
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
            final forward = await _sshClient!.forwardLocal(
              config.host,
              config.port,
            );
            print('SSH Tunnel: Forward channel created');

            forward.stream.cast<List<int>>().listen(
              (data) => socket.add(data),
              onError: (e) => print('SSH Tunnel: Forward->Socket error: $e'),
              onDone: () => print('SSH Tunnel: Forward->Socket closed'),
            );

            socket.cast<List<int>>().listen(
              (data) => forward.sink.add(data),
              onError: (e) => print('SSH Tunnel: Socket->Forward error: $e'),
              onDone: () {
                print('SSH Tunnel: Socket->Forward closed');
                forward.sink.close();
                socket.close();
              },
            );
            print('SSH Tunnel: Data piping established');
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
      await conn.connect();
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
            keys.addAll(SSHKeyPair.fromPem(keyText, config.sshKeyPassword));
          } else {
            final file = File(keyText);
            if (file.existsSync()) {
              keys.addAll(
                SSHKeyPair.fromPem(
                  file.readAsStringSync(),
                  config.sshKeyPassword,
                ),
              );
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
            final forward = await _sshClient!.forwardLocal(
              config.host,
              config.port,
            );
            print('SSH Tunnel: Forward channel created');

            forward.stream.cast<List<int>>().listen(
              (data) => socket.add(data),
              onError: (e) => print('SSH Tunnel: Forward->Socket error: $e'),
              onDone: () => print('SSH Tunnel: Forward->Socket closed'),
            );

            socket.cast<List<int>>().listen(
              (data) => forward.sink.add(data),
              onError: (e) => print('SSH Tunnel: Socket->Forward error: $e'),
              onDone: () {
                print('SSH Tunnel: Socket->Forward closed');
                forward.sink.close();
                socket.close();
              },
            );
            print('SSH Tunnel: Data piping established');
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
      await conn.connect();
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
}
