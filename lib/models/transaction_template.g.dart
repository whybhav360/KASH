// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionTemplateAdapter extends TypeAdapter<TransactionTemplate> {
  @override
  final int typeId = 4;

  @override
  TransactionTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as TransactionType,
      category: fields[4] as String,
      accountId: fields[5] as String?,
      note: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionTemplate obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.accountId)
      ..writeByte(6)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
