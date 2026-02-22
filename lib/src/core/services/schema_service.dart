import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_driver.dart';

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
        debugPrint('Timeout waiting for columns: $cacheKey');
        return [];
      }
      return _columnsCache[cacheKey] ?? [];
    }

    _loadingTables.add(cacheKey);

    try {
      final columns = await driver.getColumns(tableName);
      _columnsCache[cacheKey] = columns;
      return columns;
    } catch (e) {
      debugPrint('Error loading columns for $tableName: $e');
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
              debugPrint('Timeout preloading columns for: $table');
              return <ColumnInfo>[];
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error preloading columns: $e');
    }
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
