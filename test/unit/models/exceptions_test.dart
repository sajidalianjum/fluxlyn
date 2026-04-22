import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/core/models/exceptions.dart';

void main() {
  group('Exceptions', () {
    group('DatabaseException', () {
      test('creates exception with message', () {
        final exception = DatabaseException('Connection failed');

        expect(exception.message, 'Connection failed');
        expect(exception.operation, null);
        expect(exception.connectionName, null);
        expect(exception.originalError, null);
      });

      test('creates exception with all parameters', () {
        final original = Exception('Original error');
        final exception = DatabaseException(
          'Query failed',
          operation: 'execute',
          connectionName: 'MyDB',
          originalError: original,
        );

        expect(exception.message, 'Query failed');
        expect(exception.operation, 'execute');
        expect(exception.connectionName, 'MyDB');
        expect(exception.originalError, original);
      });

      test('toString includes all parameters', () {
        final exception = DatabaseException(
          'Test error',
          operation: 'connect',
          connectionName: 'Production',
          originalError: 'timeout',
        );

        final str = exception.toString();

        expect(str, contains('DatabaseException'));
        expect(str, contains('Test error'));
        expect(str, contains('Operation: connect'));
        expect(str, contains('Connection: Production'));
        expect(str, contains('Original: timeout'));
      });

      test('toString omits null parameters', () {
        final exception = DatabaseException('Simple error');

        final str = exception.toString();

        expect(str, 'DatabaseException: Simple error');
      });
    });

    group('NetworkException', () {
      test('creates exception with message', () {
        final exception = NetworkException('Network timeout');

        expect(exception.message, 'Network timeout');
        expect(exception.url, null);
        expect(exception.statusCode, null);
      });

      test('creates exception with all parameters', () {
        final exception = NetworkException(
          'API error',
          url: 'https://api.example.com',
          statusCode: 500,
          originalError: 'Server down',
        );

        expect(exception.message, 'API error');
        expect(exception.url, 'https://api.example.com');
        expect(exception.statusCode, 500);
      });

      test('toString includes URL and status code', () {
        final exception = NetworkException(
          'Request failed',
          url: 'https://example.com',
          statusCode: 404,
        );

        final str = exception.toString();

        expect(str, contains('URL: https://example.com'));
        expect(str, contains('Status: 404'));
      });
    });

    group('SSHException', () {
      test('creates exception with message', () {
        final exception = SSHException('SSH connection failed');

        expect(exception.message, 'SSH connection failed');
        expect(exception.host, null);
        expect(exception.port, null);
      });

      test('creates exception with host and port', () {
        final exception = SSHException(
          'Authentication failed',
          host: 'ssh.example.com',
          port: 22,
        );

        expect(exception.host, 'ssh.example.com');
        expect(exception.port, 22);
      });

      test('toString includes host:port', () {
        final exception = SSHException(
          'Timeout',
          host: 'server.com',
          port: 2222,
        );

        final str = exception.toString();

        expect(str, contains('Host: server.com:2222'));
      });
    });

    group('StorageException', () {
      test('creates exception with message', () {
        final exception = StorageException('Failed to save');

        expect(exception.message, 'Failed to save');
        expect(exception.operation, null);
        expect(exception.filePath, null);
      });

      test('creates exception with operation and file path', () {
        final exception = StorageException(
          'Write failed',
          operation: 'save',
          filePath: '/path/to/file',
        );

        expect(exception.operation, 'save');
        expect(exception.filePath, '/path/to/file');
      });

      test('toString includes operation and file', () {
        final exception = StorageException(
          'Error',
          operation: 'export',
          filePath: '/data/export.fluxlyn',
        );

        final str = exception.toString();

        expect(str, contains('Operation: export'));
        expect(str, contains('File: /data/export.fluxlyn'));
      });
    });

    group('TimeoutException', () {
      test('creates exception with message', () {
        final exception = TimeoutException('Operation timed out');

        expect(exception.message, 'Operation timed out');
        expect(exception.timeout, null);
        expect(exception.operation, null);
      });

      test('creates exception with timeout duration', () {
        final exception = TimeoutException(
          'Connection timeout',
          timeout: const Duration(seconds: 30),
          operation: 'connect',
        );

        expect(exception.timeout, const Duration(seconds: 30));
        expect(exception.operation, 'connect');
      });

      test('toString includes timeout in seconds', () {
        final exception = TimeoutException(
          'Timeout',
          timeout: const Duration(seconds: 30),
        );

        final str = exception.toString();

        expect(str, contains('Timeout: 30s'));
      });
    });

    group('ConnectionException', () {
      test('creates exception with message', () {
        final exception = ConnectionException('Cannot connect');

        expect(exception.message, 'Cannot connect');
        expect(exception.isReconnect, false);
      });

      test('creates reconnect exception', () {
        final exception = ConnectionException(
          'Reconnection failed',
          isReconnect: true,
        );

        expect(exception.isReconnect, true);
      });

      test('creates exception with connection details', () {
        final exception = ConnectionException(
          'Failed',
          connectionName: 'Production',
          host: 'db.example.com',
          port: 3306,
        );

        expect(exception.connectionName, 'Production');
        expect(exception.host, 'db.example.com');
        expect(exception.port, 3306);
      });

      test('toString changes type for reconnect', () {
        final normal = ConnectionException('Normal');
        final reconnect = ConnectionException('Reconnect', isReconnect: true);

        expect(normal.toString(), contains('ConnectionException'));
        expect(reconnect.toString(), contains('ReconnectException'));
      });

      test('toUserFriendlyString returns message', () {
        final exception = ConnectionException('User friendly message');

        expect(exception.toUserFriendlyString(), 'User friendly message');
      });
    });

    group('QueryException', () {
      test('creates exception with message', () {
        final exception = QueryException('Syntax error');

        expect(exception.message, 'Syntax error');
        expect(exception.query, null);
        expect(exception.database, null);
        expect(exception.table, null);
      });

      test('creates exception with query details', () {
        final exception = QueryException(
          'Table not found',
          query: 'SELECT * FROM users',
          database: 'mydb',
          table: 'users',
        );

        expect(exception.query, 'SELECT * FROM users');
        expect(exception.database, 'mydb');
        expect(exception.table, 'users');
      });

      test('toString truncates long query', () {
        final longQuery = 'SELECT * FROM users WHERE ' +
            'id = 1 AND name = "test"' * 20;
        final exception = QueryException(
          'Error',
          query: longQuery,
        );

        final str = exception.toString();

        expect(str.contains('Query:'), longQuery.length <= 200);
      });

      test('toString includes short query', () {
        final exception = QueryException(
          'Error',
          query: 'SELECT 1',
        );

        final str = exception.toString();

        expect(str, contains('Query: SELECT 1'));
      });
    });

    group('ValidationException', () {
      test('creates exception with message', () {
        final exception = ValidationException('Invalid input');

        expect(exception.message, 'Invalid input');
        expect(exception.field, null);
        expect(exception.value, null);
      });

      test('creates exception with field and value', () {
        final exception = ValidationException(
          'Invalid port',
          field: 'port',
          value: -1,
        );

        expect(exception.field, 'port');
        expect(exception.value, -1);
      });

      test('toString includes field and value', () {
        final exception = ValidationException(
          'Required field empty',
          field: 'name',
          value: '',
        );

        final str = exception.toString();

        expect(str, contains('Field: name'));
        expect(str, contains('Value:'));
      });
    });
  });
}