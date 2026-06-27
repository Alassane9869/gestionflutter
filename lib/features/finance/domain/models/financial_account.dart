// ignore_for_file: constant_identifier_names
import 'package:uuid/uuid.dart';

enum AccountType { CASH, BANK, MOBILE_MONEY }

extension AccountTypeX on AccountType {
  String get label {
    switch (this) {
      case AccountType.CASH: return 'Espèces / Caisse';
      case AccountType.BANK: return 'Compte Bancaire';
      case AccountType.MOBILE_MONEY: return 'Mobile Money';
    }
  }
}

class FinancialAccount {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final bool isDefault;
  final String? operator; // e.g. 'Wave', 'Orange Money', 'MTN', 'Ecobank', etc.

  FinancialAccount({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.isDefault = false,
    this.operator,
  });

  /// Display label used in POS and elsewhere
  String get displayName {
    if (operator != null && operator!.isNotEmpty) {
      return '$name ($operator)';
    }
    return name;
  }

  factory FinancialAccount.fromMap(Map<String, dynamic> map) {
    return FinancialAccount(
      id: map['id'],
      name: map['name'],
      type: AccountType.values.firstWhere((e) => e.name == map['type']),
      balance: (map['balance'] as num).toDouble(),
      isDefault: map['is_default'] == 1,
      operator: map['operator'] as String?,
    );
  }
}

enum TransactionType { IN, OUT }

extension TransactionTypeX on TransactionType {
  String get label {
    switch (this) {
      case TransactionType.IN: return 'Entrée';
      case TransactionType.OUT: return 'Sortie';
    }
  }
}

enum TransactionCategory { SALE, EXPENSE, PURCHASE, TRANSFER, ADJUSTMENT, REFUND, DEBT_REPAYMENT, LOYALTY_REDEEM }

extension TransactionCategoryX on TransactionCategory {
  String get label {
    switch (this) {
      case TransactionCategory.SALE: return 'Vente';
      case TransactionCategory.EXPENSE: return 'Dépense Opérationnelle';
      case TransactionCategory.PURCHASE: return 'Achat / Approvisionnement';
      case TransactionCategory.TRANSFER: return 'Transfert entre comptes';
      case TransactionCategory.ADJUSTMENT: return 'Ajustement de solde';
      case TransactionCategory.REFUND: return 'Remboursement Client';
      case TransactionCategory.DEBT_REPAYMENT: return 'Règlement de Dette';
      case TransactionCategory.LOYALTY_REDEEM: return 'Utilisation Fidélité';
    }
  }
}

class FinancialTransaction {
  final String id;
  final String accountId;
  final TransactionType type;
  final double amount;
  final TransactionCategory category;
  final String? description;
  final DateTime date;
  final String? referenceId;
  final String? sessionId;

  FinancialTransaction({
    String? id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.category,
    this.description,
    required this.date,
    this.referenceId,
    this.sessionId,
  }) : id = id ?? const Uuid().v4();

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'],
      accountId: map['account_id'],
      type: TransactionType.values.firstWhere((e) => e.name == map['type']),
      amount: (map['amount'] as num).toDouble(),
      category: TransactionCategory.values.firstWhere((e) => e.name == map['category']),
      description: map['description'],
      date: DateTime.parse(map['date']),
      referenceId: map['reference_id'],
      sessionId: map['session_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'type': type.name,
      'amount': amount,
      'category': category.name,
      'description': description,
      'date': date.toIso8601String(),
      'reference_id': referenceId,
      'session_id': sessionId,
    };
  }
}
