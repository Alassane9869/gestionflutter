import 'package:freezed_annotation/freezed_annotation.dart';

part 'leave_request.freezed.dart';
part 'leave_request.g.dart';

enum LeaveType {
  @JsonValue('ANNUAL')
  annual,
  @JsonValue('SICK')
  sick,
  @JsonValue('PERMISSION')
  permission,
  @JsonValue('UNPAID')
  unpaid,
  @JsonValue('OTHER')
  other,
}

enum LeaveStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('REJECTED')
  rejected,
}

@freezed
class LeaveRequest with _$LeaveRequest {
  const LeaveRequest._();

  const factory LeaveRequest({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'leave_type') required LeaveType leaveType,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
    required String reason,
    @Default(LeaveStatus.pending) LeaveStatus status,
    @JsonKey(name: 'reviewed_by') String? reviewedById,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'reviewer_note') String? reviewerNote,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _LeaveRequest;

  int get durationInDays => endDate.difference(startDate).inDays + 1;

  String get leaveTypeLabel {
    switch (leaveType) {
      case LeaveType.annual: return 'Congé Annuel';
      case LeaveType.sick: return 'Congé Maladie';
      case LeaveType.permission: return 'Permission';
      case LeaveType.unpaid: return 'Congé Sans Solde';
      case LeaveType.other: return 'Autre';
    }
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => _$LeaveRequestFromJson(json);
}
