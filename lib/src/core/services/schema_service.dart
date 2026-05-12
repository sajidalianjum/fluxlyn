import 'dart:async';
import 'database_driver.dart';
import '../utils/error_reporter.dart';

class SchemaService {
  static const Duration _waitTimeout = Duration(seconds: 5);
  static const Duration _preloadTimeout = Duration(seconds: 30);

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
      final stopwatch = Stopwatch()..start();
      while (_loadingTables.contains(cacheKey) &&
          stopwatch.elapsed < _waitTimeout) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_loadingTables.contains(cacheKey)) {
        ErrorReporter.warning(
          'Timeout waiting for columns: $cacheKey',
          null,
          'SchemaService.getColumns',
          'schema_service.dart:31',
        );
        return [];
      }
      return _columnsCache[cacheKey] ?? [];
    }

    _loadingTables.add(cacheKey);

    try {
      final columns = await driver.getColumns(tableName);
      _columnsCache[cacheKey] = columns;
      return columns;
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error loading columns for $tableName: $e',
        stackTrace,
        'SchemaService.getColumns',
        'schema_service.dart:44',
      );
      return [];
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

    try {
      await Future.wait(
        tablesToLoad.map(
          (table) => getColumns(driver, databaseName, table).timeout(
            _preloadTimeout,
            onTimeout: () {
              ErrorReporter.warning(
                'Timeout preloading columns for: $table',
                null,
                'SchemaService.preloadColumns',
                'schema_service.dart:67',
              );
              return <ColumnInfo>[];
            },
          ),
        ),
      );
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error preloading columns: $e',
        stackTrace,
        'SchemaService.preloadColumns',
        'schema_service.dart:74',
      );
    }
  }

  Future<List<String>> getColumnNamesWithFallback(
    DatabaseDriver driver,
    String databaseName,
    String tableName,
  ) async {
    final cacheKey = '$databaseName.$tableName';
    if (_columnsCache.containsKey(cacheKey)) {
      return _columnsCache[cacheKey]!.map((c) => c.name).toList();
    }
    await getColumns(driver, databaseName, tableName);
    if (_columnsCache.containsKey(cacheKey)) {
      return _columnsCache[cacheKey]!.map((c) => c.name).toList();
    }
    return [];
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
