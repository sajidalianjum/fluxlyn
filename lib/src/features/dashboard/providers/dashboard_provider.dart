import 'package:flutter/material.dart';
import 'package:mysql_client/mysql_client.dart';
import '../../../core/services/database_service.dart';
import '../../connections/models/connection_model.dart';
import 'dart:async';

class DashboardProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  ConnectionModel? _currentConnectionModel;
  MySQLConnection? _connection;

  // State
  List<String> _databases = [];
  String? _selectedDatabase;
  List<String> _tables = [];
  bool _isLoading = false;
  String? _error;
  int _selectedTabIndex = 0; // Bottom Nav Index

  ConnectionModel? get currentConnectionModel => _currentConnectionModel;
  MySQLConnection? get currentConnection => _connection;
  List<String> get databases => _databases;
  String? get selectedDatabase => _selectedDatabase;
  List<String> get tables => _tables;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get selectedTabIndex => _selectedTabIndex;

  void setTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  Future<void> connect(ConnectionModel config) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_connection != null) {
        await _dbService.disconnect();
      }

      _connection = await _dbService.connect(config);
      _currentConnectionModel = config;
      _selectedDatabase = config.databaseName;

      if (_selectedDatabase != null && _selectedDatabase!.isNotEmpty) {
        await refreshTables();
      } else {
        await refreshDatabases();
      }

      // Navigate to Schema/Databases tab by default
      _selectedTabIndex = 0;
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDatabases() async {
    if (_connection == null) return;
    try {
      _databases = await _dbService.getDatabases(_connection!);
      _error = null;
    } catch (e) {
      _error = 'Failed to load databases: $e';
    }
    notifyListeners();
  }

  Future<void> selectDatabase(String dbName) async {
    if (_connection == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dbService.useDatabase(_connection!, dbName);
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
    if (_connection == null || _selectedDatabase == null) return;
    try {
      _tables = await _dbService.getTables(_connection!);
      _error = null;
    } catch (e) {
      _error = 'Failed to load tables: $e';
    }
    notifyListeners();
  }

  Future<IResultSet?> executeQuery(String sql) async {
    if (_connection == null) return null;
    try {
      return await _dbService.execute(_connection!, sql);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearDatabaseSelection() async {
    _selectedDatabase = null;
    _tables = [];
    await refreshDatabases();
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _dbService.disconnect();
    _connection = null;
    _currentConnectionModel = null;
    _databases = [];
    _selectedDatabase = null;
    _tables = [];
    notifyListeners();
  }

  // Table data methods
  Future<TableDataResult> fetchTableData(
    String tableName, {
    int limit = 100,
  }) async {
    if (_connection == null) {
      return TableDataResult(error: 'Not connected to database');
    }

    try {
      // Get primary key info first
      final pkResult = await _dbService.execute(
        _connection!,
        "SHOW KEYS FROM `$tableName` WHERE Key_name = 'PRIMARY'",
      );
      String? primaryKeyColumn;
      for (final row in pkResult.rows) {
        primaryKeyColumn = row.colByName('Column_name');
        break; // Take first PK column
      }

      // Get column types to detect binary columns
      final columnsResult = await _dbService.execute(
        _connection!,
        'SHOW COLUMNS FROM `$tableName`',
      );
      final binaryColumns = <String>{};
      final bitColumns = <String>{};
      final allColumns = <String>[];
      for (final row in columnsResult.rows) {
        final colName = row.colByName('Field');
        final colType = row.colByName('Type')?.toLowerCase() ?? '';
        if (colName != null) {
          allColumns.add(colName);
          // Detect BIT columns separately
          if (colType.contains('bit')) {
            bitColumns.add(colName);
          } else if (colType.contains('blob') ||
              colType.contains('binary') ||
              colType.contains('varbinary')) {
            binaryColumns.add(colName);
          }
        }
      }

      // Build SELECT query that handles binary columns safely
      // Convert binary columns to HEX to avoid UTF-8 decoding issues
      final selectColumns = allColumns
          .map((col) {
            if (binaryColumns.contains(col) || bitColumns.contains(col)) {
              return 'HEX(`$col`) AS `$col`';
            }
            return '`$col`';
          })
          .join(', ');

      // Fetch table data
      final result = await _dbService.execute(
        _connection!,
        'SELECT $selectColumns FROM `$tableName` LIMIT $limit',
      );

      // Extract columns and rows
      List<String> columns = [];
      List<Map<String, dynamic>> rows = [];

      if (result.rows.isNotEmpty) {
        // Get column names from first row using assoc()
        final firstRowMap = result.rows.first.assoc();
        columns = firstRowMap.keys.toList();

        // Convert all rows to maps
        for (final row in result.rows) {
          final rowMap = Map<String, dynamic>.from(row.assoc());
          // Handle BIT columns - convert hex to 0/1
          for (final col in bitColumns) {
            if (rowMap[col] != null) {
              final hexStr = rowMap[col].toString();
              // Convert hex to integer (0 or 1)
              try {
                final intValue = int.parse(hexStr, radix: 16);
                rowMap[col] = intValue;
              } catch (e) {
                rowMap[col] = hexStr == '00' ? 0 : 1;
              }
            }
          }
          // Truncate hex values for binary columns
          for (final col in binaryColumns) {
            if (rowMap[col] != null) {
              final hexStr = rowMap[col].toString();
              if (hexStr.length > 16) {
                rowMap[col] =
                    '${hexStr.substring(0, 16)}... (${hexStr.length ~/ 2} bytes)';
              } else {
                rowMap[col] = '0x$hexStr';
              }
            }
          }
          rows.add(rowMap);
        }
      }

      return TableDataResult(
        columns: columns,
        rows: rows,
        primaryKeyColumn: primaryKeyColumn,
        binaryColumns: binaryColumns.toList(),
        bitColumns: bitColumns.toList(),
      );
    } catch (e) {
      return TableDataResult(error: 'Failed to fetch table data: $e');
    }
  }

  Future<String?> updateRow(
    String tableName,
    String primaryKeyColumn,
    dynamic primaryKeyValue,
    Map<String, dynamic> updates,
  ) async {
    if (_connection == null) {
      return 'Not connected to database';
    }

    try {
      // Build SET clause
      final setClauses = <String>[];
      for (final entry in updates.entries) {
        if (entry.value == null) {
          setClauses.add('`${entry.key}` = NULL');
        } else if (entry.value is String) {
          // Escape single quotes
          final escaped = (entry.value as String).replaceAll("'", "''");
          setClauses.add('`${entry.key}` = \'$escaped\'');
        } else if (entry.value is DateTime) {
          final formatted = (entry.value as DateTime).toIso8601String();
          setClauses.add('`${entry.key}` = \'$formatted\'');
        } else {
          setClauses.add('`${entry.key}` = ${entry.value}');
        }
      }

      // Build WHERE clause
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
      await _dbService.execute(_connection!, sql);

      return null; // Success
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
  final String? error;

  TableDataResult({
    this.columns = const [],
    this.rows = const [],
    this.primaryKeyColumn,
    this.binaryColumns = const [],
    this.bitColumns = const [],
    this.error,
  });

  bool get hasError => error != null;
  bool get isEditable => primaryKeyColumn != null && rows.isNotEmpty;
}
