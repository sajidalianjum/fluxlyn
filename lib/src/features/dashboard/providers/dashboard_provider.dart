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
        errorMessage = 'Authentication Failed: MySQL requires a secure connection for this user. Please try enabling "SSL" in your connection settings.';
      } else if (errorMessage.contains('errno=61')) {
        errorMessage = 'Connection Refused: Ensure your database is running and accepting remote connections on the specified port.';
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
}
