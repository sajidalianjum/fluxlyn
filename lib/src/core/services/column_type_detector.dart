import 'dart:convert';
import 'package:mysql_dart/mysql_dart.dart';
import 'sql_analyzer.dart';

enum TypeConfidence { high, low }

class ColumnTypeInfo {
  final String columnName;
  final String tableName;
  final String dataType;
  final bool isBinary;
  final bool isBit;
  final bool isEnum;
  final bool isSet;
  final List<String> enumValues;
  final List<String> setValues;
  final TypeConfidence confidence;
  final bool isNullable;
  final String? columnDefault;
  final int? numericPrecision;
  final int? numericScale;
  final int? charMaxLength;

  ColumnTypeInfo({
    required this.columnName,
    required this.tableName,
    required this.dataType,
    this.isBinary = false,
    this.isBit = false,
    this.isEnum = false,
    this.isSet = false,
    this.enumValues = const [],
    this.setValues = const [],
    this.confidence = TypeConfidence.high,
    this.isNullable = true,
    this.columnDefault,
    this.numericPrecision,
    this.numericScale,
    this.charMaxLength,
  });

  factory ColumnTypeInfo.unknown(String columnName) {
    return ColumnTypeInfo(
      columnName: columnName,
      tableName: '',
      dataType: 'unknown',
      confidence: TypeConfidence.low,
    );
  }

  ColumnTypeInfo copyWith({
    String? columnName,
    String? tableName,
    String? dataType,
    bool? isBinary,
    bool? isBit,
    bool? isEnum,
    bool? isSet,
    List<String>? enumValues,
    List<String>? setValues,
    TypeConfidence? confidence,
    bool? isNullable,
    String? columnDefault,
    int? numericPrecision,
    int? numericScale,
    int? charMaxLength,
  }) {
    return ColumnTypeInfo(
      columnName: columnName ?? this.columnName,
      tableName: tableName ?? this.tableName,
      dataType: dataType ?? this.dataType,
      isBinary: isBinary ?? this.isBinary,
      isBit: isBit ?? this.isBit,
      isEnum: isEnum ?? this.isEnum,
      isSet: isSet ?? this.isSet,
      enumValues: enumValues ?? this.enumValues,
      setValues: setValues ?? this.setValues,
      confidence: confidence ?? this.confidence,
      isNullable: isNullable ?? this.isNullable,
      columnDefault: columnDefault ?? this.columnDefault,
      numericPrecision: numericPrecision ?? this.numericPrecision,
      numericScale: numericScale ?? this.numericScale,
      charMaxLength: charMaxLength ?? this.charMaxLength,
    );
  }
}

class ColumnTypeDetector {
  /// Detect column types for the result of a query
  /// Returns a map from column name to ColumnTypeInfo
  /// Uses INFORMATION_SCHEMA when available, silently falls back to inference
  static Future<Map<String, ColumnTypeInfo>> detectTypes({
    required String query,
    required List<String> resultColumns,
    required MySQLConnection connection,
    String? databaseName,
    List<Map<String, dynamic>>? sampleRows,
  }) async {
    final columnTypes = <String, ColumnTypeInfo>{};

    if (!SqlAnalyzer.isSelectQuery(query) || databaseName == null) {
      // Infer types from sample rows if available
      if (sampleRows != null && sampleRows.isNotEmpty) {
        return _inferTypesFromResults(resultColumns, sampleRows);
      }
      for (final col in resultColumns) {
        columnTypes[col] = ColumnTypeInfo.unknown(col);
      }
      return columnTypes;
    }

    final tableNames = SqlAnalyzer.extractTableNames(query);

    if (tableNames.isEmpty) {
      // Infer types from sample rows if available
      if (sampleRows != null && sampleRows.isNotEmpty) {
        return _inferTypesFromResults(resultColumns, sampleRows);
      }
      for (final col in resultColumns) {
        columnTypes[col] = ColumnTypeInfo.unknown(col);
      }
      return columnTypes;
    }

    // Try to fetch schema from INFORMATION_SCHEMA (silent fallback on failure)
    final schemaInfo = await _fetchSchemaInfo(
      connection: connection,
      databaseName: databaseName,
      tableNames: tableNames,
    );

    // If schema fetch failed or returned empty, infer from result values
    if (schemaInfo.isEmpty) {
      if (sampleRows != null && sampleRows.isNotEmpty) {
        return _inferTypesFromResults(resultColumns, sampleRows);
      }
      for (final col in resultColumns) {
        columnTypes[col] = ColumnTypeInfo.unknown(col);
      }
      return columnTypes;
    }

    final columnMapping = _mapResultColumnsToSchema(
      resultColumns: resultColumns,
      schemaInfo: schemaInfo,
      query: query,
    );

    return columnMapping;
  }

  /// Format a value based on column type
  static dynamic formatValue(dynamic value, ColumnTypeInfo? info) {
    if (value == null) {
      return null;
    }

    if (info == null || info.dataType == 'unknown') {
      return _formatUnknownValue(value);
    }

    if (info.isBit) {
      return _formatBitValue(value);
    } else if (info.isBinary) {
      return _formatBinaryValue(value);
    } else if (info.isEnum || info.isSet) {
      return _formatEnumSetValue(value, info);
    }

    return _formatStringValue(value);
  }

  /// Fetch column information from INFORMATION_SCHEMA
  /// Silently returns empty map on failure (no user disruption)
  static Future<Map<String, List<ColumnTypeInfo>>> _fetchSchemaInfo({
    required MySQLConnection connection,
    required String databaseName,
    required List<String> tableNames,
  }) async {
    final schemaInfo = <String, List<ColumnTypeInfo>>{};

    final tableNameList = tableNames
        .map((t) => "'${t.replaceAll("'", "''")}'")
        .join(',');

    final query =
        '''
      SELECT
        TABLE_NAME,
        COLUMN_NAME,
        DATA_TYPE,
        COLUMN_TYPE,
        IS_NULLABLE,
        COLUMN_DEFAULT,
        CHARACTER_MAXIMUM_LENGTH,
        NUMERIC_PRECISION,
        NUMERIC_SCALE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = '$databaseName'
      AND TABLE_NAME IN ($tableNameList)
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    ''';

    try {
      final result = await connection.execute(query);

      for (final row in result.rows) {
        final tableNameRaw = row.colByName('TABLE_NAME');
        final columnNameRaw = row.colByName('COLUMN_NAME');
        final dataTypeRaw = row.colByName('DATA_TYPE');
        final columnTypeRaw = row.colByName('COLUMN_TYPE');
        final isNullableRaw = row.colByName('IS_NULLABLE');
        final columnDefaultRaw = row.colByName('COLUMN_DEFAULT');
        final charMaxLengthRaw = row.colByName('CHARACTER_MAXIMUM_LENGTH');
        final numericPrecisionRaw = row.colByName('NUMERIC_PRECISION');
        final numericScaleRaw = row.colByName('NUMERIC_SCALE');

        String tableName = '';
        String columnName = '';
        String dataType = '';
        String columnType = '';
        bool isNullable = true;
        String? columnDefault;
        int? charMaxLength;
        int? numericPrecision;
        int? numericScale;

        if (tableNameRaw is List<int>) {
          tableName = utf8.decode(tableNameRaw).trim();
        } else {
          tableName = tableNameRaw?.toString() ?? '';
        }

        if (columnNameRaw is List<int>) {
          columnName = utf8.decode(columnNameRaw).trim();
        } else {
          columnName = columnNameRaw?.toString() ?? '';
        }

        if (dataTypeRaw is List<int>) {
          dataType = utf8.decode(dataTypeRaw).toLowerCase().trim();
        } else if (dataTypeRaw != null) {
          dataType = dataTypeRaw.toString().toLowerCase();
        }

        if (columnTypeRaw is List<int>) {
          columnType = utf8.decode(columnTypeRaw).trim();
        } else if (columnTypeRaw != null) {
          columnType = columnTypeRaw.toString();
        }

        if (isNullableRaw is List<int>) {
          isNullable = utf8.decode(isNullableRaw).trim().toUpperCase() == 'YES';
        } else if (isNullableRaw != null) {
          isNullable = isNullableRaw.toString().toUpperCase() == 'YES';
        }

        if (columnDefaultRaw is List<int>) {
          columnDefault = utf8.decode(columnDefaultRaw).trim();
        } else if (columnDefaultRaw != null) {
          columnDefault = columnDefaultRaw.toString();
        }

        if (charMaxLengthRaw != null) {
          charMaxLength = int.tryParse(charMaxLengthRaw.toString());
        }

        if (numericPrecisionRaw != null) {
          numericPrecision = int.tryParse(numericPrecisionRaw.toString());
        }

        if (numericScaleRaw != null) {
          numericScale = int.tryParse(numericScaleRaw.toString());
        }

        if (tableName.isEmpty || columnName.isEmpty) continue;

        final info = _parseColumnTypeInfo(
          columnName: columnName,
          tableName: tableName,
          dataType: dataType,
          columnType: columnType,
          isNullable: isNullable,
          columnDefault: columnDefault,
          charMaxLength: charMaxLength,
          numericPrecision: numericPrecision,
          numericScale: numericScale,
        );

        schemaInfo.putIfAbsent(tableName, () => []);
        schemaInfo[tableName]!.add(info);
      }
    } catch (e) {
      // Silent fallback - no error surfaced to user
      // Return empty map to trigger inference from result values
      return {};
    }

    return schemaInfo;
  }

  /// Parse column type information from schema
  static ColumnTypeInfo _parseColumnTypeInfo({
    required String columnName,
    required String tableName,
    required String dataType,
    required String columnType,
    bool isNullable = true,
    String? columnDefault,
    int? charMaxLength,
    int? numericPrecision,
    int? numericScale,
  }) {
    final lowerType = dataType.toLowerCase();
    final lowerColumnType = columnType.toLowerCase();

    final isBinary =
        lowerType.contains('blob') ||
        lowerType.contains('binary') ||
        lowerType.contains('varbinary');

    final isBit = lowerType == 'bit' || lowerType.startsWith('bit(');

    final isEnum = lowerColumnType.startsWith('enum(');
    final isSet = lowerColumnType.startsWith('set(');

    final List<String> enumValues = isEnum
        ? _parseEnumSetValues(lowerColumnType)
        : [];
    final List<String> setValues = isSet
        ? _parseEnumSetValues(lowerColumnType)
        : [];

    return ColumnTypeInfo(
      columnName: columnName,
      tableName: tableName,
      dataType: dataType,
      isBinary: isBinary,
      isBit: isBit,
      isEnum: isEnum,
      isSet: isSet,
      enumValues: enumValues,
      setValues: setValues,
      confidence: TypeConfidence.high,
      isNullable: isNullable,
      columnDefault: columnDefault,
      charMaxLength: charMaxLength,
      numericPrecision: numericPrecision,
      numericScale: numericScale,
    );
  }

  /// Parse ENUM or SET values from type string
  static List<String> _parseEnumSetValues(String typeString) {
    if (!typeString.contains('(') || !typeString.contains(')')) {
      return [];
    }

    final startIndex = typeString.indexOf('(');
    final endIndex = typeString.lastIndexOf(')');
    final valuesPart = typeString.substring(startIndex + 1, endIndex);

    final values = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escapeNext = false;

    for (final char in valuesPart.runes) {
      final ch = String.fromCharCode(char);

      if (escapeNext) {
        buffer.write(ch);
        escapeNext = false;
      } else if (ch == '\\') {
        escapeNext = true;
      } else if (ch == "'") {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }

    values.add(buffer.toString());
    return values;
  }

  /// Map result columns to schema information
  static Map<String, ColumnTypeInfo> _mapResultColumnsToSchema({
    required List<String> resultColumns,
    required Map<String, List<ColumnTypeInfo>> schemaInfo,
    required String query,
  }) {
    final columnMapping = <String, ColumnTypeInfo>{};

    for (final resultCol in resultColumns) {
      ColumnTypeInfo? bestMatch;

      for (final tableInfo in schemaInfo.values) {
        for (final colInfo in tableInfo) {
          final colName = colInfo.columnName;

          if (colName.toLowerCase() == resultCol.toLowerCase()) {
            bestMatch = colInfo;
            break;
          }

          if (resultCol.contains('.') &&
              colName.toLowerCase() ==
                  resultCol.split('.').last.toLowerCase()) {
            bestMatch = colInfo;
            break;
          }
        }
        if (bestMatch != null) break;
      }

      columnMapping[resultCol] = bestMatch ?? ColumnTypeInfo.unknown(resultCol);
    }

    return columnMapping;
  }

  /// Infer column types from result values (fallback when schema unavailable)
  /// Returns low-confidence type information based on runtime value analysis
  static Map<String, ColumnTypeInfo> _inferTypesFromResults(
    List<String> columns,
    List<Map<String, dynamic>> rows,
  ) {
    final columnTypes = <String, ColumnTypeInfo>{};

    for (final col in columns) {
      // Analyze non-null values for this column
      final nonNullValues = rows
          .map((row) => row[col])
          .where((v) => v != null)
          .toList();

      if (nonNullValues.isEmpty) {
        columnTypes[col] = ColumnTypeInfo.unknown(col);
        continue;
      }

      // Check if all values are List<int> (binary or bit)
      final listIntValues = nonNullValues.whereType<List<int>>().toList();
      if (listIntValues.isNotEmpty) {
        // Check if it's likely BIT(1) - single byte with value 0 or 1
        final isBit = listIntValues.every(
          (v) => v.length == 1 && (v[0] == 0 || v[0] == 1),
        );

        if (isBit) {
          columnTypes[col] = ColumnTypeInfo(
            columnName: col,
            tableName: '',
            dataType: 'bit',
            isBit: true,
            confidence: TypeConfidence.low,
          );
        } else {
          // Likely binary data
          columnTypes[col] = ColumnTypeInfo(
            columnName: col,
            tableName: '',
            dataType: 'binary',
            isBinary: true,
            confidence: TypeConfidence.low,
          );
        }
        continue;
      }

      // Check for binary data in string format (hex strings)
      final stringValues = nonNullValues.whereType<String>().toList();
      if (stringValues.isNotEmpty) {
        // Check if values look like hex-encoded binary
        final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
        final looksLikeBinary = stringValues.every(
          (v) => hexPattern.hasMatch(v) && v.length > 16,
        );

        if (looksLikeBinary) {
          columnTypes[col] = ColumnTypeInfo(
            columnName: col,
            tableName: '',
            dataType: 'binary',
            isBinary: true,
            confidence: TypeConfidence.low,
          );
          continue;
        }
      }

      // Cannot reliably infer ENUM/SET without schema
      // Default to unknown with low confidence
      columnTypes[col] = ColumnTypeInfo.unknown(col);
    }

    return columnTypes;
  }

  /// Format BIT value
  static String _formatBitValue(dynamic value) {
    if (value is List<int>) {
      return value.isNotEmpty ? value.first.toString() : '0';
    }

    if (value is String && value.startsWith('[') && value.endsWith(']')) {
      final inner = value.substring(1, value.length - 1);
      final intValue = int.tryParse(inner.trim());
      return (intValue ?? 0).toString();
    }

    final intValue = int.tryParse(value.toString());
    return (intValue ?? 0).toString();
  }

  /// Format binary value as hex
  static String _formatBinaryValue(dynamic value) {
    String hexStr;

    if (value is List<int>) {
      hexStr = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } else if (value is String) {
      hexStr = value;
    } else {
      hexStr = value.toString();
    }

    if (hexStr.startsWith('0x')) {
      hexStr = hexStr.substring(2);
    }

    if (hexStr.isEmpty) {
      return '0x';
    } else if (hexStr.length > 16) {
      return '0x${hexStr.substring(0, 16)}... (${hexStr.length ~/ 2} bytes)';
    } else {
      return '0x$hexStr';
    }
  }

  /// Format ENUM/SET value
  static String _formatEnumSetValue(dynamic value, ColumnTypeInfo info) {
    if (value == null) return '';

    final valueStr = value.toString();

    if (info.isEnum) {
      return valueStr;
    }

    if (info.isSet) {
      return valueStr;
    }

    return valueStr;
  }

  /// Format unknown value (safe default)
  static String _formatUnknownValue(dynamic value) {
    if (value is List<int>) {
      if (_isLikelyBinaryData(value)) {
        final hexStr = value
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (hexStr.length > 16) {
          return '0x${hexStr.substring(0, 16)}... (${hexStr.length ~/ 2} bytes)';
        }
        return '0x$hexStr';
      }
      return value.isNotEmpty ? value.first.toString() : '';
    }

    try {
      return value.toString();
    } catch (e) {
      return '<binary>';
    }
  }

  /// Format string value
  static String _formatStringValue(dynamic value) {
    try {
      return value.toString();
    } catch (e) {
      return '<error>';
    }
  }

  /// Check if byte list is likely binary data
  static bool _isLikelyBinaryData(List<int> bytes) {
    if (bytes.isEmpty) return false;

    var nonPrintableCount = 0;
    for (final byte in bytes) {
      if (byte < 32 && byte != 9 && byte != 10 && byte != 13) {
        nonPrintableCount++;
      } else if (byte > 126) {
        nonPrintableCount++;
      }
    }

    return nonPrintableCount > bytes.length * 0.3;
  }
}
