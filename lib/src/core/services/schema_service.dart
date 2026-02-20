import 'database_driver.dart';

class SchemaService {
  final Map<String, List<ColumnInfo>> _columnsCache = {};
  final Set<String> _loadingTables = {};
  final Map<String, List<String>> _tableNamesCache = {};

  Future<List<ColumnInfo>> getColumns(
    DatabaseDriver driver,
    String databaseName,
    String tableName,
  ) async {
    final cacheKey = '$databaseName.$tableName';

    if (_columnsCache.containsKey(cacheKey)) {
      return _columnsCache[cacheKey]!;
    }

    if (_loadingTables.contains(cacheKey)) {
      while (_loadingTables.contains(cacheKey)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _columnsCache[cacheKey] ?? [];
    }

    _loadingTables.add(cacheKey);

    try {
      final columns = await driver.getColumns(tableName);
      _columnsCache[cacheKey] = columns;
      return columns;
    } finally {
      _loadingTables.remove(cacheKey);
    }
  }

  Future<void> preloadColumns(
    DatabaseDriver driver,
    String databaseName,
    List<String> tableNames,
  ) async {
    final tablesToLoad = tableNames.where((table) {
      final cacheKey = '$databaseName.$table';
      return !_columnsCache.containsKey(cacheKey);
    }).toList();

    await Future.wait(
      tablesToLoad.map(
        (table) => getColumns(
          driver,
          databaseName,
          table,
        ).catchError((_) => <ColumnInfo>[]),
      ),
    );
  }

  List<String> getAllColumnNames(String databaseName, String? tableName) {
    if (tableName != null) {
      final cacheKey = '$databaseName.$tableName';
      final columns = _columnsCache[cacheKey];
      if (columns != null) {
        return columns.map((c) => c.name).toList();
      }
    }

    final allColumns = <String>[];
    for (final entry in _columnsCache.entries) {
      if (entry.key.startsWith('$databaseName.')) {
        allColumns.addAll(entry.value.map((c) => c.name));
      }
    }
    return allColumns;
  }

  void clearCache(String? databaseName) {
    if (databaseName == null) {
      _columnsCache.clear();
    } else {
      _columnsCache.removeWhere((key, _) => key.startsWith('$databaseName.'));
    }
  }

  bool isLoaded(String databaseName, String tableName) {
    final cacheKey = '$databaseName.$tableName';
    return _columnsCache.containsKey(cacheKey);
  }

  List<String> getTableNames(String databaseName) {
    return _tableNamesCache[databaseName] ?? [];
  }

  void setTableNames(String databaseName, List<String> tableNames) {
    _tableNamesCache[databaseName] = tableNames;
  }

  void clearTableNamesCache(String? databaseName) {
    if (databaseName == null) {
      _tableNamesCache.clear();
    } else {
      _tableNamesCache.remove(databaseName);
    }
  }
}
