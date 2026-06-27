import 'package:uuid/uuid.dart';

class Supplier {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final double totalPurchases;
  final double outstandingDebt;

  Supplier({
    String? id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.totalPurchases = 0.0,
    this.outstandingDebt = 0.0,
    this.isSynced = false,
  }) : id = id ?? const Uuid().v4();

  final bool isSynced;


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'total_purchases': totalPurchases,
      'outstanding_debt': outstandingDebt,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String,
      contactName: map['contact_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      totalPurchases: (map['total_purchases'] as num?)?.toDouble() ?? 0.0,
      outstandingDebt: (map['outstanding_debt'] as num?)?.toDouble() ?? 0.0,
      isSynced: (map['is_synced'] as num? ?? 0).toInt() == 1,
    );
  }

  Supplier copyWith({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    double? totalPurchases,
    double? outstandingDebt,
    bool? isSynced,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      outstandingDebt: outstandingDebt ?? this.outstandingDebt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
