// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'leave_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LeaveRequest _$LeaveRequestFromJson(Map<String, dynamic> json) {
  return _LeaveRequest.fromJson(json);
}

/// @nodoc
mixin _$LeaveRequest {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'leave_type')
  LeaveType get leaveType => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_date')
  DateTime get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  DateTime get endDate => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  LeaveStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewed_by')
  String? get reviewedById => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewed_at')
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'reviewer_note')
  String? get reviewerNote => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this LeaveRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LeaveRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LeaveRequestCopyWith<LeaveRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LeaveRequestCopyWith<$Res> {
  factory $LeaveRequestCopyWith(
    LeaveRequest value,
    $Res Function(LeaveRequest) then,
  ) = _$LeaveRequestCopyWithImpl<$Res, LeaveRequest>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'leave_type') LeaveType leaveType,
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime endDate,
    String reason,
    LeaveStatus status,
    @JsonKey(name: 'reviewed_by') String? reviewedById,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'reviewer_note') String? reviewerNote,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$LeaveRequestCopyWithImpl<$Res, $Val extends LeaveRequest>
    implements $LeaveRequestCopyWith<$Res> {
  _$LeaveRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LeaveRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? leaveType = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? reason = null,
    Object? status = null,
    Object? reviewedById = freezed,
    Object? reviewedAt = freezed,
    Object? reviewerNote = freezed,
    Object? createdAt = freezed,
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
            leaveType: null == leaveType
                ? _value.leaveType
                : leaveType // ignore: cast_nullable_to_non_nullable
                      as LeaveType,
            startDate: null == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endDate: null == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as LeaveStatus,
            reviewedById: freezed == reviewedById
                ? _value.reviewedById
                : reviewedById // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reviewerNote: freezed == reviewerNote
                ? _value.reviewerNote
                : reviewerNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LeaveRequestImplCopyWith<$Res>
    implements $LeaveRequestCopyWith<$Res> {
  factory _$$LeaveRequestImplCopyWith(
    _$LeaveRequestImpl value,
    $Res Function(_$LeaveRequestImpl) then,
  ) = __$$LeaveRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'leave_type') LeaveType leaveType,
    @JsonKey(name: 'start_date') DateTime startDate,
    @JsonKey(name: 'end_date') DateTime endDate,
    String reason,
    LeaveStatus status,
    @JsonKey(name: 'reviewed_by') String? reviewedById,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'reviewer_note') String? reviewerNote,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$LeaveRequestImplCopyWithImpl<$Res>
    extends _$LeaveRequestCopyWithImpl<$Res, _$LeaveRequestImpl>
    implements _$$LeaveRequestImplCopyWith<$Res> {
  __$$LeaveRequestImplCopyWithImpl(
    _$LeaveRequestImpl _value,
    $Res Function(_$LeaveRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LeaveRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? leaveType = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? reason = null,
    Object? status = null,
    Object? reviewedById = freezed,
    Object? reviewedAt = freezed,
    Object? reviewerNote = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$LeaveRequestImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        leaveType: null == leaveType
            ? _value.leaveType
            : leaveType // ignore: cast_nullable_to_non_nullable
                  as LeaveType,
        startDate: null == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endDate: null == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as LeaveStatus,
        reviewedById: freezed == reviewedById
            ? _value.reviewedById
            : reviewedById // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewerNote: freezed == reviewerNote
            ? _value.reviewerNote
            : reviewerNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LeaveRequestImpl extends _LeaveRequest {
  const _$LeaveRequestImpl({
    required this.id,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'leave_type') required this.leaveType,
    @JsonKey(name: 'start_date') required this.startDate,
    @JsonKey(name: 'end_date') required this.endDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    @JsonKey(name: 'reviewed_by') this.reviewedById,
    @JsonKey(name: 'reviewed_at') this.reviewedAt,
    @JsonKey(name: 'reviewer_note') this.reviewerNote,
    @JsonKey(name: 'created_at') this.createdAt,
  }) : super._();

  factory _$LeaveRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$LeaveRequestImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'leave_type')
  final LeaveType leaveType;
  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime endDate;
  @override
  final String reason;
  @override
  @JsonKey()
  final LeaveStatus status;
  @override
  @JsonKey(name: 'reviewed_by')
  final String? reviewedById;
  @override
  @JsonKey(name: 'reviewed_at')
  final DateTime? reviewedAt;
  @override
  @JsonKey(name: 'reviewer_note')
  final String? reviewerNote;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'LeaveRequest(id: $id, userId: $userId, leaveType: $leaveType, startDate: $startDate, endDate: $endDate, reason: $reason, status: $status, reviewedById: $reviewedById, reviewedAt: $reviewedAt, reviewerNote: $reviewerNote, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LeaveRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.leaveType, leaveType) ||
                other.leaveType == leaveType) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.reviewedById, reviewedById) ||
                other.reviewedById == reviewedById) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reviewerNote, reviewerNote) ||
                other.reviewerNote == reviewerNote) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    leaveType,
    startDate,
    endDate,
    reason,
    status,
    reviewedById,
    reviewedAt,
    reviewerNote,
    createdAt,
  );

  /// Create a copy of LeaveRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LeaveRequestImplCopyWith<_$LeaveRequestImpl> get copyWith =>
      __$$LeaveRequestImplCopyWithImpl<_$LeaveRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LeaveRequestImplToJson(this);
  }
}

abstract class _LeaveRequest extends LeaveRequest {
  const factory _LeaveRequest({
    required final String id,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'leave_type') required final LeaveType leaveType,
    @JsonKey(name: 'start_date') required final DateTime startDate,
    @JsonKey(name: 'end_date') required final DateTime endDate,
    required final String reason,
    final LeaveStatus status,
    @JsonKey(name: 'reviewed_by') final String? reviewedById,
    @JsonKey(name: 'reviewed_at') final DateTime? reviewedAt,
    @JsonKey(name: 'reviewer_note') final String? reviewerNote,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$LeaveRequestImpl;
  const _LeaveRequest._() : super._();

  factory _LeaveRequest.fromJson(Map<String, dynamic> json) =
      _$LeaveRequestImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'leave_type')
  LeaveType get leaveType;
  @override
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @override
  @JsonKey(name: 'end_date')
  DateTime get endDate;
  @override
  String get reason;
  @override
  LeaveStatus get status;
  @override
  @JsonKey(name: 'reviewed_by')
  String? get reviewedById;
  @override
  @JsonKey(name: 'reviewed_at')
  DateTime? get reviewedAt;
  @override
  @JsonKey(name: 'reviewer_note')
  String? get reviewerNote;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of LeaveRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LeaveRequestImplCopyWith<_$LeaveRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
