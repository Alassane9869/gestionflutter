import 'package:freezed_annotation/freezed_annotation.dart';

part 'payroll.freezed.dart';
part 'payroll.g.dart';

enum PayrollStatus {
  @JsonValue('DRAFT')
  draft,
  @JsonValue('VALIDATED')
  validated,
  @JsonValue('PAID')
  paid,
}

@freezed
class PayrollLine with _$PayrollLine {
  const factory PayrollLine({
    required String label,
    required double amount,
    @Default(true) bool isAddition, // true = prime, false = retenue
  }) = _PayrollLine;

  factory PayrollLine.fromJson(Map<String, dynamic> json) => _$PayrollLineFromJson(json);
}

@freezed
class Payroll with _$Payroll {
  const Payroll._();

  const factory Payroll({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required int month,
    required int year,
    @JsonKey(name: 'base_salary') required double baseSalary,
    @JsonKey(name: 'extra_lines') @Default([]) List<PayrollLine> extraLines,
    @JsonKey(name: 'payment_date') DateTime? paymentDate,
    @Default(PayrollStatus.draft) PayrollStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @Default(false) bool printed,
    String? notes,
  }) = _Payroll;

  double get totalAdditions => extraLines
      .where((l) => l.isAddition)
      .fold(0, (sum, l) => sum + l.amount);

  double get totalDeductions => extraLines
      .where((l) => !l.isAddition)
      .fold(0, (sum, l) => sum + l.amount);

  double get netSalary => baseSalary + totalAdditions - totalDeductions;

  String get periodLabel {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${months[month - 1]} $year';
  }

  factory Payroll.fromJson(Map<String, dynamic> json) => _$PayrollFromJson(json);
}
