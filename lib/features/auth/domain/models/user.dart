import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

enum UserRole {
  @JsonValue('ADMIN')
  admin,
  @JsonValue('MANAGER')
  manager,
  @JsonValue('CASHIER')
  cashier,
  @JsonValue('INTERN')
  intern,
  @JsonValue('ACCOUNTANT')
  accountant,
  @JsonValue('STOCK_MANAGER')
  stockManager,
  @JsonValue('SALES')
  sales,
  @JsonValue('AUDITOR')
  auditor,
  @JsonValue('INVENTORY_AGENT')
  inventoryAgent,
  @JsonValue('ADMIN_PLUS') // Potentiel futur pour super-admin
  adminPlus,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin: return 'Administrateur';
      case UserRole.manager: return 'Gérant';
      case UserRole.cashier: return 'Caissier';
      case UserRole.intern: return 'Stagiaire';
      case UserRole.accountant: return 'Comptable';
      case UserRole.stockManager: return 'Gestionnaire de Stock';
      case UserRole.sales: return 'Commercial / Vendeur';
      case UserRole.auditor: return 'Auditeur';
      case UserRole.inventoryAgent: return 'Agent d\'inventaire';
      case UserRole.adminPlus: return 'Super Administrateur';
    }
  }

  // Helper for UI tags
  bool get isSimpleRole => this == UserRole.cashier || this == UserRole.intern || this == UserRole.sales;
}

@freezed
class UserPermissions with _$UserPermissions {
  const factory UserPermissions({
    @Default(false) bool canRefund,
    @Default(false) bool canChangePrice,
    @Default(false) bool canViewReports,
    @Default(false) bool canManageStock,
    @Default(false) bool canManageUsers,
    @Default(false) bool canAccessSettings,
    @Default(false) bool canManageSuppliers,
    @Default(false) bool canManageCustomers,
    @Default(false) bool canAccessFinance,
    @Default(false) bool canManageExpenses,
    @Default(false) bool canManageHR,
  }) = _UserPermissions;

  factory UserPermissions.fromJson(Map<String, dynamic> json) => _$UserPermissionsFromJson(json);

  factory UserPermissions.admin() => const UserPermissions(
        canRefund: true,
        canChangePrice: true,
        canViewReports: true,
        canManageStock: true,
        canManageUsers: true,
        canAccessSettings: true,
        canManageSuppliers: true,
        canManageCustomers: true,
        canAccessFinance: true,
        canManageExpenses: true,
        canManageHR: true,
      );

  factory UserPermissions.manager() => const UserPermissions(
        canRefund: true,
        canChangePrice: true,
        canViewReports: true,
        canManageStock: true,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: true,
        canManageCustomers: true,
        canAccessFinance: false,
        canManageExpenses: true,
        canManageHR: false,
      );

  factory UserPermissions.cashier() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: false,
        canManageStock: false,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: false,
        canManageCustomers: true,
        canAccessFinance: false,
        canManageExpenses: false,
        canManageHR: false,
      );

  factory UserPermissions.intern() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: false,
        canManageStock: false,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: false,
        canManageCustomers: true,
        canAccessFinance: false,
        canManageExpenses: false,
        canManageHR: false,
      );

  factory UserPermissions.accountant() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: true,
        canManageStock: false,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: true,
        canManageCustomers: true,
        canAccessFinance: true,
        canManageExpenses: true,
        canManageHR: true,
      );

  factory UserPermissions.stockManager() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: true,
        canManageStock: true,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: true,
        canManageCustomers: false,
        canAccessFinance: false,
        canManageExpenses: false,
        canManageHR: false,
      );

  factory UserPermissions.sales() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: false,
        canManageStock: false,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: false,
        canManageCustomers: true,
        canAccessFinance: false,
        canManageExpenses: false,
        canManageHR: false,
      );

  factory UserPermissions.auditor() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: true,
        canManageStock: false, // Audit of stock reports, not necessarily physical counting
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: false,
        canManageCustomers: false,
        canAccessFinance: true,
        canManageExpenses: true,
        canManageHR: false,
      );

  factory UserPermissions.inventoryAgent() => const UserPermissions(
        canRefund: false,
        canChangePrice: false,
        canViewReports: false,
        canManageStock: true,
        canManageUsers: false,
        canAccessSettings: false,
        canManageSuppliers: false,
        canManageCustomers: false,
        canAccessFinance: false,
        canManageExpenses: false,
        canManageHR: false,
      );
}

@freezed
class User with _$User {
  const User._();

  const factory User({
    required String id,
    required String username,
    @JsonKey(name: 'pin_hash') required String pinHash,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    @Default(UserRole.cashier) UserRole role,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    
    // HR Fields
    String? email,
    String? phone,
    String? address,
    @JsonKey(name: 'birth_date') DateTime? birthDate,
    @JsonKey(name: 'hire_date') DateTime? hireDate,
    String? nationality,
    
    // Dynamic Permissions
    @Default(UserPermissions()) UserPermissions permissions,
    
    // Treasury Access Rights
    @JsonKey(name: 'assigned_account_ids') @Default([]) List<String> assignedAccountIds,
  }) = _User;

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isAdminPlus => role == UserRole.adminPlus;
  bool get isCashier => role == UserRole.cashier;

  String get fullName {
    if ((firstName == null || firstName!.isEmpty) && (lastName == null || lastName!.isEmpty)) {
      return username;
    }
    return "${firstName ?? ''} ${lastName ?? ''}".trim();
  }
  
  // Custom Permission Getters (Fallback to role if specific permission is false, or purely dynamic)
  // For now, we mix both: explicit permission OR being an admin.
  bool get canManageUsers => isAdmin || permissions.canManageUsers;
  bool get canAccessFinance => isAdmin || permissions.canAccessFinance;
  bool get canAccessSettings => isAdmin || permissions.canAccessSettings;
  bool get canManageInventory => isAdmin || isManager || permissions.canManageStock;
  bool get canManageSuppliers => isAdmin || isManager || permissions.canManageSuppliers;
  bool get canAccessReports => isAdmin || isManager || permissions.canViewReports;
  bool get canManageHR => isAdmin || permissions.canManageHR;
  bool get canManageCustomers => isAdmin || isManager || permissions.canManageCustomers;
  bool get canSell => isAdmin || isManager || isCashier || role == UserRole.sales;

  // New Global Guards (Enterprise Security)
  bool get canManageExpenses => isAdmin || isManager || permissions.canManageExpenses;
  bool get canRefund => isAdmin || permissions.canRefund;
  bool get canChangePrice => isAdmin || permissions.canChangePrice;
  bool get canViewReports => isAdmin || isManager || permissions.canViewReports;

  // Account Rights Check
  bool canAccessAccount(String accountId) {
    if (isAdmin || isManager || isAdminPlus) return true;
    return assignedAccountIds.contains(accountId);
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
