// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leave_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LeaveRequestImpl _$$LeaveRequestImplFromJson(Map<String, dynamic> json) =>
    _$LeaveRequestImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      leaveType: $enumDecode(_$LeaveTypeEnumMap, json['leave_type']),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      reason: json['reason'] as String,
      status:
          $enumDecodeNullable(_$LeaveStatusEnumMap, json['status']) ??
          LeaveStatus.pending,
      reviewedById: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      reviewerNote: json['reviewer_note'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$LeaveRequestImplToJson(_$LeaveRequestImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'leave_type': _$LeaveTypeEnumMap[instance.leaveType]!,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate.toIso8601String(),
      'reason': instance.reason,
      'status': _$LeaveStatusEnumMap[instance.status]!,
      'reviewed_by': instance.reviewedById,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
      'reviewer_note': instance.reviewerNote,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$LeaveTypeEnumMap = {
  LeaveType.annual: 'ANNUAL',
  LeaveType.sick: 'SICK',
  LeaveType.permission: 'PERMISSION',
  LeaveType.unpaid: 'UNPAID',
  LeaveType.other: 'OTHER',
};

const _$LeaveStatusEnumMap = {
  LeaveStatus.pending: 'PENDING',
  LeaveStatus.approved: 'APPROVED',
  LeaveStatus.rejected: 'REJECTED',
};
