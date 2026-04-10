class LoyaltySettings {
  final String id;
  final double pointsPerAmount; // Points gained per unit of currency (ex: 1 point per 1000)
  final double amountPerPoint; // Currency reduction per point (ex: 1 point = 10)
  final bool isEnabled;

  LoyaltySettings({
    required this.id,
    required this.pointsPerAmount,
    required this.amountPerPoint,
    required this.isEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'points_per_amount': pointsPerAmount,
      'amount_per_point': amountPerPoint,
      'is_enabled': isEnabled ? 1 : 0,
    };
  }

  factory LoyaltySettings.fromMap(Map<String, dynamic> map) {
    return LoyaltySettings(
      id: map['id'] as String,
      pointsPerAmount: (map['points_per_amount'] as num).toDouble(),
      amountPerPoint: (map['amount_per_point'] as num).toDouble(),
      isEnabled: (map['is_enabled'] as int) == 1,
    );
  }

  LoyaltySettings copyWith({
    double? pointsPerAmount,
    double? amountPerPoint,
    bool? isEnabled,
  }) {
    return LoyaltySettings(
      id: id,
      pointsPerAmount: pointsPerAmount ?? this.pointsPerAmount,
      amountPerPoint: amountPerPoint ?? this.amountPerPoint,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
