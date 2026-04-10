class Sale {
  final String id;
  final String? clientId;
  final DateTime date;
  final double totalAmount;
  final double amountPaid;
  final String? paymentMethod;
  final bool isCredit;
  final String status;
  final double refundedAmount;
  final String userId;
  final String? accountId;
  final double discountAmount;
  final double creditAmount;
  final bool isSynced;
  final DateTime? dueDate;
  final String? sessionId;

  const Sale({
    required this.id,
    this.clientId,
    this.accountId,
    required this.date,
    required this.totalAmount,
    required this.amountPaid,
    this.paymentMethod,
    this.isCredit = false,
    this.status = 'COMPLETED',
    this.refundedAmount = 0.0,
    required this.userId,
    this.discountAmount = 0.0,
    this.creditAmount = 0.0,
    this.isSynced = true,
    this.dueDate,
    this.sessionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'account_id': accountId,
      'date': date.toIso8601String(),
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'is_credit': isCredit ? 1 : 0,
      'status': status,
      'refunded_amount': refundedAmount,
      'user_id': userId,
      'discount_amount': discountAmount,
      'credit_amount': creditAmount,
      'is_synced': isSynced ? 1 : 0,
      'due_date': dueDate?.toIso8601String(),
      'session_id': sessionId,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      clientId: map['client_id'] as String?,
      accountId: map['account_id'] as String?,
      date: DateTime.parse(map['date'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      isCredit: (map['is_credit'] as num).toInt() == 1,
      status: map['status'] as String? ?? 'COMPLETED',
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0.0,
      userId: map['user_id'] as String,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      creditAmount: (map['credit_amount'] as num?)?.toDouble() ?? 0.0,
      isSynced: (map['is_synced'] as num? ?? 1) == 1,
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      sessionId: map['session_id'] as String?,
    );
  }
}

class SaleItem {
  final String id;
  final String saleId;
  final String? productId; // Nullable pour les articles personnalisés
  final double quantity;
  final double returnedQuantity;
  final double unitPrice;
  final double discountPercent;
  final double costPrice; // Ajouté pour snapshot CMUP (Marges historiques)

  const SaleItem({
    required this.id,
    required this.saleId,
    this.productId,
    required this.quantity,
    this.returnedQuantity = 0.0,
    required this.unitPrice,
    this.discountPercent = 0.0,
    this.costPrice = 0.0, // Par défaut 0 si non spécifié
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'quantity': quantity,
      'returned_quantity': returnedQuantity,
      'unit_price': unitPrice,
      'discount_percent': discountPercent,
      'cost_price': costPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      returnedQuantity: (map['returned_quantity'] as num? ?? 0.0).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      discountPercent: (map['discount_percent'] as num? ?? 0.0).toDouble(),
      costPrice: (map['cost_price'] as num? ?? 0.0).toDouble(),
    );
  }
}
