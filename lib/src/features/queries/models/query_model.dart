import 'package:hive/hive.dart';

part 'query_model.g.dart';

@HiveType(typeId: 2)
class QueryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String query;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime modifiedAt;

  @HiveField(5)
  final bool isFavorite;

  @HiveField(6)
  final String connectionId;

  @HiveField(7)
  final String? databaseName;

  QueryModel({
    required this.id,
    required this.name,
    required this.query,
    required this.createdAt,
    required this.modifiedAt,
    this.isFavorite = false,
    required this.connectionId,
    this.databaseName,
  });

  QueryModel copyWith({
    String? id,
    String? name,
    String? query,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFavorite,
    String? connectionId,
    String? databaseName,
  }) {
    return QueryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      query: query ?? this.query,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      connectionId: connectionId ?? this.connectionId,
      databaseName: databaseName ?? this.databaseName,
    );
  }
}

@HiveType(typeId: 3)
class QueryHistoryEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String query;

  @HiveField(2)
  final DateTime executedAt;

  @HiveField(3)
  final int executionTimeMs;

  @HiveField(4)
  final int rowCount;

  @HiveField(5)
  final bool success;

  @HiveField(6)
  final String? errorMessage;

  @HiveField(7)
  final String connectionId;

  @HiveField(8)
  final String? databaseName;

  QueryHistoryEntry({
    required this.id,
    required this.query,
    required this.executedAt,
    required this.executionTimeMs,
    required this.rowCount,
    required this.success,
    this.errorMessage,
    required this.connectionId,
    this.databaseName,
  });
}
