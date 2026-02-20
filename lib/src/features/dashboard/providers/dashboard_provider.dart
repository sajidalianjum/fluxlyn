import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mysql_dart/mysql_dart.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/database_driver.dart';
import '../../connections/models/connection_model.dart';
import '../models/table_search_result.dart';

enum ConnectionStep {
  initializing,
  connectingSsh,
  authenticatingSsh,
  connectingDatabase,
  loadingDatabases,
  loadingTables,
  completed,
}

class DashboardProvider extends ChangeNotifier with WidgetsBindingObserver {
  ConnectionModel? _currentConnectionModel;
  DatabaseDriver? _driver;
  bool _wasConnectedBeforePause = false;
  bool _isReconnecting = false;

  List<String> _databases = [];
  String? _selectedDatabase;
  List<String> _tables = [];
  bool _isLoading = false;
  String? _error;
  int _selectedTabIndex = 0;
  ConnectionStep _connectionStep = ConnectionStep.initializing;
  String? _pendingQuery;

  ConnectionModel? get currentConnectionModel => _currentConnectionModel;
  String? get pendingQuery => _pendingQuery;
  DatabaseDriver? get driver => _driver;
  List<String> get databases => _databases;
  String? get selectedDatabase => _selectedDatabase;
  List<String> get tables => _tables;
  bool get isLoading => _isLoading;
  bool get isReconnecting => _isReconnecting;
  String? get error => _error;
  int get selectedTabIndex => _selectedTabIndex;
  ConnectionStep get connectionStep => _connectionStep;

  void setPendingQuery(String? query) {
    _pendingQuery = query;
    notifyListeners();
  }

  void clearPendingQuery() {
    _pendingQuery = null;
  }

  void setTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  Future<void> connect(ConnectionModel config) async {
    _isLoading = true;
    _error = null;
    _connectionStep = ConnectionStep.initializing;
    notifyListeners();

    try {
      WidgetsBinding.instance.addObserver(this);

      if (_driver != null) {
        await _driver!.disconnect();
      }

      if (config.useSsh) {
        _connectionStep = ConnectionStep.connectingSsh;
        notifyListeners();
      }

      _driver = DatabaseService.createDriver(config.type);
      await _driver!.connect(config);
      _currentConnectionModel = config;
      _selectedDatabase = config.databaseName;
      _wasConnectedBeforePause = true;

      _connectionStep = ConnectionStep.loadingDatabases;
      notifyListeners();
      await refreshDatabases();

      if (_selectedDatabase != null && _selectedDatabase!.isNotEmpty) {
        _connectionStep = ConnectionStep.loadingTables;
        notifyListeners();
        await refreshTables();
      }

      _selectedTabIndex = 0;
      _connectionStep = ConnectionStep.completed;
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('caching_sha2_password')) {
        errorMessage =
            'Authentication Failed: MySQL requires a secure connection for this user. Please try enabling "SSL" in your connection settings.';
      } else if (errorMessage.contains('errno=61')) {
        errorMessage =
            'Connection Refused: Ensure your database is running and accepting remote connections on the specified port.';
      }
      _error = errorMessage;
      _currentConnectionModel = null;
      _connectionStep = ConnectionStep.initializing;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDatabases() async {
    if (_driver == null) return;
    try {
      _databases = await _driver!.getDatabases();
      _error = null;
    } catch (e) {
      _error = 'Failed to load databases: $e';
    }
    notifyListeners();
  }

  Future<void> selectDatabase(String dbName) async {
    if (_driver == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _driver!.useDatabase(dbName);
      _selectedDatabase = dbName;
      await refreshTables();
    } catch (e) {
      _error = 'Failed to select database: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTables() async {
    if (_driver == null || _selectedDatabase == null) return;
    try {
      _tables = await _driver!.getTables();
      _error = null;
    } catch (e) {
      _error = 'Failed to load tables: $e';
    }
    notifyListeners();
  }

  Future<dynamic> executeQuery(String sql) async {
    if (_driver == null) return null;
    try {
      return await _driver!.execute(sql);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearDatabaseSelection() async {
    _selectedDatabase = null;
    _tables = [];
    notifyListeners();
  }

  Future<void> disconnect() async {
    WidgetsBinding.instance.removeObserver(this);
    await _driver?.disconnect();
    _driver = null;
    _currentConnectionModel = null;
    _databases = [];
    _selectedDatabase = null;
    _tables = [];
    _wasConnectedBeforePause = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasConnectedBeforePause = _driver != null;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasConnectedBeforePause &&
          _driver != null &&
          _currentConnectionModel != null) {
        _checkAndReconnect();
      }
    }
  }

  Future<void> _checkAndReconnect() async {
    if (_driver == null) {
      _autoReconnect();
      return;
    }

    try {
      final isConnected = await _driver!.isConnected();
      if (!isConnected) {
        _autoReconnect();
      }
    } catch (e) {
      _autoReconnect();
    }
  }

  Future<void> _autoReconnect() async {
    if (_currentConnectionModel == null) return;

    _isLoading = true;
    _isReconnecting = true;
    _error = null;
    notifyListeners();

    try {
      _driver = null;

      if (_currentConnectionModel!.useSsh) {
        _connectionStep = ConnectionStep.connectingSsh;
        notifyListeners();
      }

      _driver = DatabaseService.createDriver(_currentConnectionModel!.type);
      await _driver!.connect(_currentConnectionModel!);

      _connectionStep = ConnectionStep.loadingDatabases;
      notifyListeners();
      await refreshDatabases();

      if (_selectedDatabase != null && _selectedDatabase!.isNotEmpty) {
        _connectionStep = ConnectionStep.loadingTables;
        notifyListeners();
        await refreshTables();
      }

      _connectionStep = ConnectionStep.completed;
    } catch (e) {
      _driver = null;
      _error = 'Auto-reconnect failed: $e';
      _connectionStep = ConnectionStep.initializing;
      _wasConnectedBeforePause = false;
    } finally {
      _isLoading = false;
      _isReconnecting = false;
      notifyListeners();
    }
  }

  Future<TableDataResult> fetchTableData(
    String tableName, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (_driver == null) {
      return TableDataResult(error: 'Not connected to database');
    }

    try {
      final primaryKeyColumn = await _driver!.getPrimaryKeyColumn(tableName);
      final columns = await _driver!.getColumns(tableName);

      final binaryColumns = <String>{};
      final bitColumns = <String>{};
      final enumColumns = <String, List<String>>{};
      final setColumns = <String, List<String>>{};
      final allColumns = <String>{};

      for (final col in columns) {
        allColumns.add(col.name);
        final colType = col.type.toLowerCase();

        if (colType == 'bit' || colType.startsWith('bit(')) {
          bitColumns.add(col.name);
        } else if (colType.startsWith('enum(')) {
          enumColumns[col.name] = _parseEnumSetValues(col.type);
        } else if (colType.startsWith('set(')) {
          setColumns[col.name] = _parseEnumSetValues(col.type);
        } else if (colType.contains('blob') ||
            colType.contains('binary') ||
            colType.contains('varbinary')) {
          binaryColumns.add(col.name);
        }
      }

      final selectColumns = allColumns
          .map((col) {
            if (bitColumns.contains(col)) {
              return 'CAST(`$col` AS UNSIGNED) AS `$col`';
            } else if (binaryColumns.contains(col)) {
              return 'HEX(`$col`) AS `$col`';
            }
            return '`$col`';
          })
          .join(', ');

      final result = await executeQuery(
        'SELECT $selectColumns FROM `$tableName` LIMIT $limit OFFSET $offset',
      );

      List<String> columnNames = [];
      List<Map<String, dynamic>> rows = [];

      if (_currentConnectionModel!.type == ConnectionType.mysql) {
        final mysqlResult = result as IResultSet;
        if (mysqlResult.rows.isNotEmpty) {
          final firstRowMap = mysqlResult.rows.first.assoc();
          columnNames = firstRowMap.keys.toList();

          for (final row in mysqlResult.rows) {
            final rowMap = Map<String, dynamic>.from(row.assoc());

            for (final col in bitColumns) {
              if (rowMap[col] != null) {
                final colValue = rowMap[col];
                if (colValue is List<int>) {
                  if (colValue.isEmpty) {
                    rowMap[col] = 0;
                  } else {
                    rowMap[col] = colValue[0];
                  }
                } else if (colValue is! int) {
                  rowMap[col] = int.tryParse(colValue.toString()) ?? 0;
                }
              }
            }

            for (final col in binaryColumns) {
              if (rowMap[col] != null) {
                final colValue = rowMap[col];
                String hexStr;

                if (colValue is List<int>) {
                  hexStr = colValue
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join();
                } else {
                  hexStr = colValue.toString();
                }

                if (hexStr.startsWith('0x')) {
                  hexStr = hexStr.substring(2);
                }

                if (hexStr.isEmpty) {
                  rowMap[col] = '0x';
                } else if (hexStr.length > 16) {
                  rowMap[col] =
                      '0x${hexStr.substring(0, 16)}... (${hexStr.length ~/ 2} bytes)';
                } else {
                  rowMap[col] = '0x$hexStr';
                }
              }
            }
            rows.add(rowMap);
          }
        }
      } else {
        final pgResult = result as List<Map<String, dynamic>>;
        if (pgResult.isNotEmpty) {
          columnNames = pgResult.first.keys.toList();
          rows = pgResult;
        }
      }

      final hasNextPage = rows.length >= limit;

      return TableDataResult(
        columns: columnNames,
        rows: rows,
        primaryKeyColumn: primaryKeyColumn,
        binaryColumns: binaryColumns.toList(),
        bitColumns: bitColumns.toList(),
        enumColumns: enumColumns,
        setColumns: setColumns,
        offset: offset,
        limit: limit,
        hasNextPage: hasNextPage,
      );
    } catch (e) {
      return TableDataResult(error: 'Failed to fetch table data: $e');
    }
  }

  Future<TableDataResult> fetchTableDataWithFilter({
    required String tableName,
    String? searchColumn,
    String? searchText,
    String? sortColumn,
    SortDirection sortDirection = SortDirection.asc,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_driver == null) {
      return TableDataResult(error: 'Not connected to database');
    }

    try {
      String? primaryKeyColumn = await _driver!.getPrimaryKeyColumn(tableName);
      final columns = await _driver!.getColumns(tableName);

      final binaryColumns = <String>{};
      final bitColumns = <String>{};
      final enumColumns = <String, List<String>>{};
      final setColumns = <String, List<String>>{};
      final allColumns = <String>{};

      for (final col in columns) {
        allColumns.add(col.name);
        final colType = col.type.toLowerCase();

        if (colType == 'bit' || colType.startsWith('bit(')) {
          bitColumns.add(col.name);
        } else if (colType.startsWith('enum(')) {
          enumColumns[col.name] = _parseEnumSetValues(col.type);
        } else if (colType.startsWith('set(')) {
          setColumns[col.name] = _parseEnumSetValues(col.type);
        } else if (colType.contains('blob') ||
            colType.contains('binary') ||
            colType.contains('varbinary')) {
          binaryColumns.add(col.name);
        }
      }

      final selectColumns = allColumns
          .map((col) {
            if (bitColumns.contains(col)) {
              return 'CAST(`$col` AS UNSIGNED) AS `$col`';
            } else if (binaryColumns.contains(col)) {
              return 'HEX(`$col`) AS `$col`';
            }
            return '`$col`';
          })
          .join(', ');

      final conditions = <String>[];
      if (searchColumn != null && searchText != null && searchText.isNotEmpty) {
        conditions.add('`$searchColumn` LIKE \'%$searchText%\'');
      }

      final orderByClauses = <String>[];
      if (sortColumn != null && sortColumn.isNotEmpty) {
        final direction = sortDirection == SortDirection.asc ? 'ASC' : 'DESC';
        orderByClauses.add('`$sortColumn` $direction');
      }

      var query = 'SELECT $selectColumns FROM `$tableName`';
      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }
      if (orderByClauses.isNotEmpty) {
        query += ' ORDER BY ${orderByClauses.join(', ')}';
      }
      query += ' LIMIT $limit OFFSET $offset';

      final result = await executeQuery(query);

      List<String> columnNames = [];
      List<Map<String, dynamic>> rows = [];

      if (_currentConnectionModel!.type == ConnectionType.mysql) {
        final mysqlResult = result as IResultSet;
        if (mysqlResult.rows.isNotEmpty) {
          final firstRowMap = mysqlResult.rows.first.assoc();
          columnNames = firstRowMap.keys.toList();

          for (final row in mysqlResult.rows) {
            final rowMap = Map<String, dynamic>.from(row.assoc());

            for (final col in bitColumns) {
              if (rowMap[col] != null) {
                final colValue = rowMap[col];
                if (colValue is List<int>) {
                  if (colValue.isEmpty) {
                    rowMap[col] = 0;
                  } else {
                    rowMap[col] = colValue[0];
                  }
                } else if (colValue is! int) {
                  rowMap[col] = int.tryParse(colValue.toString()) ?? 0;
                }
              }
            }

            for (final col in binaryColumns) {
              if (rowMap[col] != null) {
                final colValue = rowMap[col];
                String hexStr;

                if (colValue is List<int>) {
                  hexStr = colValue
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join();
                } else {
                  hexStr = colValue.toString();
                }

                if (hexStr.startsWith('0x')) {
                  hexStr = hexStr.substring(2);
                }

                if (hexStr.isEmpty) {
                  rowMap[col] = '0x';
                } else if (hexStr.length > 16) {
                  rowMap[col] =
                      '0x${hexStr.substring(0, 16)}... (${hexStr.length ~/ 2} bytes)';
                } else {
                  rowMap[col] = '0x$hexStr';
                }
              }
            }
            rows.add(rowMap);
          }
        }
      } else {
        final pgResult = result as List<Map<String, dynamic>>;
        if (pgResult.isNotEmpty) {
          columnNames = pgResult.first.keys.toList();
          rows = pgResult;
        }
      }

      final hasNextPage = rows.length >= limit;

      return TableDataResult(
        columns: columnNames,
        rows: rows,
        primaryKeyColumn: primaryKeyColumn,
        binaryColumns: binaryColumns.toList(),
        bitColumns: bitColumns.toList(),
        enumColumns: enumColumns,
        setColumns: setColumns,
        offset: offset,
        limit: limit,
        hasNextPage: hasNextPage,
      );
    } catch (e) {
      return TableDataResult(error: 'Failed to fetch filtered table data: $e');
    }
  }

  Future<String?> updateRow(
    String tableName,
    String primaryKeyColumn,
    dynamic primaryKeyValue,
    Map<String, dynamic> updates,
  ) async {
    if (_driver == null) {
      return 'Not connected to database';
    }

    try {
      final setClauses = <String>[];
      for (final entry in updates.entries) {
        if (entry.value == null) {
          setClauses.add('`${entry.key}` = NULL');
        } else if (entry.value is String) {
          final escaped = (entry.value as String).replaceAll("'", "''");
          setClauses.add('`${entry.key}` = \'$escaped\'');
        } else if (entry.value is DateTime) {
          final formatted = (entry.value as DateTime).toIso8601String();
          setClauses.add('`${entry.key}` = \'$formatted\'');
        } else {
          setClauses.add('`${entry.key}` = ${entry.value}');
        }
      }

      String whereClause;
      if (primaryKeyValue == null) {
        return 'Cannot update row: primary key value is null';
      } else if (primaryKeyValue is String) {
        final escaped = primaryKeyValue.replaceAll("'", "''");
        whereClause = '`$primaryKeyColumn` = \'$escaped\'';
      } else {
        whereClause = '`$primaryKeyColumn` = $primaryKeyValue';
      }

      final sql =
          'UPDATE `$tableName` SET ${setClauses.join(', ')} WHERE $whereClause';
      await executeQuery(sql);

      return null;
    } catch (e) {
      return 'Failed to update row: $e';
    }
  }
}

class TableDataResult {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final String? primaryKeyColumn;
  final List<String> binaryColumns;
  final List<String> bitColumns;
  final Map<String, List<String>> enumColumns;
  final Map<String, List<String>> setColumns;
  final String? error;
  final int offset;
  final int limit;
  final bool hasNextPage;

  TableDataResult({
    this.columns = const [],
    this.rows = const [],
    this.primaryKeyColumn,
    this.binaryColumns = const [],
    this.bitColumns = const [],
    this.enumColumns = const {},
    this.setColumns = const {},
    this.error,
    this.offset = 0,
    this.limit = 100,
    this.hasNextPage = false,
  });

  bool get hasError => error != null;
  bool get isEditable => primaryKeyColumn != null && rows.isNotEmpty;
}

List<String> _parseEnumSetValues(String typeString) {
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
