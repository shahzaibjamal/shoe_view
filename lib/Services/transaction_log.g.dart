// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionLogAdapter extends TypeAdapter<TransactionLog> {
  @override
  final int typeId = 0;

  @override
  TransactionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionLog(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      action: fields[2] as String,
      entityId: fields[3] as String,
      entityName: fields[4] as String,
      summary: fields[5] as String,
      metadata: (fields[6] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, TransactionLog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.entityId)
      ..writeByte(4)
      ..write(obj.entityName)
      ..writeByte(5)
      ..write(obj.summary)
      ..writeByte(6)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
