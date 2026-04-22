import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/core/services/column_type_detector.dart';

void main() {
  group('ColumnTypeInfo', () {
    group('constructor', () {
      test('creates column info with required fields', () {
        final info = ColumnTypeInfo(
          columnName: 'id',
          tableName: 'users',
          dataType: 'int',
        );

        expect(info.columnName, 'id');
        expect(info.tableName, 'users');
        expect(info.dataType, 'int');
        expect(info.isBinary, false);
        expect(info.isBit, false);
        expect(info.isEnum, false);
        expect(info.isSet, false);
        expect(info.confidence, TypeConfidence.high);
      });

      test('creates column info with all optional fields', () {
        final info = ColumnTypeInfo(
          columnName: 'status',
          tableName: 'orders',
          dataType: 'enum',
          isEnum: true,
          enumValues: ['pending', 'completed', 'cancelled'],
          confidence: TypeConfidence.high,
          isNullable: false,
          columnDefault: 'pending',
        );

        expect(info.isEnum, true);
        expect(info.enumValues, ['pending', 'completed', 'cancelled']);
        expect(info.isNullable, false);
        expect(info.columnDefault, 'pending');
      });

      test('creates binary column info', () {
        final info = ColumnTypeInfo(
          columnName: 'data',
          tableName: 'files',
          dataType: 'blob',
          isBinary: true,
        );

        expect(info.isBinary, true);
      });

      test('creates bit column info', () {
        final info = ColumnTypeInfo(
          columnName: 'active',
          tableName: 'users',
          dataType: 'bit',
          isBit: true,
        );

        expect(info.isBit, true);
      });

      test('creates set column info', () {
        final info = ColumnTypeInfo(
          columnName: 'permissions',
          tableName: 'roles',
          dataType: 'set',
          isSet: true,
          setValues: ['read', 'write', 'delete'],
        );

        expect(info.isSet, true);
        expect(info.setValues, ['read', 'write', 'delete']);
      });
    });

    group('unknown factory', () {
      test('creates unknown column info', () {
        final info = ColumnTypeInfo.unknown('unknown_col');

        expect(info.columnName, 'unknown_col');
        expect(info.tableName, '');
        expect(info.dataType, 'unknown');
        expect(info.confidence, TypeConfidence.low);
      });
    });

    group('copyWith', () {
      test('copies with new data type', () {
        final original = ColumnTypeInfo(
          columnName: 'id',
          tableName: 'users',
          dataType: 'int',
        );

        final copied = original.copyWith(dataType: 'bigint');

        expect(copied.dataType, 'bigint');
        expect(copied.columnName, original.columnName);
        expect(copied.tableName, original.tableName);
      });

      test('copies with new confidence', () {
        final original = ColumnTypeInfo(
          columnName: 'test',
          tableName: 'table',
          dataType: 'varchar',
          confidence: TypeConfidence.high,
        );

        final copied = original.copyWith(confidence: TypeConfidence.low);

        expect(copied.confidence, TypeConfidence.low);
      });

      test('copies with multiple changes', () {
        final original = ColumnTypeInfo(
          columnName: 'col1',
          tableName: 'table1',
          dataType: 'int',
          isNullable: true,
          confidence: TypeConfidence.high,
        );

        final copied = original.copyWith(
          dataType: 'varchar',
          isNullable: false,
          charMaxLength: 255,
          confidence: TypeConfidence.low,
        );

        expect(copied.dataType, 'varchar');
        expect(copied.isNullable, false);
        expect(copied.charMaxLength, 255);
        expect(copied.confidence, TypeConfidence.low);
        expect(copied.columnName, original.columnName);
      });

      test('returns identical when no parameters provided', () {
        final original = ColumnTypeInfo(
          columnName: 'test',
          tableName: 'test_table',
          dataType: 'text',
          isBinary: false,
          isBit: false,
          isEnum: false,
          isSet: false,
          enumValues: [],
          setValues: [],
          confidence: TypeConfidence.high,
          isNullable: true,
        );

        final copied = original.copyWith();

        expect(copied.columnName, original.columnName);
        expect(copied.tableName, original.tableName);
        expect(copied.dataType, original.dataType);
        expect(copied.isBinary, original.isBinary);
        expect(copied.isNullable, original.isNullable);
      });
    });
  });

  group('ColumnTypeDetector', () {
    group('detectTypes', () {
      test('returns unknown types for null connection', () async {
        final types = await ColumnTypeDetector.detectTypes(
          query: 'SELECT * FROM users',
          resultColumns: ['id', 'name'],
          connection: null,
          databaseName: 'testdb',
        );

        expect(types['id']?.dataType, 'unknown');
        expect(types['name']?.dataType, 'unknown');
        expect(types['id']?.confidence, TypeConfidence.low);
      });

      test('returns unknown types for non-SELECT query', () async {
        final types = await ColumnTypeDetector.detectTypes(
          query: 'INSERT INTO users VALUES (1)',
          resultColumns: ['id'],
          connection: null,
          databaseName: 'testdb',
        );

        expect(types['id']?.dataType, 'unknown');
      });

      test('returns unknown types for null database name', () async {
        final types = await ColumnTypeDetector.detectTypes(
          query: 'SELECT * FROM users',
          resultColumns: ['id'],
          connection: null,
          databaseName: null,
        );

        expect(types['id']?.dataType, 'unknown');
      });

      test('infers types from sample rows', () async {
        final sampleRows = [
          {'id': 1, 'name': 'Test', 'active': [1]},
          {'id': 2, 'name': 'Another', 'active': [0]},
        ];

        final types = await ColumnTypeDetector.detectTypes(
          query: 'SELECT id, name, active FROM users',
          resultColumns: ['id', 'name', 'active'],
          connection: null,
          databaseName: null,
          sampleRows: sampleRows,
        );

        expect(types.length, 3);
        expect(types['active']?.isBit, true);
      });

      test('infers binary type from sample rows', () async {
        final sampleRows = [
          {'data': [0x01, 0x02, 0x03, 0x04, 0xFF]},
        ];

        final types = await ColumnTypeDetector.detectTypes(
          query: 'SELECT data FROM files',
          resultColumns: ['data'],
          connection: null,
          databaseName: null,
          sampleRows: sampleRows,
        );

        expect(types['data']?.isBinary, true);
        expect(types['data']?.dataType, 'binary');
      });
    });

    group('formatValue', () {
      test('returns null for null value', () {
        final result = ColumnTypeDetector.formatValue(null, null);

        expect(result, null);
      });

      test('formats unknown value without info', () {
        final result = ColumnTypeDetector.formatValue('test', null);

        expect(result, 'test');
      });

      test('formats bit value', () {
        final info = ColumnTypeInfo(
          columnName: 'active',
          tableName: 'users',
          dataType: 'bit',
          isBit: true,
        );

        final result = ColumnTypeDetector.formatValue([1], info);

        expect(result, '1');
      });

      test('formats bit value as integer', () {
        final info = ColumnTypeInfo(
          columnName: 'flag',
          tableName: 'table',
          dataType: 'bit',
          isBit: true,
        );

        final result = ColumnTypeDetector.formatValue([0], info);

        expect(result, '0');
      });

      test('formats binary value as hex', () {
        final info = ColumnTypeInfo(
          columnName: 'data',
          tableName: 'files',
          dataType: 'blob',
          isBinary: true,
        );

        final result = ColumnTypeDetector.formatValue([0xDE, 0xAD, 0xBE, 0xEF], info);

        expect(result, contains('0x'));
        expect(result, contains('deadbeef'));
      });

      test('formats long binary value with truncation', () {
        final info = ColumnTypeInfo(
          columnName: 'large_data',
          tableName: 'files',
          dataType: 'blob',
          isBinary: true,
        );

        final largeData = List.generate(100, (i) => i);
        final result = ColumnTypeDetector.formatValue(largeData, info);

        expect(result, contains('...'));
        expect(result, contains('bytes'));
      });

      test('formats enum value', () {
        final info = ColumnTypeInfo(
          columnName: 'status',
          tableName: 'orders',
          dataType: 'enum',
          isEnum: true,
          enumValues: ['pending', 'completed'],
        );

        final result = ColumnTypeDetector.formatValue('pending', info);

        expect(result, 'pending');
      });

      test('formats set value', () {
        final info = ColumnTypeInfo(
          columnName: 'permissions',
          tableName: 'roles',
          dataType: 'set',
          isSet: true,
          setValues: ['read', 'write'],
        );

        final result = ColumnTypeDetector.formatValue('read,write', info);

        expect(result, 'read,write');
      });

      test('formats regular string value', () {
        final info = ColumnTypeInfo(
          columnName: 'name',
          tableName: 'users',
          dataType: 'varchar',
        );

        final result = ColumnTypeDetector.formatValue('John Doe', info);

        expect(result, 'John Doe');
      });

      test('formats integer value', () {
        final info = ColumnTypeInfo(
          columnName: 'count',
          tableName: 'stats',
          dataType: 'int',
        );

        final result = ColumnTypeDetector.formatValue(42, info);

        expect(result, '42');
      });
    });
  });
}