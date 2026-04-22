import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/features/queries/models/query_model.dart';

void main() {
  group('QueryModel', () {
    group('constructor', () {
      test('creates query with required fields', () {
        final now = DateTime.now();
        final query = QueryModel(
          id: 'query-123',
          name: 'Get Users',
          query: 'SELECT * FROM users',
          createdAt: now,
          modifiedAt: now,
          connectionId: 'conn-123',
        );

        expect(query.id, 'query-123');
        expect(query.name, 'Get Users');
        expect(query.query, 'SELECT * FROM users');
        expect(query.createdAt, now);
        expect(query.modifiedAt, now);
        expect(query.isFavorite, false);
        expect(query.connectionId, 'conn-123');
        expect(query.databaseName, null);
      });

      test('creates query with all optional fields', () {
        final now = DateTime.now();
        final query = QueryModel(
          id: 'query-456',
          name: 'Update Status',
          query: 'UPDATE users SET status = 1',
          createdAt: now,
          modifiedAt: now,
          isFavorite: true,
          connectionId: 'conn-456',
          databaseName: 'production_db',
        );

        expect(query.isFavorite, true);
        expect(query.databaseName, 'production_db');
      });
    });

    group('copyWith', () {
      test('copies with new name', () {
        final original = QueryModel(
          id: 'q1',
          name: 'Original',
          query: 'SELECT 1',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          connectionId: 'c1',
        );

        final copied = original.copyWith(name: 'Renamed');

        expect(copied.name, 'Renamed');
        expect(copied.id, original.id);
        expect(copied.query, original.query);
        expect(copied.isFavorite, original.isFavorite);
      });

      test('copies with new query', () {
        final original = QueryModel(
          id: 'q1',
          name: 'Query',
          query: 'SELECT * FROM old_table',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          connectionId: 'c1',
        );

        final copied = original.copyWith(query: 'SELECT * FROM new_table');

        expect(copied.query, 'SELECT * FROM new_table');
        expect(copied.name, original.name);
      });

      test('copies with new isFavorite', () {
        final original = QueryModel(
          id: 'q1',
          name: 'Query',
          query: 'SELECT 1',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          isFavorite: false,
          connectionId: 'c1',
        );

        final copied = original.copyWith(isFavorite: true);

        expect(copied.isFavorite, true);
      });

      test('copies with new modifiedAt', () {
        final originalTime = DateTime(2024, 1, 1);
        final newTime = DateTime(2024, 12, 31);
        final original = QueryModel(
          id: 'q1',
          name: 'Query',
          query: 'SELECT 1',
          createdAt: originalTime,
          modifiedAt: originalTime,
          connectionId: 'c1',
        );

        final copied = original.copyWith(modifiedAt: newTime);

        expect(copied.modifiedAt, newTime);
        expect(copied.createdAt, originalTime);
      });

      test('copies with new databaseName', () {
        final original = QueryModel(
          id: 'q1',
          name: 'Query',
          query: 'SELECT 1',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          connectionId: 'c1',
          databaseName: null,
        );

        final copied = original.copyWith(databaseName: 'new_db');

        expect(copied.databaseName, 'new_db');
      });

      test('returns identical values when no parameters provided', () {
        final original = QueryModel(
          id: 'q1',
          name: 'Query',
          query: 'SELECT * FROM users',
          createdAt: DateTime(2024, 1, 1),
          modifiedAt: DateTime(2024, 6, 1),
          isFavorite: true,
          connectionId: 'c1',
          databaseName: 'db1',
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.name, original.name);
        expect(copied.query, original.query);
        expect(copied.createdAt, original.createdAt);
        expect(copied.modifiedAt, original.modifiedAt);
        expect(copied.isFavorite, original.isFavorite);
        expect(copied.connectionId, original.connectionId);
        expect(copied.databaseName, original.databaseName);
      });

      test('copies with multiple changes', () {
        final original = QueryModel(
          id: 'q1',
          name: 'Old Name',
          query: 'SELECT * FROM old',
          createdAt: DateTime(2024, 1, 1),
          modifiedAt: DateTime(2024, 1, 1),
          isFavorite: false,
          connectionId: 'c1',
          databaseName: 'old_db',
        );

        final copied = original.copyWith(
          name: 'New Name',
          query: 'SELECT * FROM new',
          modifiedAt: DateTime(2024, 12, 1),
          isFavorite: true,
          databaseName: 'new_db',
        );

        expect(copied.name, 'New Name');
        expect(copied.query, 'SELECT * FROM new');
        expect(copied.modifiedAt, DateTime(2024, 12, 1));
        expect(copied.isFavorite, true);
        expect(copied.databaseName, 'new_db');
        expect(copied.id, 'q1');
        expect(copied.connectionId, 'c1');
      });
    });
  });

  group('QueryHistoryEntry', () {
    group('constructor', () {
      test('creates successful history entry', () {
        final now = DateTime.now();
        final entry = QueryHistoryEntry(
          id: 'hist-123',
          query: 'SELECT * FROM users LIMIT 10',
          executedAt: now,
          executionTimeMs: 150,
          rowCount: 10,
          success: true,
          connectionId: 'conn-123',
        );

        expect(entry.id, 'hist-123');
        expect(entry.query, 'SELECT * FROM users LIMIT 10');
        expect(entry.executedAt, now);
        expect(entry.executionTimeMs, 150);
        expect(entry.rowCount, 10);
        expect(entry.success, true);
        expect(entry.errorMessage, null);
        expect(entry.connectionId, 'conn-123');
        expect(entry.databaseName, null);
      });

      test('creates failed history entry', () {
        final now = DateTime.now();
        final entry = QueryHistoryEntry(
          id: 'hist-456',
          query: 'SELECT * FROM nonexistent_table',
          executedAt: now,
          executionTimeMs: 50,
          rowCount: 0,
          success: false,
          errorMessage: 'Table does not exist',
          connectionId: 'conn-456',
        );

        expect(entry.success, false);
        expect(entry.errorMessage, 'Table does not exist');
        expect(entry.rowCount, 0);
      });

      test('creates history entry with database name', () {
        final now = DateTime.now();
        final entry = QueryHistoryEntry(
          id: 'hist-789',
          query: 'SELECT * FROM orders',
          executedAt: now,
          executionTimeMs: 200,
          rowCount: 100,
          success: true,
          connectionId: 'conn-789',
          databaseName: 'sales_db',
        );

        expect(entry.databaseName, 'sales_db');
      });
    });

    group('fields', () {
      test('tracks execution metrics correctly', () {
        final fastEntry = QueryHistoryEntry(
          id: 'fast',
          query: 'SELECT 1',
          executedAt: DateTime.now(),
          executionTimeMs: 5,
          rowCount: 1,
          success: true,
          connectionId: 'c1',
        );

        final slowEntry = QueryHistoryEntry(
          id: 'slow',
          query: 'SELECT * FROM large_table',
          executedAt: DateTime.now(),
          executionTimeMs: 5000,
          rowCount: 1000000,
          success: true,
          connectionId: 'c1',
        );

        expect(fastEntry.executionTimeMs < slowEntry.executionTimeMs, true);
        expect(slowEntry.rowCount > fastEntry.rowCount, true);
      });

      test('handles zero row results', () {
        final entry = QueryHistoryEntry(
          id: 'empty',
          query: 'SELECT * FROM users WHERE id = -1',
          executedAt: DateTime.now(),
          executionTimeMs: 10,
          rowCount: 0,
          success: true,
          connectionId: 'c1',
        );

        expect(entry.rowCount, 0);
        expect(entry.success, true);
      });
    });
  });
}