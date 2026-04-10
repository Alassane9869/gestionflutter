// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payroll.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PayrollLine _$PayrollLineFromJson(Map<String, dynamic> json) {
  return _PayrollLine.fromJson(json);
}

/// @nodoc
mixin _$PayrollLine {
  String get label => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  bool get isAddition => throw _privateConstructorUsedError;

  /// Serializes this PayrollLine to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PayrollLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayrollLineCopyWith<PayrollLine> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayrollLineCopyWith<$Res> {
  factory $PayrollLineCopyWith(
    PayrollLine value,
    $Res Function(PayrollLine) then,
  ) = _$PayrollLineCopyWithImpl<$Res, PayrollLine>;
  @useResult
  $Res call({String label, double amount, bool isAddition});
}

/// @nodoc
class _$PayrollLineCopyWithImpl<$Res, $Val extends PayrollLine>
    implements $PayrollLineCopyWith<$Res> {
  _$PayrollLineCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PayrollLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? amount = null,
    Object? isAddition = null,
  }) {
    return _then(
      _value.copyWith(
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double,
            isAddition: null == isAddition
                ? _value.isAddition
                : isAddition // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PayrollLineImplCopyWith<$Res>
    implements $PayrollLineCopyWith<$Res> {
  factory _$$PayrollLineImplCopyWith(
    _$PayrollLineImpl value,
    $Res Function(_$PayrollLineImpl) then,
  ) = __$$PayrollLineImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String label, double amount, bool isAddition});
}

/// @nodoc
class __$$PayrollLineImplCopyWithImpl<$Res>
    extends _$PayrollLineCopyWithImpl<$Res, _$PayrollLineImpl>
    implements _$$PayrollLineImplCopyWith<$Res> {
  __$$PayrollLineImplCopyWithImpl(
    _$PayrollLineImpl _value,
    $Res Function(_$PayrollLineImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayrollLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? amount = null,
    Object? isAddition = null,
  }) {
    return _then(
      _$PayrollLineImpl(
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double,
        isAddition: null == isAddition
            ? _value.isAddition
            : isAddition // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PayrollLineImpl implements _PayrollLine {
  const _$PayrollLineImpl({
    required this.label,
    required this.amount,
    this.isAddition = true,
  });

  factory _$PayrollLineImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayrollLineImplFromJson(json);

  @override
  final String label;
  @override
  final double amount;
  @override
  @JsonKey()
  final bool isAddition;

  @override
  String toString() {
    return 'PayrollLine(label: $label, amount: $amount, isAddition: $isAddition)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayrollLineImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isAddition, isAddition) ||
                other.isAddition == isAddition));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, label, amount, isAddition);

  /// Create a copy of PayrollLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayrollLineImplCopyWith<_$PayrollLineImpl> get copyWith =>
      __$$PayrollLineImplCopyWithImpl<_$PayrollLineImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayrollLineImplToJson(this);
  }
}

abstract class _PayrollLine implements PayrollLine {
  const factory _PayrollLine({
    required final String label,
    required final double amount,
    final bool isAddition,
  }) = _$PayrollLineImpl;

  factory _PayrollLine.fromJson(Map<String, dynamic> json) =
      _$PayrollLineImpl.fromJson;

  @override
  String get label;
  @override
  double get amount;
  @override
  bool get isAddition;

  /// Create a copy of PayrollLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayrollLineImplCopyWith<_$PayrollLineImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Payroll _$PayrollFromJson(Map<String, dynamic> json) {
  return _Payroll.fromJson(json);
}

/// @nodoc
mixin _$Payroll {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  int get month => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;
  @JsonKey(name: 'base_salary')
  double get baseSalary => throw _privateConstructorUsedError;
  @JsonKey(name: 'extra_lines')
  List<PayrollLine> get extraLines => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_date')
  DateTime? get paymentDate => throw _privateConstructorUsedError;
  PayrollStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  bool get printed => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this Payroll to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Payroll
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayrollCopyWith<Payroll> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayrollCopyWith<$Res> {
  factory $PayrollCopyWith(Payroll value, $Res Function(Payroll) then) =
      _$PayrollCopyWithImpl<$Res, Payroll>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    int month,
    int year,
    @JsonKey(name: 'base_salary') double baseSalary,
    @JsonKey(name: 'extra_lines') List<PayrollLine> extraLines,
    @JsonKey(name: 'payment_date') DateTime? paymentDate,
    PayrollStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    bool printed,
    String? notes,
  });
}

/// @nodoc
class _$PayrollCopyWithImpl<$Res, $Val extends Payroll>
    implements $PayrollCopyWith<$Res> {
  _$PayrollCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Payroll
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? month = null,
    Object? year = null,
    Object? baseSalary = null,
    Object? extraLines = null,
    Object? paymentDate = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? printed = null,
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
            month: null == month
                ? _value.month
                : month // ignore: cast_nullable_to_non_nullable
                      as int,
            year: null == year
                ? _value.year
                : year // ignore: cast_nullable_to_non_nullable
                      as int,
            baseSalary: null == baseSalary
                ? _value.baseSalary
                : baseSalary // ignore: cast_nullable_to_non_nullable
                      as double,
            extraLines: null == extraLines
                ? _value.extraLines
                : extraLines // ignore: cast_nullable_to_non_nullable
                      as List<PayrollLine>,
            paymentDate: freezed == paymentDate
                ? _value.paymentDate
                : paymentDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PayrollStatus,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            printed: null == printed
                ? _value.printed
                : printed // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$PayrollImplCopyWith<$Res> implements $PayrollCopyWith<$Res> {
  factory _$$PayrollImplCopyWith(
    _$PayrollImpl value,
    $Res Function(_$PayrollImpl) then,
  ) = __$$PayrollImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    int month,
    int year,
    @JsonKey(name: 'base_salary') double baseSalary,
    @JsonKey(name: 'extra_lines') List<PayrollLine> extraLines,
    @JsonKey(name: 'payment_date') DateTime? paymentDate,
    PayrollStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    bool printed,
    String? notes,
  });
}

/// @nodoc
class __$$PayrollImplCopyWithImpl<$Res>
    extends _$PayrollCopyWithImpl<$Res, _$PayrollImpl>
    implements _$$PayrollImplCopyWith<$Res> {
  __$$PayrollImplCopyWithImpl(
    _$PayrollImpl _value,
    $Res Function(_$PayrollImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Payroll
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? month = null,
    Object? year = null,
    Object? baseSalary = null,
    Object? extraLines = null,
    Object? paymentDate = freezed,
    Object? status = null,
    Object? createdAt = freezed,
    Object? printed = null,
    Object? notes = freezed,
  }) {
    return _then(
      _$PayrollImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        month: null == month
            ? _value.month
            : month // ignore: cast_nullable_to_non_nullable
                  as int,
        year: null == year
            ? _value.year
            : year // ignore: cast_nullable_to_non_nullable
                  as int,
        baseSalary: null == baseSalary
            ? _value.baseSalary
            : baseSalary // ignore: cast_nullable_to_non_nullable
                  as double,
        extraLines: null == extraLines
            ? _value._extraLines
            : extraLines // ignore: cast_nullable_to_non_nullable
                  as List<PayrollLine>,
        paymentDate: freezed == paymentDate
            ? _value.paymentDate
            : paymentDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PayrollStatus,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        printed: null == printed
            ? _value.printed
            : printed // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$PayrollImpl extends _Payroll {
  const _$PayrollImpl({
    required this.id,
    @JsonKey(name: 'user_id') required this.userId,
    required this.month,
    required this.year,
    @JsonKey(name: 'base_salary') required this.baseSalary,
    @JsonKey(name: 'extra_lines') final List<PayrollLine> extraLines = const [],
    @JsonKey(name: 'payment_date') this.paymentDate,
    this.status = PayrollStatus.draft,
    @JsonKey(name: 'created_at') this.createdAt,
    this.printed = false,
    this.notes,
  }) : _extraLines = extraLines,
       super._();

  factory _$PayrollImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayrollImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final int month;
  @override
  final int year;
  @override
  @JsonKey(name: 'base_salary')
  final double baseSalary;
  final List<PayrollLine> _extraLines;
  @override
  @JsonKey(name: 'extra_lines')
  List<PayrollLine> get extraLines {
    if (_extraLines is EqualUnmodifiableListView) return _extraLines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_extraLines);
  }

  @override
  @JsonKey(name: 'payment_date')
  final DateTime? paymentDate;
  @override
  @JsonKey()
  final PayrollStatus status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey()
  final bool printed;
  @override
  final String? notes;

  @override
  String toString() {
    return 'Payroll(id: $id, userId: $userId, month: $month, year: $year, baseSalary: $baseSalary, extraLines: $extraLines, paymentDate: $paymentDate, status: $status, createdAt: $createdAt, printed: $printed, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayrollImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.baseSalary, baseSalary) ||
                other.baseSalary == baseSalary) &&
            const DeepCollectionEquality().equals(
              other._extraLines,
              _extraLines,
            ) &&
            (identical(other.paymentDate, paymentDate) ||
                other.paymentDate == paymentDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.printed, printed) || other.printed == printed) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    month,
    year,
    baseSalary,
    const DeepCollectionEquality().hash(_extraLines),
    paymentDate,
    status,
    createdAt,
    printed,
    notes,
  );

  /// Create a copy of Payroll
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayrollImplCopyWith<_$PayrollImpl> get copyWith =>
      __$$PayrollImplCopyWithImpl<_$PayrollImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayrollImplToJson(this);
  }
}

abstract class _Payroll extends Payroll {
  const factory _Payroll({
    required final String id,
    @JsonKey(name: 'user_id') required final String userId,
    required final int month,
    required final int year,
    @JsonKey(name: 'base_salary') required final double baseSalary,
    @JsonKey(name: 'extra_lines') final List<PayrollLine> extraLines,
    @JsonKey(name: 'payment_date') final DateTime? paymentDate,
    final PayrollStatus status,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    final bool printed,
    final String? notes,
  }) = _$PayrollImpl;
  const _Payroll._() : super._();

  factory _Payroll.fromJson(Map<String, dynamic> json) = _$PayrollImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  int get month;
  @override
  int get year;
  @override
  @JsonKey(name: 'base_salary')
  double get baseSalary;
  @override
  @JsonKey(name: 'extra_lines')
  List<PayrollLine> get extraLines;
  @override
  @JsonKey(name: 'payment_date')
  DateTime? get paymentDate;
  @override
  PayrollStatus get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  bool get printed;
  @override
  String? get notes;

  /// Create a copy of Payroll
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayrollImplCopyWith<_$PayrollImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
