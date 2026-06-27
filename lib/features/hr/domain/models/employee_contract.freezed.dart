// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'employee_contract.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EmployeeContract _$EmployeeContractFromJson(Map<String, dynamic> json) {
  return _EmployeeContract.fromJson(json);
}

/// @nodoc
mixin _$EmployeeContract {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'contract_type')
  ContractType get contractType => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_date')
  DateTime get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  DateTime? get endDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'base_salary')
  double get baseSalary => throw _privateConstructorUsedError;
  @JsonKey(name: 'transport_allowance')
  double get transportAllowance => throw _privateConstructorUsedError;
  @JsonKey(name: 'meal_allowance')
  double get mealAllowance => throw _privateConstructorUsedError;
  String? get position => throw _privateConstructorUsedError;
  @JsonKey(name: 'department')
  String? get department => throw _privateConstructorUsedError;
  @JsonKey(name: 'school_name')
  String? get schoolName => throw _privateConstructorUsedError; // for stages
  @JsonKey(name: 'supervisor_id')
  String? get supervisorId => throw _privateConstructorUsedError;
  ContractStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this EmployeeContract to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EmployeeContract
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EmployeeContractCopyWith<EmployeeContract> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmployeeContractCopyWith<$Res> {
  factory $EmployeeContractCopyWith(
    EmployeeContract value,
    $Res Function(EmployeeContract) then,
  ) = _$EmployeeContractCopyWithImpl<$Res, EmployeeContract>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'contract_type') ContractType contractType,
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @JsonKey(name: 'base_salary') double baseSalary,
    @JsonKey(name: 'transport_allowance') double transportAllowance,
    @JsonKey(name: 'meal_allowance') double mealAllowance,
    String? position,
    @JsonKey(name: 'department') String? department,
    @JsonKey(name: 'school_name') String? schoolName,
    @JsonKey(name: 'supervisor_id') String? supervisorId,
    ContractStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String? notes,
  });
}

/// @nodoc
class _$EmployeeContractCopyWithImpl<$Res, $Val extends EmployeeContract>
    implements $EmployeeContractCopyWith<$Res> {
  _$EmployeeContractCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EmployeeContract
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? contractType = null,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? baseSalary = null,
    Object? transportAllowance = null,
    Object? mealAllowance = null,
    Object? position = freezed,
    Object? department = freezed,
    Object? schoolName = freezed,
    Object? supervisorId = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            contractType: null == contractType
                ? _value.contractType
                : contractType // ignore: cast_nullable_to_non_nullable
                      as ContractType,
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            baseSalary: null == baseSalary
                ? _value.baseSalary
                : baseSalary // ignore: cast_nullable_to_non_nullable
                      as double,
            transportAllowance: null == transportAllowance
                ? _value.transportAllowance
                : transportAllowance // ignore: cast_nullable_to_non_nullable
                      as double,
            mealAllowance: null == mealAllowance
                ? _value.mealAllowance
                : mealAllowance // ignore: cast_nullable_to_non_nullable
                      as double,
            position: freezed == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as String?,
            department: freezed == department
                ? _value.department
                : department // ignore: cast_nullable_to_non_nullable
                      as String?,
            schoolName: freezed == schoolName
                ? _value.schoolName
                : schoolName // ignore: cast_nullable_to_non_nullable
                      as String?,
            supervisorId: freezed == supervisorId
                ? _value.supervisorId
                : supervisorId // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ContractStatus,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EmployeeContractImplCopyWith<$Res>
    implements $EmployeeContractCopyWith<$Res> {
  factory _$$EmployeeContractImplCopyWith(
    _$EmployeeContractImpl value,
    $Res Function(_$EmployeeContractImpl) then,
  ) = __$$EmployeeContractImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'contract_type') ContractType contractType,
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @JsonKey(name: 'base_salary') double baseSalary,
    @JsonKey(name: 'transport_allowance') double transportAllowance,
    @JsonKey(name: 'meal_allowance') double mealAllowance,
    String? position,
    @JsonKey(name: 'department') String? department,
    @JsonKey(name: 'school_name') String? schoolName,
    @JsonKey(name: 'supervisor_id') String? supervisorId,
    ContractStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    String? notes,
  });
}

/// @nodoc
class __$$EmployeeContractImplCopyWithImpl<$Res>
    extends _$EmployeeContractCopyWithImpl<$Res, _$EmployeeContractImpl>
    implements _$$EmployeeContractImplCopyWith<$Res> {
  __$$EmployeeContractImplCopyWithImpl(
    _$EmployeeContractImpl _value,
    $Res Function(_$EmployeeContractImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EmployeeContract
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? contractType = null,
    Object? startDate = null,
    Object? endDate = freezed,
    Object? baseSalary = null,
    Object? transportAllowance = null,
    Object? mealAllowance = null,
    Object? position = freezed,
    Object? department = freezed,
    Object? schoolName = freezed,
    Object? supervisorId = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? notes = freezed,
  }) {
    return _then(
      _$EmployeeContractImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        contractType: null == contractType
            ? _value.contractType
            : contractType // ignore: cast_nullable_to_non_nullable
                  as ContractType,
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        baseSalary: null == baseSalary
            ? _value.baseSalary
            : baseSalary // ignore: cast_nullable_to_non_nullable
                  as double,
        transportAllowance: null == transportAllowance
            ? _value.transportAllowance
            : transportAllowance // ignore: cast_nullable_to_non_nullable
                  as double,
        mealAllowance: null == mealAllowance
            ? _value.mealAllowance
            : mealAllowance // ignore: cast_nullable_to_non_nullable
                  as double,
        position: freezed == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as String?,
        department: freezed == department
            ? _value.department
            : department // ignore: cast_nullable_to_non_nullable
                  as String?,
        schoolName: freezed == schoolName
            ? _value.schoolName
            : schoolName // ignore: cast_nullable_to_non_nullable
                  as String?,
        supervisorId: freezed == supervisorId
            ? _value.supervisorId
            : supervisorId // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ContractStatus,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EmployeeContractImpl extends _EmployeeContract {
  const _$EmployeeContractImpl({
    required this.id,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'contract_type') required this.contractType,
    @JsonKey(name: 'start_date') required this.startDate,
    @JsonKey(name: 'end_date') this.endDate,
    @JsonKey(name: 'base_salary') this.baseSalary = 0.0,
    @JsonKey(name: 'transport_allowance') this.transportAllowance = 0.0,
    @JsonKey(name: 'meal_allowance') this.mealAllowance = 0.0,
    this.position,
    @JsonKey(name: 'department') this.department,
    @JsonKey(name: 'school_name') this.schoolName,
    @JsonKey(name: 'supervisor_id') this.supervisorId,
    this.status = ContractStatus.active,
    @JsonKey(name: 'created_at') this.createdAt,
    this.notes,
  }) : super._();

  factory _$EmployeeContractImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmployeeContractImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'contract_type')
  final ContractType contractType;
  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  @override
  @JsonKey(name: 'base_salary')
  final double baseSalary;
  @override
  @JsonKey(name: 'transport_allowance')
  final double transportAllowance;
  @override
  @JsonKey(name: 'meal_allowance')
  final double mealAllowance;
  @override
  final String? position;
  @override
  @JsonKey(name: 'department')
  final String? department;
  @override
  @JsonKey(name: 'school_name')
  final String? schoolName;
  // for stages
  @override
  @JsonKey(name: 'supervisor_id')
  final String? supervisorId;
  @override
  @JsonKey()
  final ContractStatus status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  final String? notes;

  @override
  String toString() {
    return 'EmployeeContract(id: $id, userId: $userId, contractType: $contractType, startDate: $startDate, endDate: $endDate, baseSalary: $baseSalary, transportAllowance: $transportAllowance, mealAllowance: $mealAllowance, position: $position, department: $department, schoolName: $schoolName, supervisorId: $supervisorId, status: $status, createdAt: $createdAt, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmployeeContractImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.contractType, contractType) ||
                other.contractType == contractType) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.baseSalary, baseSalary) ||
                other.baseSalary == baseSalary) &&
            (identical(other.transportAllowance, transportAllowance) ||
                other.transportAllowance == transportAllowance) &&
            (identical(other.mealAllowance, mealAllowance) ||
                other.mealAllowance == mealAllowance) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.schoolName, schoolName) ||
                other.schoolName == schoolName) &&
            (identical(other.supervisorId, supervisorId) ||
                other.supervisorId == supervisorId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    contractType,
    startDate,
    endDate,
    baseSalary,
    transportAllowance,
    mealAllowance,
    position,
    department,
    schoolName,
    supervisorId,
    status,
    createdAt,
    notes,
  );

  /// Create a copy of EmployeeContract
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EmployeeContractImplCopyWith<_$EmployeeContractImpl> get copyWith =>
      __$$EmployeeContractImplCopyWithImpl<_$EmployeeContractImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EmployeeContractImplToJson(this);
  }
}

abstract class _EmployeeContract extends EmployeeContract {
  const factory _EmployeeContract({
    required final String id,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'contract_type') required final ContractType contractType,
    @JsonKey(name: 'start_date') required final DateTime startDate,
    @JsonKey(name: 'end_date') final DateTime? endDate,
    @JsonKey(name: 'base_salary') final double baseSalary,
    @JsonKey(name: 'transport_allowance') final double transportAllowance,
    @JsonKey(name: 'meal_allowance') final double mealAllowance,
    final String? position,
    @JsonKey(name: 'department') final String? department,
    @JsonKey(name: 'school_name') final String? schoolName,
    @JsonKey(name: 'supervisor_id') final String? supervisorId,
    final ContractStatus status,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    final String? notes,
  }) = _$EmployeeContractImpl;
  const _EmployeeContract._() : super._();

  factory _EmployeeContract.fromJson(Map<String, dynamic> json) =
      _$EmployeeContractImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'contract_type')
  ContractType get contractType;
  @override
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @override
  @JsonKey(name: 'end_date')
  DateTime? get endDate;
  @override
  @JsonKey(name: 'base_salary')
  double get baseSalary;
  @override
  @JsonKey(name: 'transport_allowance')
  double get transportAllowance;
  @override
  @JsonKey(name: 'meal_allowance')
  double get mealAllowance;
  @override
  String? get position;
  @override
  @JsonKey(name: 'department')
  String? get department;
  @override
  @JsonKey(name: 'school_name')
  String? get schoolName; // for stages
  @override
  @JsonKey(name: 'supervisor_id')
  String? get supervisorId;
  @override
  ContractStatus get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  String? get notes;

  /// Create a copy of EmployeeContract
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EmployeeContractImplCopyWith<_$EmployeeContractImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
