// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_history_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertHistoryEntryAdapter extends TypeAdapter<AlertHistoryEntry> {
  @override
  final int typeId = 7;

  @override
  AlertHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertHistoryEntry(
      id: fields[0] as String,
      alertId: fields[1] as String,
      executedAt: fields[2] as DateTime,
      executionTimeMs: fields[3] as int,
      success: fields[4] as bool,
      errorMessage: fields[5] as String?,
      rowCount: fields[6] as int?,
      thresholdTriggered: fields[7] as bool,
      thresholdValue: fields[8] as double?,
      connectionId: fields[9] as String?,
      databaseName: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AlertHistoryEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.alertId)
      ..writeByte(2)
      ..write(obj.executedAt)
      ..writeByte(3)
      ..write(obj.executionTimeMs)
      ..writeByte(4)
      ..write(obj.success)
      ..writeByte(5)
      ..write(obj.errorMessage)
      ..writeByte(6)
      ..write(obj.rowCount)
      ..writeByte(7)
      ..write(obj.thresholdTriggered)
      ..writeByte(8)
      ..write(obj.thresholdValue)
      ..writeByte(9)
      ..write(obj.connectionId)
      ..writeByte(10)
      ..write(obj.databaseName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
