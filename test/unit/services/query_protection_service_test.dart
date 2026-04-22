import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/core/services/query_protection_service.dart';

void main() {
  group('QueryProtectionService', () {
    group('isWriteOperation', () {
      group('write operations', () {
        test('identifies INSERT as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation(
              'INSERT INTO users (name) VALUES ("John")',
            ),
            true,
          );
        });

        test('identifies UPDATE as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation(
              'UPDATE users SET name = "Jane"',
            ),
            true,
          );
        });

        test('identifies DELETE as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation(
              'DELETE FROM users WHERE id = 1',
            ),
            true,
          );
        });

        test('identifies CREATE as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation(
              'CREATE TABLE test (id INT)',
            ),
            true,
          );
        });

        test('identifies ALTER as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation(
              'ALTER TABLE users ADD COLUMN email VARCHAR(100)',
            ),
            true,
          );
        });

        test('identifies DROP as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('DROP TABLE users'),
            true,
          );
        });

        test('identifies TRUNCATE as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('TRUNCATE TABLE users'),
            true,
          );
        });

        test('identifies RENAME as write operation', () {
          expect(
            QueryProtectionService.isWriteOperation(
              'RENAME TABLE old_name TO new_name',
            ),
            true,
          );
        });

        test('handles lowercase queries', () {
          expect(
            QueryProtectionService.isWriteOperation('insert into users values (1)'),
            true,
          );
          expect(
            QueryProtectionService.isWriteOperation('update users set x = 1'),
            true,
          );
          expect(
            QueryProtectionService.isWriteOperation('delete from users'),
            true,
          );
        });

        test('handles mixed case queries', () {
          expect(
            QueryProtectionService.isWriteOperation('Insert Into users Values (1)'),
            true,
          );
        });

        test('handles queries with leading whitespace', () {
          expect(
            QueryProtectionService.isWriteOperation('   INSERT INTO users VALUES (1)'),
            true,
          );
          expect(
            QueryProtectionService.isWriteOperation('\nUPDATE users SET x = 1'),
            true,
          );
          expect(
            QueryProtectionService.isWriteOperation('\tDELETE FROM users'),
            true,
          );
        });
      });

      group('read operations', () {
        test('SELECT is not a write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('SELECT * FROM users'),
            false,
          );
        });

        test('SHOW is not a write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('SHOW TABLES'),
            false,
          );
        });

        test('DESCRIBE is not a write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('DESCRIBE users'),
            false,
          );
        });

        test('EXPLAIN is not a write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('EXPLAIN SELECT * FROM users'),
            false,
          );
        });

        test('USE is not a write operation', () {
          expect(
            QueryProtectionService.isWriteOperation('USE my_database'),
            false,
          );
        });

        test('empty string is not a write operation', () {
          expect(QueryProtectionService.isWriteOperation(''), false);
        });

        test('whitespace only is not a write operation', () {
          expect(QueryProtectionService.isWriteOperation('   '), false);
        });
      });
    });

    group('isDestructiveOperation', () {
      group('destructive operations', () {
        test('identifies DELETE as destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation(
              'DELETE FROM users WHERE id = 1',
            ),
            true,
          );
        });

        test('identifies DROP as destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation('DROP TABLE users'),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation('DROP DATABASE mydb'),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation('DROP INDEX idx_name'),
            true,
          );
        });

        test('identifies TRUNCATE as destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation('TRUNCATE TABLE users'),
            true,
          );
        });

        test('identifies ALTER as destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation(
              'ALTER TABLE users DROP COLUMN email',
            ),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation(
              'ALTER TABLE users ADD COLUMN email VARCHAR(100)',
            ),
            true,
          );
        });

        test('handles lowercase destructive queries', () {
          expect(
            QueryProtectionService.isDestructiveOperation('delete from users'),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation('drop table users'),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation('truncate table users'),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation('alter table users add column x int'),
            true,
          );
        });

        test('handles queries with leading whitespace', () {
          expect(
            QueryProtectionService.isDestructiveOperation('  DELETE FROM users'),
            true,
          );
          expect(
            QueryProtectionService.isDestructiveOperation('\nDROP TABLE users'),
            true,
          );
        });
      });

      group('non-destructive operations', () {
        test('INSERT is not destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation(
              'INSERT INTO users (name) VALUES ("John")',
            ),
            false,
          );
        });

        test('UPDATE is not destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation(
              'UPDATE users SET name = "Jane"',
            ),
            false,
          );
        });

        test('CREATE is not destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation(
              'CREATE TABLE users (id INT)',
            ),
            false,
          );
        });

        test('SELECT is not destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation('SELECT * FROM users'),
            false,
          );
        });

        test('RENAME is not destructive', () {
          expect(
            QueryProtectionService.isDestructiveOperation(
              'RENAME TABLE old TO new',
            ),
            false,
          );
        });

        test('empty string is not destructive', () {
          expect(QueryProtectionService.isDestructiveOperation(''), false);
        });
      });
    });

    group('checkQuery', () {
      group('read-only mode', () {
        test('blocks write operations when readOnlyMode is true', () {
          final result = QueryProtectionService.checkQuery(
            'INSERT INTO users VALUES (1)',
            true,
            false,
          );

          expect(result, 'Read-only mode is enabled. Write operations are not allowed.');
        });

        test('blocks UPDATE in read-only mode', () {
          final result = QueryProtectionService.checkQuery(
            'UPDATE users SET name = "test"',
            true,
            false,
          );

          expect(result, 'Read-only mode is enabled. Write operations are not allowed.');
        });

        test('allows SELECT in read-only mode', () {
          final result = QueryProtectionService.checkQuery(
            'SELECT * FROM users',
            true,
            false,
          );

          expect(result, null);
        });

        test('allows write operations when readOnlyMode is false', () {
          final result = QueryProtectionService.checkQuery(
            'INSERT INTO users VALUES (1)',
            false,
            false,
          );

          expect(result, null);
        });
      });

      group('lock protection', () {
        test('blocks destructive operations when lock is true', () {
          final result = QueryProtectionService.checkQuery(
            'DELETE FROM users',
            false,
            true,
          );

          expect(result, 'Destructive operations are locked.');
        });

        test('blocks DROP when lock is true', () {
          final result = QueryProtectionService.checkQuery(
            'DROP TABLE users',
            false,
            true,
          );

          expect(result, 'Destructive operations are locked.');
        });

        test('blocks TRUNCATE when lock is true', () {
          final result = QueryProtectionService.checkQuery(
            'TRUNCATE TABLE users',
            false,
            true,
          );

          expect(result, 'Destructive operations are locked.');
        });

        test('blocks ALTER when lock is true', () {
          final result = QueryProtectionService.checkQuery(
            'ALTER TABLE users ADD COLUMN x INT',
            false,
            true,
          );

          expect(result, 'Destructive operations are locked.');
        });

        test('allows destructive operations when lock is false', () {
          final result = QueryProtectionService.checkQuery(
            'DELETE FROM users',
            false,
            false,
          );

          expect(result, null);
        });

        test('allows non-destructive write operations even with lock', () {
          final result = QueryProtectionService.checkQuery(
            'INSERT INTO users VALUES (1)',
            false,
            true,
          );

          expect(result, null);
        });

        test('allows UPDATE even with lock (not destructive)', () {
          final result = QueryProtectionService.checkQuery(
            'UPDATE users SET name = "test"',
            false,
            true,
          );

          expect(result, null);
        });
      });

      group('combined protections', () {
        test('read-only mode checked before lock', () {
          final result = QueryProtectionService.checkQuery(
            'DELETE FROM users',
            true,
            true,
          );

          expect(result, 'Read-only mode is enabled. Write operations are not allowed.');
        });

        test('lock blocks destructive when not in read-only', () {
          final result = QueryProtectionService.checkQuery(
            'DROP TABLE users',
            false,
            true,
          );

          expect(result, 'Destructive operations are locked.');
        });

        test('allows SELECT with both protections', () {
          final result = QueryProtectionService.checkQuery(
            'SELECT * FROM users',
            true,
            true,
          );

          expect(result, null);
        });

        test('allows all operations when both protections disabled', () {
          final result = QueryProtectionService.checkQuery(
            'DELETE FROM users',
            false,
            false,
          );

          expect(result, null);
        });
      });

      group('edge cases', () {
        test('handles empty query', () {
          final result = QueryProtectionService.checkQuery('', true, true);

          expect(result, null);
        });

        test('handles whitespace query', () {
          final result = QueryProtectionService.checkQuery('   ', true, true);

          expect(result, null);
        });

        test('handles query with leading whitespace', () {
          final result = QueryProtectionService.checkQuery(
            '  DELETE FROM users',
            true,
            true,
          );

          expect(result, 'Read-only mode is enabled. Write operations are not allowed.');
        });

        test('handles mixed case query', () {
          final result = QueryProtectionService.checkQuery(
            'Delete From Users',
            true,
            false,
          );

          expect(result, 'Read-only mode is enabled. Write operations are not allowed.');
        });
      });
    });

    group('checkEditOperation', () {
      test('blocks edit in read-only mode', () {
        final result = QueryProtectionService.checkEditOperation(true, false);

        expect(result, 'Read-only mode is active.');
      });

      test('allows edit when not in read-only mode', () {
        final result = QueryProtectionService.checkEditOperation(false, true);

        expect(result, null);
      });

      test('lock parameter does not affect edit operation', () {
        final result1 = QueryProtectionService.checkEditOperation(false, true);
        final result2 = QueryProtectionService.checkEditOperation(false, false);

        expect(result1, null);
        expect(result2, null);
      });

      test('read-only always checked for edit', () {
        final result = QueryProtectionService.checkEditOperation(true, true);

        expect(result, 'Read-only mode is active.');
      });
    });
  });
}