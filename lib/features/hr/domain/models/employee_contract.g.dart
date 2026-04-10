// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'employee_contract.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmployeeContractImpl _$$EmployeeContractImplFromJson(
  Map<String, dynamic> json,
) => _$EmployeeContractImpl(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  contractType: $enumDecode(_$ContractTypeEnumMap, json['contract_type']),
  startDate: DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
  baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0.0,
  transportAllowance: (json['transport_allowance'] as num?)?.toDouble() ?? 0.0,
  mealAllowance: (json['meal_allowance'] as num?)?.toDouble() ?? 0.0,
  position: json['position'] as String?,
  department: json['department'] as String?,
  schoolName: json['school_name'] as String?,
  supervisorId: json['supervisor_id'] as String?,
  status:
      $enumDecodeNullable(_$ContractStatusEnumMap, json['status']) ??
      ContractStatus.active,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$$EmployeeContractImplToJson(
  _$EmployeeContractImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'contract_type': _$ContractTypeEnumMap[instance.contractType]!,
  'start_date': instance.startDate.toIso8601String(),
  'end_date': instance.endDate?.toIso8601String(),
  'base_salary': instance.baseSalary,
  'transport_allowance': instance.transportAllowance,
  'meal_allowance': instance.mealAllowance,
  'position': instance.position,
  'department': instance.department,
  'school_name': instance.schoolName,
  'supervisor_id': instance.supervisorId,
  'status': _$ContractStatusEnumMap[instance.status]!,
  'created_at': instance.createdAt?.toIso8601String(),
  'notes': instance.notes,
};

const _$ContractTypeEnumMap = {
  ContractType.cdi: 'CDI',
  ContractType.cdd: 'CDD',
  ContractType.stage: 'STAGE',
  ContractType.essai: 'ESSAI',
  ContractType.prestataire: 'PRESTATAIRE',
};

const _$ContractStatusEnumMap = {
  ContractStatus.active: 'ACTIVE',
  ContractStatus.expired: 'EXPIRED',
  ContractStatus.terminated: 'TERMINATED',
};
