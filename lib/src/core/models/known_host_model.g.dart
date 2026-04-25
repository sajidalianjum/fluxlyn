// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'known_host_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KnownHostModelAdapter extends TypeAdapter<KnownHostModel> {
  @override
  final int typeId = 5;

  @override
  KnownHostModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KnownHostModel(
      host: fields[0] as String,
      port: fields[1] as int,
      keyType: fields[2] as String,
      fingerprint: fields[3] as String,
      encodedKey: fields[4] as String,
      addedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, KnownHostModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.host)
      ..writeByte(1)
      ..write(obj.port)
      ..writeByte(2)
      ..write(obj.keyType)
      ..writeByte(3)
      ..write(obj.fingerprint)
      ..writeByte(4)
      ..write(obj.encodedKey)
      ..writeByte(5)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnownHostModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
