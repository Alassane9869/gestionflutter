import 'package:uuid/uuid.dart';

// ignore: constant_identifier_names
enum SessionStatus { OPEN, CLOSED }

class CashSession {
  final String id;
  final String userId;
  final DateTime openDate;
  final DateTime? closeDate;
  final double openingBalance;
  final double? closingBalanceActual;
  final double? closingBalanceTheoretical;
  final double? difference;
  final SessionStatus status;

  CashSession({
    String? id,
    required this.userId,
    DateTime? openDate,
    this.closeDate,
    required this.openingBalance,
    this.closingBalanceActual,
    this.closingBalanceTheoretical,
    this.difference,
    this.status = SessionStatus.OPEN,
  })  : id = id ?? const Uuid().v4(),
        openDate = openDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'open_date': openDate.toIso8601String(),
      'close_date': closeDate?.toIso8601String(),
      'opening_balance': openingBalance,
      'closing_balance_actual': closingBalanceActual,
      'closing_balance_theoretical': closingBalanceTheoretical,
      'difference': difference,
      'status': status.name,
    };
  }

  factory CashSession.fromMap(Map<String, dynamic> map) {
    return CashSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      openDate: DateTime.parse(map['open_date'] as String),
      closeDate: map['close_date'] != null ? DateTime.parse(map['close_date'] as String) : null,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      closingBalanceActual: (map['closing_balance_actual'] as num?)?.toDouble(),
      closingBalanceTheoretical: (map['closing_balance_theoretical'] as num?)?.toDouble(),
      difference: (map['difference'] as num?)?.toDouble(),
      status: SessionStatus.values.firstWhere((e) => e.name == map['status']),
    );
  }
}
