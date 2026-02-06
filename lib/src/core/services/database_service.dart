import 'dart:async';
import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:dartssh2/dartssh2.dart';
import '../../features/connections/models/connection_model.dart';

class DatabaseService {
  SSHClient? _sshClient;
  
  Future<void> testConnection(ConnectionModel config) async {
    if (config.type == ConnectionType.mysql) {
      await _testMySQL(config);
    } else {
      throw UnimplementedError('PostgreSQL not supported yet');
    }
  }

  Future<void> _testMySQL(ConnectionModel config) async {
    String host = config.host;
    int port = config.port;

    // SSH Tunneling Logic
    if (config.useSsh && config.sshHost != null) {
      try {
        final socket = await SSHSocket.connect(
          config.sshHost!,
          config.sshPort ?? 22,
          timeout: const Duration(seconds: 10),
        );

        final List<SSHKeyPair> keys = [];
        if (config.sshPrivateKey != null) {
           final keyText = config.sshPrivateKey!;
           if (keyText.startsWith('-----')) {
              keys.addAll(SSHKeyPair.fromPem(keyText, config.sshKeyPassword));
           } else {
              final file = File(keyText);
              if (file.existsSync()) {
                keys.addAll(SSHKeyPair.fromPem(file.readAsStringSync(), config.sshKeyPassword));
              }
           }
        }

        _sshClient = SSHClient(
          socket,
          username: config.sshUsername ?? '',
          onPasswordRequest: () => config.sshPassword,
          identities: keys,
        );
        
        await _sshClient!.authenticated;

        // Forward local port to DB host
        final dynamic server = await _sshClient!.forwardLocal(
           config.host,
           config.port,
           localHost: '127.0.0.1', 
           localPort: 0,
        );
        
        host = '127.0.0.1';
        port = server.port;

      } catch (e) {
        throw Exception('SSH Connection Failed: $e');
      }
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
      await conn.connect();
      await conn.close();
    } catch (e) {
      if (_sshClient != null) {
          _sshClient!.close();
          _sshClient!.done;
      }
      rethrow;
    }
    
    if (_sshClient != null) {
        _sshClient!.close();
        _sshClient!.done;
    }
  }

  // --- New Methods ---

  Future<MySQLConnection> connect(ConnectionModel config) async {
    String host = config.host;
    int port = config.port;

    // SSH Tunneling Logic
    if (config.useSsh && config.sshHost != null) {
      try {
        final socket = await SSHSocket.connect(
          config.sshHost!,
          config.sshPort ?? 22,
          timeout: const Duration(seconds: 10),
        );

        final List<SSHKeyPair> keys = [];
        if (config.sshPrivateKey != null) {
          final keyText = config.sshPrivateKey!;
          if (keyText.startsWith('-----')) {
            keys.addAll(SSHKeyPair.fromPem(keyText, config.sshKeyPassword));
          } else {
            final file = File(keyText);
            if (file.existsSync()) {
              keys.addAll(SSHKeyPair.fromPem(file.readAsStringSync(), config.sshKeyPassword));
            }
          }
        }

        _sshClient = SSHClient(
          socket,
          username: config.sshUsername ?? '',
          onPasswordRequest: () => config.sshPassword,
          identities: keys,
        );
        
        await _sshClient!.authenticated;

        // Forward local port
        final dynamic server = await _sshClient!.forwardLocal(
           config.host,
           config.port,
           localHost: '127.0.0.1', 
           localPort: 0,
        );
        
        host = '127.0.0.1';
        port = server.port;

      } catch (e) {
        disconnect();
        throw Exception('SSH Connection Failed: $e');
      }
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
        await conn.connect();
        return conn;
    } catch (e) {
        disconnect();
        rethrow;
    }
  }

  Future<void> disconnect() async {
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
        tables.add(row.colAt(0) ?? '');
    }
    return tables;
  }

  Future<List<String>> getDatabases(MySQLConnection conn) async {
    final result = await conn.execute('SHOW DATABASES');
    final List<String> databases = [];
    for (final row in result.rows) {
        databases.add(row.colAt(0) ?? '');
    }
    return databases;
  }

  Future<void> useDatabase(MySQLConnection conn, String databaseName) async {
      await conn.execute('USE `$databaseName`');
  }
}
