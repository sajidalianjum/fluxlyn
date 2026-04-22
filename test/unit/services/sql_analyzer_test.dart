import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/core/services/sql_analyzer.dart';

void main() {
  group('SqlAnalyzer', () {
    group('getQueryType', () {
      group('SELECT queries', () {
        test('identifies basic SELECT', () {
          expect(
            SqlAnalyzer.getQueryType('SELECT * FROM users'),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with lowercase', () {
          expect(
            SqlAnalyzer.getQueryType('select * from users'),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with mixed case', () {
          expect(
            SqlAnalyzer.getQueryType('Select * From Users'),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with columns', () {
          expect(
            SqlAnalyzer.getQueryType('SELECT id, name, email FROM users'),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with WHERE clause', () {
          expect(
            SqlAnalyzer.getQueryType('SELECT * FROM users WHERE id = 1'),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with JOIN', () {
          expect(
            SqlAnalyzer.getQueryType(
              'SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id',
            ),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with subquery', () {
          expect(
            SqlAnalyzer.getQueryType(
              'SELECT * FROM (SELECT id FROM users) AS sub',
            ),
            SqlQueryType.select,
          );
        });

        test('identifies SELECT with leading whitespace', () {
          expect(
            SqlAnalyzer.getQueryType('   SELECT * FROM users'),
            SqlQueryType.select,
          );
        });

        test('identifies CTE (WITH clause) as SELECT', () {
          expect(
            SqlAnalyzer.getQueryType(
              'WITH active_users AS (SELECT * FROM users WHERE active = 1) '
              'SELECT * FROM active_users',
            ),
            SqlQueryType.select,
          );
        });

        test('identifies complex SELECT with multiple clauses', () {
          expect(
            SqlAnalyzer.getQueryType(
              'SELECT id, COUNT(*) as count FROM users '
              'WHERE status = 1 '
              'GROUP BY id '
              'HAVING count > 5 '
              'ORDER BY count DESC '
              'LIMIT 10',
            ),
            SqlQueryType.select,
          );
        });
      });

      group('DML queries', () {
        test('identifies INSERT', () {
          expect(
            SqlAnalyzer.getQueryType(
              'INSERT INTO users (name, email) VALUES ("John", "john@example.com")',
            ),
            SqlQueryType.dml,
          );
        });

        test('identifies UPDATE', () {
          expect(
            SqlAnalyzer.getQueryType('UPDATE users SET name = "Jane" WHERE id = 1'),
            SqlQueryType.dml,
          );
        });

        test('identifies DELETE', () {
          expect(
            SqlAnalyzer.getQueryType('DELETE FROM users WHERE id = 1'),
            SqlQueryType.dml,
          );
        });

        test('identifies REPLACE', () {
          expect(
            SqlAnalyzer.getQueryType(
              'REPLACE INTO users (id, name) VALUES (1, "John")',
            ),
            SqlQueryType.dml,
          );
        });

        test('identifies TRUNCATE', () {
          expect(
            SqlAnalyzer.getQueryType('TRUNCATE TABLE users'),
            SqlQueryType.dml,
          );
        });

        test('identifies lowercase DML', () {
          expect(
            SqlAnalyzer.getQueryType('insert into users values (1)'),
            SqlQueryType.dml,
          );
          expect(
            SqlAnalyzer.getQueryType('update users set name = "test"'),
            SqlQueryType.dml,
          );
          expect(
            SqlAnalyzer.getQueryType('delete from users'),
            SqlQueryType.dml,
          );
        });
      });

      group('DDL queries', () {
        test('identifies CREATE TABLE', () {
          expect(
            SqlAnalyzer.getQueryType(
              'CREATE TABLE users (id INT, name VARCHAR(100))',
            ),
            SqlQueryType.ddl,
          );
        });

        test('identifies CREATE INDEX', () {
          expect(
            SqlAnalyzer.getQueryType('CREATE INDEX idx_name ON users (name)'),
            SqlQueryType.ddl,
          );
        });

        test('identifies ALTER TABLE', () {
          expect(
            SqlAnalyzer.getQueryType('ALTER TABLE users ADD COLUMN email VARCHAR(100)'),
            SqlQueryType.ddl,
          );
        });

        test('identifies DROP TABLE', () {
          expect(
            SqlAnalyzer.getQueryType('DROP TABLE users'),
            SqlQueryType.ddl,
          );
        });

        test('identifies DROP INDEX', () {
          expect(
            SqlAnalyzer.getQueryType('DROP INDEX idx_name'),
            SqlQueryType.ddl,
          );
        });

        test('identifies lowercase DDL', () {
          expect(
            SqlAnalyzer.getQueryType('create table test (id int)'),
            SqlQueryType.ddl,
          );
          expect(
            SqlAnalyzer.getQueryType('alter table test add column x int'),
            SqlQueryType.ddl,
          );
          expect(
            SqlAnalyzer.getQueryType('drop table test'),
            SqlQueryType.ddl,
          );
        });
      });

      group('unknown queries', () {
        test('returns unknown for empty string', () {
          expect(SqlAnalyzer.getQueryType(''), SqlQueryType.unknown);
        });

        test('returns unknown for whitespace only', () {
          expect(SqlAnalyzer.getQueryType('   '), SqlQueryType.unknown);
        });

        test('returns unknown for SHOW commands', () {
          expect(
            SqlAnalyzer.getQueryType('SHOW TABLES'),
            SqlQueryType.unknown,
          );
        });

        test('returns unknown for DESCRIBE commands', () {
          expect(
            SqlAnalyzer.getQueryType('DESCRIBE users'),
            SqlQueryType.unknown,
          );
        });

        test('returns unknown for EXPLAIN commands', () {
          expect(
            SqlAnalyzer.getQueryType('EXPLAIN SELECT * FROM users'),
            SqlQueryType.unknown,
          );
        });

        test('returns unknown for SET commands', () {
          expect(
            SqlAnalyzer.getQueryType('SET autocommit = 0'),
            SqlQueryType.unknown,
          );
        });

        test('returns unknown for USE commands', () {
          expect(
            SqlAnalyzer.getQueryType('USE my_database'),
            SqlQueryType.unknown,
          );
        });
      });
    });

    group('extractTableNames', () {
      group('basic queries', () {
        test('extracts single table from simple SELECT', () {
          final tables = SqlAnalyzer.extractTableNames('SELECT * FROM users');

          expect(tables, contains('users'));
          expect(tables.length, 1);
        });

        test('extracts table with alias', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users AS u',
          );

          expect(tables, contains('users'));
        });

        test('handles lowercase query', () {
          final tables = SqlAnalyzer.extractTableNames(
            'select * from users',
          );

          expect(tables, contains('users'));
        });
      });

      group('JOIN queries', () {
        test('extracts tables from INNER JOIN', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users INNER JOIN orders ON users.id = orders.user_id',
          );

          expect(tables, containsAll(['users', 'orders']));
        });

        test('extracts tables from LEFT JOIN', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users LEFT JOIN orders ON users.id = orders.user_id',
          );

          expect(tables, containsAll(['users', 'orders']));
        });

        test('extracts tables from multiple JOINs', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users '
            'JOIN orders ON users.id = orders.user_id '
            'JOIN products ON orders.product_id = products.id',
          );

          expect(tables, containsAll(['users', 'orders', 'products']));
        });

        test('handles JOIN without INNER/LEFT keyword', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users JOIN orders ON users.id = orders.user_id',
          );

          expect(tables, containsAll(['users', 'orders']));
        });
      });

      group('queries with clauses', () {
        test('extracts table from SELECT with WHERE', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users WHERE id = 1',
          );

          expect(tables, contains('users'));
        });

        test('extracts table from SELECT with GROUP BY', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT COUNT(*) FROM users GROUP BY status',
          );

          expect(tables, contains('users'));
        });

        test('extracts table from SELECT with ORDER BY', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users ORDER BY created_at DESC',
          );

          expect(tables, contains('users'));
        });

        test('extracts table from SELECT with LIMIT', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users LIMIT 10',
          );

          expect(tables, contains('users'));
        });

        test('extracts table from complex query with all clauses', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT u.id, COUNT(o.id) FROM users u '
            'WHERE u.active = 1 '
            'GROUP BY u.id '
            'HAVING COUNT(o.id) > 0 '
            'ORDER BY u.name '
            'LIMIT 5',
          );

          expect(tables, contains('users'));
        });
      });

      group('special cases', () {
        test('returns empty list for non-SELECT queries', () {
          expect(
            SqlAnalyzer.extractTableNames('INSERT INTO users VALUES (1)'),
            isEmpty,
          );
          expect(
            SqlAnalyzer.extractTableNames('UPDATE users SET name = "test"'),
            isEmpty,
          );
          expect(
            SqlAnalyzer.extractTableNames('DELETE FROM users'),
            isEmpty,
          );
        });

        test('returns empty list for SELECT without FROM', () {
          expect(SqlAnalyzer.extractTableNames('SELECT 1'), isEmpty);
          expect(SqlAnalyzer.extractTableNames('SELECT NOW()'), isEmpty);
        });

        test('handles table names with underscores', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM user_accounts',
          );

          expect(tables, contains('user_accounts'));
        });

        test('handles table names with numbers', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM users2',
          );

          expect(tables, contains('users2'));
        });

        test('handles schema-qualified table names', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * FROM public.users',
          );

          expect(tables, contains('public'));
          expect(tables, contains('users'));
        });
      });

      group('comments and formatting', () {
        test('handles SQL with comments', () {
          final tables = SqlAnalyzer.extractTableNames(
            '/* comment */ SELECT * FROM users /* another comment */',
          );

          expect(tables, contains('users'));
        });

        test('handles SQL with line comments', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT * -- comment\nFROM users',
          );

          expect(tables, contains('users'));
        });

        test('handles extra whitespace', () {
          final tables = SqlAnalyzer.extractTableNames(
            'SELECT   *   FROM   users',
          );

          expect(tables, contains('users'));
        });
      });
    });

    group('extractColumnNames', () {
      group('basic SELECT', () {
        test('extracts single column', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT id FROM users',
          );

          expect(columns, contains('id'));
        });

        test('extracts multiple columns', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT id, name, email FROM users',
          );

          expect(columns, containsAll(['id', 'name', 'email']));
        });

        test('handles SELECT * (returns empty)', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT * FROM users',
          );

          expect(columns, isEmpty);
        });

        test('handles lowercase SELECT', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'select id, name from users',
          );

          expect(columns, containsAll(['id', 'name']));
        });
      });

      group('column aliases', () {
        test('extracts aliased column with AS', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT id AS user_id FROM users',
          );

          expect(columns, contains('user_id'));
        });

        test('extracts aliased column without AS', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT id user_id FROM users',
          );

          expect(columns, contains('user_id'));
        });

        test('handles multiple aliased columns', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT id AS user_id, name AS user_name FROM users',
          );

          expect(columns, containsAll(['user_id', 'user_name']));
        });
      });

      group('table-qualified columns', () {
        test('extracts column from qualified reference', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT users.id FROM users',
          );

          expect(columns, contains('id'));
        });

        test('extracts column from aliased table', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT u.id, u.name FROM users u',
          );

          expect(columns, containsAll(['id', 'name']));
        });
      });

      group('function calls', () {
        test('handles COUNT function', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT COUNT(*) FROM users',
          );

          expect(columns, isEmpty);
        });

        test('handles aggregate with alias', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT COUNT(*) AS total FROM users',
          );

          expect(columns, contains('total'));
        });

        test('handles function on column', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT UPPER(name) AS upper_name FROM users',
          );

          expect(columns, contains('upper_name'));
        });
      });

      group('non-SELECT queries', () {
        test('returns empty for INSERT', () {
          expect(
            SqlAnalyzer.extractColumnNames('INSERT INTO users (name) VALUES ("test")'),
            isEmpty,
          );
        });

        test('returns empty for UPDATE', () {
          expect(
            SqlAnalyzer.extractColumnNames('UPDATE users SET name = "test"'),
            isEmpty,
          );
        });

        test('returns empty for DELETE', () {
          expect(
            SqlAnalyzer.extractColumnNames('DELETE FROM users'),
            isEmpty,
          );
        });
      });

      group('complex expressions', () {
        test('handles expression with alias', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT id + 1 AS next_id FROM users',
          );

          expect(columns, contains('next_id'));
        });

        test('handles concatenation with alias', () {
          final columns = SqlAnalyzer.extractColumnNames(
            'SELECT CONCAT(first_name, last_name) AS full_name FROM users',
          );

          expect(columns, contains('full_name'));
        });
      });
    });

    group('isSelectQuery', () {
      test('returns true for SELECT', () {
        expect(SqlAnalyzer.isSelectQuery('SELECT * FROM users'), true);
      });

      test('returns true for lowercase SELECT', () {
        expect(SqlAnalyzer.isSelectQuery('select * from users'), true);
      });

      test('returns true for SELECT with whitespace', () {
        expect(SqlAnalyzer.isSelectQuery('  SELECT 1'), true);
      });

      test('returns false for INSERT', () {
        expect(SqlAnalyzer.isSelectQuery('INSERT INTO users VALUES (1)'), false);
      });

      test('returns false for UPDATE', () {
        expect(SqlAnalyzer.isSelectQuery('UPDATE users SET x = 1'), false);
      });

      test('returns false for empty string', () {
        expect(SqlAnalyzer.isSelectQuery(''), false);
      });
    });
  });
}