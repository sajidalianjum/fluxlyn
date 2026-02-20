import '../../features/connections/models/connection_model.dart';

abstract class DatabaseDriver {
  Future<void> testConnection(ConnectionModel config);
  Future<void> connect(ConnectionModel config);
  Future<void> disconnect();
  Future<dynamic> execute(String sql);
  Future<List<String>> getTables();
  Future<List<String>> getDatabases();
  Future<void> useDatabase(String databaseName);
  Future<bool> isConnected();
  Future<List<ColumnInfo>> getColumns(String tableName);
  Future<String?> getPrimaryKeyColumn(String tableName);
}

class ColumnInfo {
  final String name;
  final String type;
  final bool isNullable;
  final String? defaultValue;
  final String? extra;

  ColumnInfo({
    required this.name,
    required this.type,
    this.isNullable = true,
    this.defaultValue,
    this.extra,
  });
}
