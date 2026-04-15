import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mysql_dart/mysql_dart.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/database_driver.dart';
import '../../../core/services/postgres_driver.dart';
import '../../../core/models/exceptions.dart';
import '../../../core/utils/error_reporter.dart';
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
  static const Duration _connectionCheckTimeout = Duration(seconds: 5);

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
  String? _pendingDatabase;

  ConnectionModel? get currentConnectionModel => _currentConnectionModel;
  String? get pendingQuery => _pendingQuery;
  String? get pendingDatabase => _pendingDatabase;
  DatabaseDriver? get driver => _driver;
  List<String> get databases => _databases;
  String? get selectedDatabase => _selectedDatabase;
  List<String> get tables => _tables;
  bool get isLoading => _isLoading;
  bool get isReconnecting => _isReconnecting;
  String? get error => _error;
  int get selectedTabIndex => _selectedTabIndex;
  ConnectionStep get connectionStep => _connectionStep;

  String _formatConnectionError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    if (lowerError.contains('caching_sha2_password')) {
      return 'Authentication Failed: MySQL requires a secure connection for this user. Please try enabling "SSL" in your connection settings.';
    }
    if (lowerError.contains('errno=61') ||
        lowerError.contains('connection refused')) {
      return 'Connection Refused: Ensure your database is running and accepting remote connections on the specified port.';
    }
    if (lowerError.contains('errno=111') ||
        lowerError.contains('no route to host')) {
      return 'Host Unreachable: The specified host could not be reached. Please check host address and network connectivity.';
    }
    if (lowerError.contains('errno=113')) {
      return 'No Route to Host: The host is not reachable from this network.';
    }
    if (lowerError.contains('access denied') ||
        lowerError.contains('authentication failed')) {
      return 'Authentication Failed: Check your username and password credentials.';
    }
    if (lowerError.contains('timeout') || lowerError.contains('timed out')) {
      return 'Connection Timeout: The connection attempt timed out. Please check your network and try again.';
    }
    if (lowerError.contains('unknown database')) {
      return 'Database Not Found: The specified database does not exist or you do not have access to it.';
    }
    if (lowerError.contains('ssl') &&
        (lowerError.contains('error') || lowerError.contains('failed'))) {
      return 'SSL Error: There was an SSL/TLS connection issue. Please verify SSL settings.';
    }

    return errorMessage
        .replaceFirst('ConnectionException: ', '')
        .replaceFirst('ReconnectException: ', '')
        .replaceFirst('Failed to connect to MySQL: ', '')
        .replaceFirst('Failed to connect to PostgreSQL: ', '')
        .trim();
  }

  void setPendingQuery(String? query) {
    _pendingQuery = query;
    notifyListeners();
  }

  void setPendingDatabase(String? database) {
    _pendingDatabase = database;
    notifyListeners();
  }

  void clearPendingQuery() {
    _pendingQuery = null;
    _pendingDatabase = null;
  }

  void clearPendingDatabase() {
    _pendingDatabase = null;
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
        await selectDatabase(_selectedDatabase!);
      }

      _selectedTabIndex = 0;
      _connectionStep = ConnectionStep.completed;
    } catch (e) {
      _error = _formatConnectionError(e.toString());
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
    } catch (e, stackTrace) {
      _error = 'Failed to load databases: ${e.toString()}';
      ErrorReporter.warning(
        'Error loading databases: $e',
        stackTrace,
        'DashboardProvider.refreshDatabases',
        'dashboard_provider.dart:168',
      );
    }
    notifyListeners();
  }

  Future<void> selectDatabase(String dbName) async {
    if (_driver == null) {
      _error = 'Not connected to database';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _driver!.useDatabase(dbName);
      _selectedDatabase = dbName;
      await refreshTables();
    } catch (e, stackTrace) {
      _error = 'Failed to select database: ${e.toString()}';
      ErrorReporter.warning(
        'Error selecting database $dbName: $e',
        stackTrace,
        'DashboardProvider.selectDatabase',
        'dashboard_provider.dart:189',
      );
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
    } catch (e, stackTrace) {
      _error = 'Failed to load tables: ${e.toString()}';
      ErrorReporter.warning(
        'Error loading tables: $e',
        stackTrace,
        'DashboardProvider.refreshTables',
        'dashboard_provider.dart:203',
      );
    }
    notifyListeners();
  }

  Future<dynamic> executeQuery(String sql) async {
    if (_driver == null) {
      throw DatabaseException(
        'Not connected to database',
        operation: 'executeQuery',
        connectionName: _currentConnectionModel?.name,
      );
    }
    try {
      return await _driver!.execute(sql);
    } catch (e) {
      if (e is DatabaseException || e is QueryException) rethrow;
      throw QueryException(
        'Failed to execute query: ${e.toString()}',
        query: sql.length > 200 ? '${sql.substring(0, 200)}...' : sql,
        database: _selectedDatabase,
        originalError: e,
      );
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
      final isConnected = await _driver!.isConnected().timeout(
        _connectionCheckTimeout,
        onTimeout: () => false,
      );
      if (!isConnected) {
        _autoReconnect();
      }
    } catch (e, stackTrace) {
      ErrorReporter.warning(
        'Error checking connection: $e',
        stackTrace,
        'DashboardProvider._checkAndReconnect',
        'dashboard_provider.dart:275',
      );
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
        await selectDatabase(_selectedDatabase!);
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

    if (_currentConnectionModel == null) {
      return TableDataResult(error: 'Connection model not available');
    }

    try {
      final results = await Future.wait([
        _driver!.getPrimaryKeyColumn(tableName),
        _driver!.getColumns(tableName),
      ]);
      final primaryKeyColumn = results[0] as String?;
      final columns = results[1] as List<ColumnInfo>;

      final binaryColumns = <String>{};
      final bitColumns = <String>{};
      final enumColumns = <String, List<String>>{};
      final setColumns = <String, List<String>>{};
      final inetColumns = <String>{};
      final columnTypes = <String, String>{};
      final allColumns = <String>{};

      for (final col in columns) {
        allColumns.add(col.name);
        final colType = col.type.toLowerCase();
        columnTypes[col.name] = colType;

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
        } else if (colType == 'inet' || colType == 'cidr') {
          inetColumns.add(col.name);
        }
      }

      final isPostgreSQL =
          _currentConnectionModel!.type != ConnectionType.mysql;
      final identifierQuote = isPostgreSQL ? '"' : '`';

      if (isPostgreSQL) {
        final postgresEnumColumns = await _driver!.getEnumColumns(tableName);
        enumColumns.addAll(postgresEnumColumns);
      }

      final selectColumns = allColumns
          .map((col) {
            final quotedCol = '$identifierQuote$col$identifierQuote';
            if (bitColumns.contains(col)) {
              if (isPostgreSQL) {
                return '$quotedCol::integer AS $quotedCol';
              }
              return 'CAST($quotedCol AS UNSIGNED) AS $quotedCol';
            } else if (binaryColumns.contains(col)) {
              if (isPostgreSQL) {
                return 'encode($quotedCol::bytea, \'hex\') AS $quotedCol';
              }
              return 'HEX($quotedCol) AS $quotedCol';
            } else if (inetColumns.contains(col)) {
              if (isPostgreSQL) {
                return '$quotedCol::text AS $quotedCol';
              }
              return quotedCol;
            }
            return quotedCol;
          })
          .join(', ');

      final quotedTableName = '$identifierQuote$tableName$identifierQuote';
      final result = await executeQuery(
        'SELECT $selectColumns FROM $quotedTableName LIMIT $limit OFFSET $offset',
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
        final pgResult = result as PostgresExecutionResult;
        if (pgResult.rows.isNotEmpty) {
          columnNames = pgResult.rows.first.keys.toList();
          rows = pgResult.rows;
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
    } catch (e, stackTrace) {
      ErrorReporter.error(
        'Failed to fetch table data: $e',
        stackTrace,
        'DashboardProvider.fetchTableData',
        'dashboard_provider.dart:509',
      );
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

    if (_currentConnectionModel == null) {
      return TableDataResult(error: 'Connection model not available');
    }

    try {
      final results = await Future.wait([
        _driver!.getPrimaryKeyColumn(tableName),
        _driver!.getColumns(tableName),
      ]);
      final primaryKeyColumn = results[0] as String?;
      final columns = results[1] as List<ColumnInfo>;

      final binaryColumns = <String>{};
      final bitColumns = <String>{};
      final enumColumns = <String, List<String>>{};
      final setColumns = <String, List<String>>{};
      final inetColumns = <String>{};
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
        } else if (colType == 'inet' || colType == 'cidr') {
          inetColumns.add(col.name);
        }
      }

      final isPostgreSQL =
          _currentConnectionModel!.type != ConnectionType.mysql;
      final identifierQuote = isPostgreSQL ? '"' : '`';

      if (isPostgreSQL) {
        final postgresEnumColumns = await _driver!.getEnumColumns(tableName);
        enumColumns.addAll(postgresEnumColumns);
      }

      final selectColumns = allColumns
          .map((col) {
            final quotedCol = '$identifierQuote$col$identifierQuote';
            if (bitColumns.contains(col)) {
              if (isPostgreSQL) {
                return '$quotedCol::integer AS $quotedCol';
              }
              return 'CAST($quotedCol AS UNSIGNED) AS $quotedCol';
            } else if (binaryColumns.contains(col)) {
              if (isPostgreSQL) {
                return 'encode($quotedCol::bytea, \'hex\') AS $quotedCol';
              }
              return 'HEX($quotedCol) AS $quotedCol';
            } else if (inetColumns.contains(col)) {
              if (isPostgreSQL) {
                return '$quotedCol::text AS $quotedCol';
              }
              return quotedCol;
            }
            return quotedCol;
          })
          .join(', ');

      final conditions = <String>[];
      if (searchColumn != null && searchText != null && searchText.isNotEmpty) {
        final quotedCol = '$identifierQuote$searchColumn$identifierQuote';
        conditions.add('$quotedCol LIKE \'%$searchText%\'');
      }

      final orderByClauses = <String>[];
      if (sortColumn != null && sortColumn.isNotEmpty) {
        final quotedCol = '$identifierQuote$sortColumn$identifierQuote';
        final direction = sortDirection == SortDirection.asc ? 'ASC' : 'DESC';
        orderByClauses.add('$quotedCol $direction');
      }

      final quotedTableName = '$identifierQuote$tableName$identifierQuote';
      var query = 'SELECT $selectColumns FROM $quotedTableName';
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
        final pgResult = result as PostgresExecutionResult;
        if (pgResult.rows.isNotEmpty) {
          columnNames = pgResult.rows.first.keys.toList();
          rows = pgResult.rows;
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
    } catch (e, stackTrace) {
      ErrorReporter.error(
        'Failed to fetch filtered table data: $e',
        stackTrace,
        'DashboardProvider.fetchTableDataWithFilter',
        'dashboard_provider.dart:707',
      );
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

    if (_currentConnectionModel == null) {
      return 'Connection model not available';
    }

    try {
      final isPostgreSQL =
          _currentConnectionModel!.type != ConnectionType.mysql;
      final identifierQuote = isPostgreSQL ? '"' : '`';

      var columnTypes = <String, String>{};
      if (isPostgreSQL) {
        final columns = await _driver!.getColumns(tableName);
        columnTypes = {for (var c in columns) c.name: c.type.toLowerCase()};
      }

      final setClauses = <String>[];
      for (final entry in updates.entries) {
        final quotedCol = '$identifierQuote${entry.key}$identifierQuote';
        if (entry.value == null) {
          setClauses.add('$quotedCol = NULL');
        } else if (isPostgreSQL) {
          final colType = columnTypes[entry.key] ?? '';

          if (entry.value is String) {
            final escaped = (entry.value as String).replaceAll("'", "''");

            if (colType == 'inet') {
              setClauses.add('$quotedCol = \'$escaped\'::inet');
            } else if (colType == 'cidr') {
              setClauses.add('$quotedCol = \'$escaped\'::cidr');
            } else {
              setClauses.add('$quotedCol = \'$escaped\'');
            }
          } else if (entry.value is DateTime) {
            final formatted = (entry.value as DateTime).toIso8601String();
            setClauses.add('$quotedCol = \'$formatted\'::timestamp');
          } else {
            setClauses.add('$quotedCol = ${entry.value}');
          }
        } else {
          if (entry.value is String) {
            final escaped = (entry.value as String).replaceAll("'", "''");
            setClauses.add('$quotedCol = \'$escaped\'');
          } else if (entry.value is DateTime) {
            final formatted = (entry.value as DateTime).toIso8601String();
            setClauses.add('$quotedCol = \'$formatted\'');
          } else {
            setClauses.add('$quotedCol = ${entry.value}');
          }
        }
      }

      String whereClause;
      final quotedPkCol = '$identifierQuote$primaryKeyColumn$identifierQuote';
      if (primaryKeyValue == null) {
        return 'Cannot update row: primary key value is null';
      } else if (primaryKeyValue is String) {
        final escaped = primaryKeyValue.replaceAll("'", "''");
        whereClause = '$quotedPkCol = \'$escaped\'';
      } else {
        whereClause = '$quotedPkCol = $primaryKeyValue';
      }

      final quotedTableName = '$identifierQuote$tableName$identifierQuote';
      final sql =
          'UPDATE $quotedTableName SET ${setClauses.join(', ')} WHERE $whereClause';
      await executeQuery(sql);

      return null;
    } catch (e, stackTrace) {
      ErrorReporter.error(
        'Failed to update row: $e',
        stackTrace,
        'DashboardProvider.updateRow',
        'dashboard_provider.dart:797',
      );
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
