class Client {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int totalPurchases;
  final double totalSpent;
  final double credit;
  final double maxCredit;
  final int loyaltyPoints;
  final DateTime? birthDate;
  final DateTime? lastPurchaseDate;
  final DateTime? lastMarketingReminderDate;

  const Client({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.totalPurchases = 0,
    this.totalSpent = 0.0,
    this.credit = 0.0,
    this.maxCredit = 50000.0,
    this.loyaltyPoints = 0,
    this.birthDate,
    this.lastPurchaseDate,
    this.lastMarketingReminderDate,
    this.isSynced = false,
  });

  final bool isSynced;


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'total_purchases': totalPurchases,
      'total_spent': totalSpent,
      'credit': credit,
      'max_credit': maxCredit,
      'loyalty_points': loyaltyPoints,
      'birth_date': birthDate?.toIso8601String(),
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'last_marketing_reminder_date': lastMarketingReminderDate?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      totalPurchases: (map['total_purchases'] as num? ?? 0).toInt(),
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      maxCredit: (map['max_credit'] as num?)?.toDouble() ?? 50000.0,
      loyaltyPoints: (map['loyalty_points'] as num? ?? 0).toInt(),
      birthDate: map['birth_date'] != null ? DateTime.tryParse(map['birth_date'] as String) : null,
      lastPurchaseDate: map['last_purchase_date'] != null ? DateTime.tryParse(map['last_purchase_date'] as String) : null,
      lastMarketingReminderDate: map['last_marketing_reminder_date'] != null ? DateTime.tryParse(map['last_marketing_reminder_date'] as String) : null,
      isSynced: (map['is_synced'] as num? ?? 0) == 1,
    );
  }

  Client copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    int? totalPurchases,
    double? totalSpent,
    double? credit,
    double? maxCredit,
    int? loyaltyPoints,
    DateTime? birthDate,
    DateTime? lastPurchaseDate,
    DateTime? lastMarketingReminderDate,
    bool? isSynced,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSpent: totalSpent ?? this.totalSpent,
      credit: credit ?? this.credit,
      maxCredit: maxCredit ?? this.maxCredit,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      birthDate: birthDate ?? this.birthDate,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      lastMarketingReminderDate: lastMarketingReminderDate ?? this.lastMarketingReminderDate,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
