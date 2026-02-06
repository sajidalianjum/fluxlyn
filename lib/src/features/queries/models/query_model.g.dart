// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QueryModelAdapter extends TypeAdapter<QueryModel> {
  @override
  final int typeId = 2;

  @override
  QueryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      query: fields[2] as String,
      createdAt: fields[3] as DateTime,
      modifiedAt: fields[4] as DateTime,
      isFavorite: fields[5] as bool,
      connectionId: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, QueryModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.query)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.modifiedAt)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.connectionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QueryHistoryEntryAdapter extends TypeAdapter<QueryHistoryEntry> {
  @override
  final int typeId = 3;

  @override
  QueryHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueryHistoryEntry(
      id: fields[0] as String,
      query: fields[1] as String,
      executedAt: fields[2] as DateTime,
      executionTimeMs: fields[3] as int,
      rowCount: fields[4] as int,
      success: fields[5] as bool,
      errorMessage: fields[6] as String?,
      connectionId: fields[7] as String,
      databaseName: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QueryHistoryEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.query)
      ..writeByte(2)
      ..write(obj.executedAt)
      ..writeByte(3)
      ..write(obj.executionTimeMs)
      ..writeByte(4)
      ..write(obj.rowCount)
      ..writeByte(5)
      ..write(obj.success)
      ..writeByte(6)
      ..write(obj.errorMessage)
      ..writeByte(7)
      ..write(obj.connectionId)
      ..writeByte(8)
      ..write(obj.databaseName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
