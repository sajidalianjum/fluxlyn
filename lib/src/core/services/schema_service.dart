import 'package:mysql_client/mysql_client.dart';

class ColumnInfo {
  final String name;
  final String dataType;
  final bool isNullable;

  ColumnInfo({
    required this.name,
    required this.dataType,
    required this.isNullable,
  });
}

class SchemaService {
  // Cache for table columns
  final Map<String, List<ColumnInfo>> _columnsCache = {};
  final Set<String> _loadingTables = {};

  /// Get columns for a specific table (lazy loading with caching)
  Future<List<ColumnInfo>> getColumns(
    MySQLConnection connection,
    String databaseName,
    String tableName,
  ) async {
    final cacheKey = '$databaseName.$tableName';

    // Return cached columns if available
    if (_columnsCache.containsKey(cacheKey)) {
      return _columnsCache[cacheKey]!;
    }

    // Prevent duplicate concurrent requests
    if (_loadingTables.contains(cacheKey)) {
      // Wait for the loading to complete
      while (_loadingTables.contains(cacheKey)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _columnsCache[cacheKey] ?? [];
    }

    _loadingTables.add(cacheKey);

    try {
      final result = await connection.execute("""
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '$databaseName' AND TABLE_NAME = '$tableName'
        ORDER BY ORDINAL_POSITION
        """);

      final columns = result.rows.map((row) {
        return ColumnInfo(
          name: row.colByName('COLUMN_NAME') ?? '',
          dataType: row.colByName('DATA_TYPE') ?? '',
          isNullable: row.colByName('IS_NULLABLE') == 'YES',
        );
      }).toList();

      _columnsCache[cacheKey] = columns;
      return columns;
    } finally {
      _loadingTables.remove(cacheKey);
    }
  }

  /// Preload columns for multiple tables (called when entering editor)
  Future<void> preloadColumns(
    MySQLConnection connection,
    String databaseName,
    List<String> tableNames,
  ) async {
    final tablesToLoad = tableNames.where((table) {
      final cacheKey = '$databaseName.$table';
      return !_columnsCache.containsKey(cacheKey);
    }).toList();

    // Load in parallel
    await Future.wait(
      tablesToLoad.map(
        (table) =>
            getColumns(connection, databaseName, table).catchError((_) => []),
      ),
    );
  }

  /// Get all column names for autocomplete
  List<String> getAllColumnNames(String databaseName, String? tableName) {
    if (tableName != null) {
      final cacheKey = '$databaseName.$tableName';
      final columns = _columnsCache[cacheKey];
      if (columns != null) {
        return columns.map((c) => c.name).toList();
      }
    }

    // Return all columns from all cached tables
    final allColumns = <String>[];
    for (final entry in _columnsCache.entries) {
      if (entry.key.startsWith('$databaseName.')) {
        allColumns.addAll(entry.value.map((c) => c.name));
      }
    }
    return allColumns;
  }

  /// Clear cache for a specific database
  void clearCache(String? databaseName) {
    if (databaseName == null) {
      _columnsCache.clear();
    } else {
      _columnsCache.removeWhere((key, _) => key.startsWith('$databaseName.'));
    }
  }

  /// Check if columns are loaded for a table
  bool isLoaded(String databaseName, String tableName) {
    final cacheKey = '$databaseName.$tableName';
    return _columnsCache.containsKey(cacheKey);
  }
}
