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
  List<String> _tables = [];
  bool _isLoading = false;
  String? _error;
  int _selectedTabIndex = 0; // Bottom Nav Index

  ConnectionModel? get currentConnectionModel => _currentConnectionModel;
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
      
      // Load initial data (Schema)
      await refreshTables();
      
      // Navigate to Schema/Databases tab by default
      _selectedTabIndex = 0;
      
    } catch (e) {
      _error = e.toString();
      _currentConnectionModel = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refreshTables() async {
      if (_connection == null) return;
      try {
          _tables = await _dbService.getTables(_connection!);
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

  Future<void> disconnect() async {
      await _dbService.disconnect();
      _connection = null;
      _currentConnectionModel = null;
      _tables = [];
      notifyListeners();
  }
}
