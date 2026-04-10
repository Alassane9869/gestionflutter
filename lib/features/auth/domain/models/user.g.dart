// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserPermissionsImpl _$$UserPermissionsImplFromJson(
  Map<String, dynamic> json,
) => _$UserPermissionsImpl(
  canRefund: json['canRefund'] as bool? ?? false,
  canChangePrice: json['canChangePrice'] as bool? ?? false,
  canViewReports: json['canViewReports'] as bool? ?? false,
  canManageStock: json['canManageStock'] as bool? ?? false,
  canManageUsers: json['canManageUsers'] as bool? ?? false,
  canAccessSettings: json['canAccessSettings'] as bool? ?? false,
  canManageSuppliers: json['canManageSuppliers'] as bool? ?? false,
  canManageCustomers: json['canManageCustomers'] as bool? ?? false,
  canAccessFinance: json['canAccessFinance'] as bool? ?? false,
  canManageExpenses: json['canManageExpenses'] as bool? ?? false,
  canManageHR: json['canManageHR'] as bool? ?? false,
);

Map<String, dynamic> _$$UserPermissionsImplToJson(
  _$UserPermissionsImpl instance,
) => <String, dynamic>{
  'canRefund': instance.canRefund,
  'canChangePrice': instance.canChangePrice,
  'canViewReports': instance.canViewReports,
  'canManageStock': instance.canManageStock,
  'canManageUsers': instance.canManageUsers,
  'canAccessSettings': instance.canAccessSettings,
  'canManageSuppliers': instance.canManageSuppliers,
  'canManageCustomers': instance.canManageCustomers,
  'canAccessFinance': instance.canAccessFinance,
  'canManageExpenses': instance.canManageExpenses,
  'canManageHR': instance.canManageHR,
};

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: json['id'] as String,
  username: json['username'] as String,
  pinHash: json['pin_hash'] as String,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  role:
      $enumDecodeNullable(_$UserRoleEnumMap, json['role']) ?? UserRole.cashier,
  isActive: json['is_active'] as bool? ?? true,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  address: json['address'] as String?,
  birthDate: json['birth_date'] == null
      ? null
      : DateTime.parse(json['birth_date'] as String),
  hireDate: json['hire_date'] == null
      ? null
      : DateTime.parse(json['hire_date'] as String),
  nationality: json['nationality'] as String?,
  permissions: json['permissions'] == null
      ? const UserPermissions()
      : UserPermissions.fromJson(json['permissions'] as Map<String, dynamic>),
  assignedAccountIds:
      (json['assigned_account_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'pin_hash': instance.pinHash,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'role': _$UserRoleEnumMap[instance.role]!,
      'is_active': instance.isActive,
      'email': instance.email,
      'phone': instance.phone,
      'address': instance.address,
      'birth_date': instance.birthDate?.toIso8601String(),
      'hire_date': instance.hireDate?.toIso8601String(),
      'nationality': instance.nationality,
      'permissions': instance.permissions,
      'assigned_account_ids': instance.assignedAccountIds,
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'ADMIN',
  UserRole.manager: 'MANAGER',
  UserRole.cashier: 'CASHIER',
  UserRole.intern: 'INTERN',
  UserRole.accountant: 'ACCOUNTANT',
  UserRole.stockManager: 'STOCK_MANAGER',
  UserRole.sales: 'SALES',
  UserRole.auditor: 'AUDITOR',
  UserRole.inventoryAgent: 'INVENTORY_AGENT',
};
