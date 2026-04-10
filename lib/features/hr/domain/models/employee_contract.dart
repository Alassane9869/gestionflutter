import 'package:freezed_annotation/freezed_annotation.dart';

part 'employee_contract.freezed.dart';
part 'employee_contract.g.dart';

enum ContractType {
  @JsonValue('CDI')
  cdi,
  @JsonValue('CDD')
  cdd,
  @JsonValue('STAGE')
  stage,
  @JsonValue('ESSAI')
  essai,
  @JsonValue('PRESTATAIRE')
  prestataire,
}

enum ContractStatus {
  @JsonValue('ACTIVE')
  active,
  @JsonValue('EXPIRED')
  expired,
  @JsonValue('TERMINATED')
  terminated,
}

@freezed
class EmployeeContract with _$EmployeeContract {
  const EmployeeContract._();

  const factory EmployeeContract({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'contract_type') required ContractType contractType,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @JsonKey(name: 'base_salary') @Default(0.0) double baseSalary,
    @JsonKey(name: 'transport_allowance') @Default(0.0) double transportAllowance,
    @JsonKey(name: 'meal_allowance') @Default(0.0) double mealAllowance,
    String? position,
    @JsonKey(name: 'department') String? department,
    @JsonKey(name: 'school_name') String? schoolName, // for stages
    @JsonKey(name: 'supervisor_id') String? supervisorId,
    @Default(ContractStatus.active) ContractStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String? notes,
  }) = _EmployeeContract;

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  bool get isExpiringSoon {
    if (endDate == null) return false;
    final daysLeft = endDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }

  int? get daysUntilExpiry {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }

  String get contractTypeLabel {
    switch (contractType) {
      case ContractType.cdi: return 'Contrat à Durée Indéterminée (CDI)';
      case ContractType.cdd: return 'Contrat à Durée Déterminée (CDD)';
      case ContractType.stage: return 'Stage';
      case ContractType.essai: return "Période d'Essai";
      case ContractType.prestataire: return 'Prestataire';
    }
  }

  factory EmployeeContract.fromJson(Map<String, dynamic> json) => _$EmployeeContractFromJson(json);
}
