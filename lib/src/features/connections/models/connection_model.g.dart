// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConnectionModelAdapter extends TypeAdapter<ConnectionModel> {
  @override
  final int typeId = 0;

  @override
  ConnectionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConnectionModel(
      id: fields[0] as String?,
      name: fields[1] as String,
      host: fields[2] as String,
      port: fields[3] as int,
      username: fields[4] as String?,
      password: fields[5] as String?,
      type: fields[6] as ConnectionType,
      sslEnabled: fields[7] as bool,
      isConnected: fields[8] as bool,
      useSsh: fields[9] as bool,
      sshHost: fields[10] as String?,
      sshPort: fields[11] as int?,
      sshUsername: fields[12] as String?,
      sshPassword: fields[13] as String?,
      sshPrivateKey: fields[14] as String?,
      sshKeyPassword: fields[15] as String?,
      databaseName: fields[16] as String?,
      customTag: fields[17] as String?,
      tag: fields[18] as ConnectionTag?,
    );
  }

  @override
  void write(BinaryWriter writer, ConnectionModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.host)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.sslEnabled)
      ..writeByte(8)
      ..write(obj.isConnected)
      ..writeByte(9)
      ..write(obj.useSsh)
      ..writeByte(10)
      ..write(obj.sshHost)
      ..writeByte(11)
      ..write(obj.sshPort)
      ..writeByte(12)
      ..write(obj.sshUsername)
      ..writeByte(13)
      ..write(obj.sshPassword)
      ..writeByte(14)
      ..write(obj.sshPrivateKey)
      ..writeByte(15)
      ..write(obj.sshKeyPassword)
      ..writeByte(16)
      ..write(obj.databaseName)
      ..writeByte(17)
      ..write(obj.customTag)
      ..writeByte(18)
      ..write(obj.tag);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConnectionTagAdapter extends TypeAdapter<ConnectionTag> {
  @override
  final int typeId = 4;

  @override
  ConnectionTag read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConnectionTag.none;
      case 1:
        return ConnectionTag.development;
      case 2:
        return ConnectionTag.production;
      case 3:
        return ConnectionTag.testing;
      case 4:
        return ConnectionTag.staging;
      case 5:
        return ConnectionTag.local;
      case 6:
        return ConnectionTag.custom;
      default:
        return ConnectionTag.none;
    }
  }

  @override
  void write(BinaryWriter writer, ConnectionTag obj) {
    switch (obj) {
      case ConnectionTag.none:
        writer.writeByte(0);
        break;
      case ConnectionTag.development:
        writer.writeByte(1);
        break;
      case ConnectionTag.production:
        writer.writeByte(2);
        break;
      case ConnectionTag.testing:
        writer.writeByte(3);
        break;
      case ConnectionTag.staging:
        writer.writeByte(4);
        break;
      case ConnectionTag.local:
        writer.writeByte(5);
        break;
      case ConnectionTag.custom:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionTagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConnectionTypeAdapter extends TypeAdapter<ConnectionType> {
  @override
  final int typeId = 1;

  @override
  ConnectionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ConnectionType.mysql;
      case 1:
        return ConnectionType.postgresql;
      default:
        return ConnectionType.mysql;
    }
  }

  @override
  void write(BinaryWriter writer, ConnectionType obj) {
    switch (obj) {
      case ConnectionType.mysql:
        writer.writeByte(0);
        break;
      case ConnectionType.postgresql:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
