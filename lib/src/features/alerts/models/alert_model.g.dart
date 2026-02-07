// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertModelAdapter extends TypeAdapter<AlertModel> {
  @override
  final int typeId = 6;

  @override
  AlertModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertModel(
      id: fields[0] as String,
      name: fields[1] as String,
      connectionId: fields[2] as String,
      query: fields[4] as String,
      schedule: fields[5] as AlertSchedule,
      databaseName: fields[3] as String?,
      scheduleHour: fields[6] as int?,
      scheduleMinute: fields[7] as int?,
      thresholdColumn: fields[8] as String?,
      thresholdOperator: fields[9] as ThresholdOperator?,
      thresholdValue: fields[10] as double?,
      isEnabled: fields[11] as bool,
      createdAt: fields[12] as DateTime,
      modifiedAt: fields[13] as DateTime,
      lastRunAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AlertModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.connectionId)
      ..writeByte(3)
      ..write(obj.databaseName)
      ..writeByte(4)
      ..write(obj.query)
      ..writeByte(5)
      ..write(obj.schedule)
      ..writeByte(6)
      ..write(obj.scheduleHour)
      ..writeByte(7)
      ..write(obj.scheduleMinute)
      ..writeByte(8)
      ..write(obj.thresholdColumn)
      ..writeByte(9)
      ..write(obj.thresholdOperator)
      ..writeByte(10)
      ..write(obj.thresholdValue)
      ..writeByte(11)
      ..write(obj.isEnabled)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.modifiedAt)
      ..writeByte(14)
      ..write(obj.lastRunAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AlertScheduleAdapter extends TypeAdapter<AlertSchedule> {
  @override
  final int typeId = 4;

  @override
  AlertSchedule read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AlertSchedule.hourly;
      case 1:
        return AlertSchedule.daily;
      case 2:
        return AlertSchedule.weekly;
      default:
        return AlertSchedule.hourly;
    }
  }

  @override
  void write(BinaryWriter writer, AlertSchedule obj) {
    switch (obj) {
      case AlertSchedule.hourly:
        writer.writeByte(0);
        break;
      case AlertSchedule.daily:
        writer.writeByte(1);
        break;
      case AlertSchedule.weekly:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThresholdOperatorAdapter extends TypeAdapter<ThresholdOperator> {
  @override
  final int typeId = 5;

  @override
  ThresholdOperator read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ThresholdOperator.greaterThan;
      case 1:
        return ThresholdOperator.lessThan;
      case 2:
        return ThresholdOperator.equals;
      case 3:
        return ThresholdOperator.notEquals;
      case 4:
        return ThresholdOperator.greaterOrEqual;
      case 5:
        return ThresholdOperator.lessOrEqual;
      default:
        return ThresholdOperator.greaterThan;
    }
  }

  @override
  void write(BinaryWriter writer, ThresholdOperator obj) {
    switch (obj) {
      case ThresholdOperator.greaterThan:
        writer.writeByte(0);
        break;
      case ThresholdOperator.lessThan:
        writer.writeByte(1);
        break;
      case ThresholdOperator.equals:
        writer.writeByte(2);
        break;
      case ThresholdOperator.notEquals:
        writer.writeByte(3);
        break;
      case ThresholdOperator.greaterOrEqual:
        writer.writeByte(4);
        break;
      case ThresholdOperator.lessOrEqual:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThresholdOperatorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
