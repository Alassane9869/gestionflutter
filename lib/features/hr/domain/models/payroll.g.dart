// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payroll.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PayrollLineImpl _$$PayrollLineImplFromJson(Map<String, dynamic> json) =>
    _$PayrollLineImpl(
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
      isAddition: json['isAddition'] as bool? ?? true,
    );

Map<String, dynamic> _$$PayrollLineImplToJson(_$PayrollLineImpl instance) =>
    <String, dynamic>{
      'label': instance.label,
      'amount': instance.amount,
      'isAddition': instance.isAddition,
    };

_$PayrollImpl _$$PayrollImplFromJson(Map<String, dynamic> json) =>
    _$PayrollImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      baseSalary: (json['base_salary'] as num).toDouble(),
      extraLines:
          (json['extra_lines'] as List<dynamic>?)
              ?.map((e) => PayrollLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      paymentDate: json['payment_date'] == null
          ? null
          : DateTime.parse(json['payment_date'] as String),
      status:
          $enumDecodeNullable(_$PayrollStatusEnumMap, json['status']) ??
          PayrollStatus.draft,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      printed: json['printed'] as bool? ?? false,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$PayrollImplToJson(_$PayrollImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'month': instance.month,
      'year': instance.year,
      'base_salary': instance.baseSalary,
      'extra_lines': instance.extraLines,
      'payment_date': instance.paymentDate?.toIso8601String(),
      'status': _$PayrollStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt?.toIso8601String(),
      'printed': instance.printed,
      'notes': instance.notes,
    };

const _$PayrollStatusEnumMap = {
  PayrollStatus.draft: 'DRAFT',
  PayrollStatus.validated: 'VALIDATED',
  PayrollStatus.paid: 'PAID',
};
