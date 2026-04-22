import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';

void main() {
  group('ConnectionType', () {
    test('has correct enum values', () {
      expect(ConnectionType.values.length, 2);
      expect(ConnectionType.values, contains(ConnectionType.mysql));
      expect(ConnectionType.values, contains(ConnectionType.postgresql));
    });
  });

  group('ConnectionTag', () {
    test('has correct enum values', () {
      expect(ConnectionTag.values.length, 7);
      expect(ConnectionTag.values, contains(ConnectionTag.none));
      expect(ConnectionTag.values, contains(ConnectionTag.development));
      expect(ConnectionTag.values, contains(ConnectionTag.production));
      expect(ConnectionTag.values, contains(ConnectionTag.testing));
      expect(ConnectionTag.values, contains(ConnectionTag.staging));
      expect(ConnectionTag.values, contains(ConnectionTag.local));
      expect(ConnectionTag.values, contains(ConnectionTag.custom));
    });
  });

  group('ConnectionModel', () {
    group('constructor', () {
      test('creates connection with default values', () {
        final connection = ConnectionModel(
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        expect(connection.name, 'Test');
        expect(connection.host, 'localhost');
        expect(connection.port, 3306);
        expect(connection.type, ConnectionType.mysql);
        expect(connection.sslEnabled, true);
        expect(connection.isConnected, false);
        expect(connection.useSsh, false);
        expect(connection.tag, ConnectionTag.none);
        expect(connection.id, isNotEmpty);
      });

      test('creates connection with custom values', () {
        final connection = ConnectionModel(
          name: 'Production DB',
          host: 'db.example.com',
          port: 5432,
          username: 'admin',
          password: 'secret',
          type: ConnectionType.postgresql,
          sslEnabled: false,
          useSsh: true,
          sshHost: 'ssh.example.com',
          sshPort: 2222,
          sshUsername: 'sshuser',
          sshPassword: 'sshpass',
          databaseName: 'mydb',
          tag: ConnectionTag.production,
          sortOrder: 5,
        );

        expect(connection.name, 'Production DB');
        expect(connection.host, 'db.example.com');
        expect(connection.port, 5432);
        expect(connection.username, 'admin');
        expect(connection.password, 'secret');
        expect(connection.type, ConnectionType.postgresql);
        expect(connection.sslEnabled, false);
        expect(connection.useSsh, true);
        expect(connection.sshHost, 'ssh.example.com');
        expect(connection.sshPort, 2222);
        expect(connection.sshUsername, 'sshuser');
        expect(connection.sshPassword, 'sshpass');
        expect(connection.databaseName, 'mydb');
        expect(connection.tag, ConnectionTag.production);
        expect(connection.sortOrder, 5);
      });

      test('generates unique id when not provided', () {
        final conn1 = ConnectionModel(name: 'A', host: 'h1', port: 3306);
        final conn2 = ConnectionModel(name: 'B', host: 'h2', port: 3306);

        expect(conn1.id, isNotEmpty);
        expect(conn2.id, isNotEmpty);
        expect(conn1.id, isNot(conn2.id));
      });

      test('uses provided id when specified', () {
        final connection = ConnectionModel(
          id: 'custom-id-123',
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        expect(connection.id, 'custom-id-123');
      });

      test('uses custom tag when provided', () {
        final connection = ConnectionModel(
          name: 'Test',
          host: 'localhost',
          port: 3306,
          customTag: 'My Custom Tag',
          tag: ConnectionTag.custom,
        );

        expect(connection.tag, ConnectionTag.custom);
        expect(connection.customTag, 'My Custom Tag');
      });
    });

    group('toJson', () {
      test('serializes MySQL connection correctly', () {
        final connection = ConnectionModel(
          id: 'test-id',
          name: 'MySQL DB',
          host: 'localhost',
          port: 3306,
          username: 'root',
          password: 'pass',
          type: ConnectionType.mysql,
          sslEnabled: true,
          tag: ConnectionTag.development,
          sortOrder: 0,
        );

        final json = connection.toJson();

        expect(json['id'], 'test-id');
        expect(json['name'], 'MySQL DB');
        expect(json['host'], 'localhost');
        expect(json['port'], 3306);
        expect(json['username'], 'root');
        expect(json['password'], 'pass');
        expect(json['type'], 'ConnectionType.mysql');
        expect(json['sslEnabled'], true);
        expect(json['useSsh'], false);
        expect(json['tag'], 'ConnectionTag.development');
        expect(json['sortOrder'], 0);
      });

      test('serializes PostgreSQL connection correctly', () {
        final connection = ConnectionModel(
          id: 'pg-id',
          name: 'PostgreSQL',
          host: 'pg.example.com',
          port: 5432,
          type: ConnectionType.postgresql,
          databaseName: 'testdb',
        );

        final json = connection.toJson();

        expect(json['type'], 'ConnectionType.postgresql');
        expect(json['databaseName'], 'testdb');
        expect(json['port'], 5432);
      });

      test('serializes SSH connection correctly', () {
        final connection = ConnectionModel(
          id: 'ssh-id',
          name: 'SSH Tunnel',
          host: 'localhost',
          port: 3306,
          useSsh: true,
          sshHost: 'ssh.server.com',
          sshPort: 22,
          sshUsername: 'sshuser',
          sshPassword: 'sshpass',
          sshPrivateKey: '/path/to/key',
          sshKeyPassword: 'keypass',
        );

        final json = connection.toJson();

        expect(json['useSsh'], true);
        expect(json['sshHost'], 'ssh.server.com');
        expect(json['sshPort'], 22);
        expect(json['sshUsername'], 'sshuser');
        expect(json['sshPassword'], 'sshpass');
        expect(json['sshPrivateKey'], '/path/to/key');
        expect(json['sshKeyPassword'], 'keypass');
      });

      test('handles null values in JSON', () {
        final connection = ConnectionModel(
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        final json = connection.toJson();

        expect(json['username'], null);
        expect(json['password'], null);
        expect(json['databaseName'], null);
        expect(json['sshHost'], null);
        expect(json['sshPrivateKey'], null);
      });
    });

    group('fromJson', () {
      test('deserializes MySQL connection correctly', () {
        final json = {
          'id': 'test-id',
          'name': 'MySQL DB',
          'host': 'localhost',
          'port': 3306,
          'username': 'root',
          'password': 'pass',
          'type': 'ConnectionType.mysql',
          'sslEnabled': true,
          'useSsh': false,
          'tag': 'ConnectionTag.development',
          'sortOrder': 0,
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.id, 'test-id');
        expect(connection.name, 'MySQL DB');
        expect(connection.host, 'localhost');
        expect(connection.port, 3306);
        expect(connection.username, 'root');
        expect(connection.password, 'pass');
        expect(connection.type, ConnectionType.mysql);
        expect(connection.sslEnabled, true);
        expect(connection.useSsh, false);
        expect(connection.tag, ConnectionTag.development);
        expect(connection.sortOrder, 0);
      });

      test('deserializes PostgreSQL connection correctly', () {
        final json = {
          'id': 'pg-id',
          'name': 'PostgreSQL',
          'host': 'pg.example.com',
          'port': 5432,
          'type': 'ConnectionType.postgresql',
          'sslEnabled': false,
          'databaseName': 'testdb',
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.type, ConnectionType.postgresql);
        expect(connection.port, 5432);
        expect(connection.databaseName, 'testdb');
        expect(connection.sslEnabled, false);
      });

      test('deserializes with string containing postgresql', () {
        final json = {
          'name': 'Test',
          'host': 'localhost',
          'port': 5432,
          'type': 'postgresql',
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.type, ConnectionType.postgresql);
      });

      test('defaults to MySQL for unknown type', () {
        final json = {
          'name': 'Test',
          'host': 'localhost',
          'port': 3306,
          'type': 'unknown',
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.type, ConnectionType.mysql);
      });

      test('handles missing optional fields', () {
        final json = {
          'name': 'Test',
          'host': 'localhost',
          'port': 3306,
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.username, null);
        expect(connection.password, null);
        expect(connection.sslEnabled, false);
        expect(connection.useSsh, false);
        expect(connection.tag, ConnectionTag.none);
        expect(connection.isConnected, false);
      });

      test('handles all tag values correctly', () {
        for (final tag in [
          'ConnectionTag.development',
          'ConnectionTag.production',
          'ConnectionTag.testing',
          'ConnectionTag.staging',
          'ConnectionTag.local',
          'ConnectionTag.custom',
        ]) {
          final json = {
            'name': 'Test',
            'host': 'localhost',
            'port': 3306,
            'tag': tag,
          };

          final connection = ConnectionModel.fromJson(json);

          expect(
            connection.tag!.name,
            tag.replaceFirst('ConnectionTag.', ''),
          );
        }
      });

      test('defaults to none tag for unknown tag string', () {
        final json = {
          'name': 'Test',
          'host': 'localhost',
          'port': 3306,
          'tag': 'ConnectionTag.unknown',
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.tag, ConnectionTag.none);
      });

      test('generates new id when id missing', () {
        final json = {
          'name': 'Test',
          'host': 'localhost',
          'port': 3306,
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.id, isNotEmpty);
      });

      test('resets isConnected to false on deserialization', () {
        final json = {
          'name': 'Test',
          'host': 'localhost',
          'port': 3306,
          'isConnected': true,
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.isConnected, false);
      });

      test('handles SSH fields correctly', () {
        final json = {
          'name': 'SSH Test',
          'host': 'localhost',
          'port': 3306,
          'useSsh': true,
          'sshHost': 'ssh.server.com',
          'sshPort': 2222,
          'sshUsername': 'sshuser',
          'sshPassword': 'sshpass',
          'sshPrivateKey': '/home/user/.ssh/id_rsa',
          'sshKeyPassword': 'keypass',
        };

        final connection = ConnectionModel.fromJson(json);

        expect(connection.useSsh, true);
        expect(connection.sshHost, 'ssh.server.com');
        expect(connection.sshPort, 2222);
        expect(connection.sshUsername, 'sshuser');
        expect(connection.sshPassword, 'sshpass');
        expect(connection.sshPrivateKey, '/home/user/.ssh/id_rsa');
        expect(connection.sshKeyPassword, 'keypass');
      });
    });

    group('serialization roundtrip', () {
      test('toJson -> fromJson preserves all data', () {
        final original = ConnectionModel(
          id: 'test-id',
          name: 'Full Connection',
          host: 'db.example.com',
          port: 5432,
          username: 'admin',
          password: 'secret',
          type: ConnectionType.postgresql,
          sslEnabled: false,
          useSsh: true,
          sshHost: 'ssh.example.com',
          sshPort: 22,
          sshUsername: 'sshuser',
          sshPassword: 'sshpass',
          sshPrivateKey: '/path/key',
          sshKeyPassword: 'keypass',
          databaseName: 'mydb',
          customTag: 'Custom Label',
          tag: ConnectionTag.custom,
          sortOrder: 10,
        );

        final json = original.toJson();
        final restored = ConnectionModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.host, original.host);
        expect(restored.port, original.port);
        expect(restored.username, original.username);
        expect(restored.password, original.password);
        expect(restored.type, original.type);
        expect(restored.sslEnabled, original.sslEnabled);
        expect(restored.useSsh, original.useSsh);
        expect(restored.sshHost, original.sshHost);
        expect(restored.sshPort, original.sshPort);
        expect(restored.sshUsername, original.sshUsername);
        expect(restored.sshPassword, original.sshPassword);
        expect(restored.sshPrivateKey, original.sshPrivateKey);
        expect(restored.sshKeyPassword, original.sshKeyPassword);
        expect(restored.databaseName, original.databaseName);
        expect(restored.customTag, original.customTag);
        expect(restored.tag, original.tag);
        expect(restored.sortOrder, original.sortOrder);
      });
    });
  });
}