import 'package:uuid/uuid.dart';

// ignore: constant_identifier_names
enum OrderStatus { PENDING, DELIVERED, CANCELLED }

class PurchaseOrder {
  final String id;
  final String supplierId;
  final String? accountId;
  final String reference;
  final DateTime date;
  final double totalAmount;
  final double amountPaid;
  final double discountAmount;
  final double taxAmount;
  final double shippingFees;
  final String? paymentMethod;
  final bool isCredit;
  final OrderStatus status;
  final String? sessionId;
  final bool isSynced;

  PurchaseOrder({
    String? id,
    required this.supplierId,
    this.accountId,
    required this.reference,
    DateTime? date,
    required this.totalAmount,
    required this.amountPaid,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.shippingFees = 0.0,
    this.paymentMethod,
    required this.isCredit,
    this.status = OrderStatus.PENDING,
    this.sessionId,
    this.isSynced = false,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'account_id': accountId,
      'reference': reference,
      'date': date.toIso8601String(),
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'shipping_fees': shippingFees,
      'payment_method': paymentMethod,
      'is_credit': isCredit ? 1 : 0,
      'status': status.name,
      'session_id': sessionId,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] as String,
      supplierId: map['supplier_id'] as String,
      accountId: map['account_id'] as String?,
      reference: map['reference'] as String,
      date: DateTime.parse(map['date'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      shippingFees: (map['shipping_fees'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] as String?,
      isCredit: (map['is_credit'] as num?)?.toInt() == 1,
      status: OrderStatus.values.firstWhere((e) => e.name == map['status']),
      sessionId: map['session_id'] as String?,
      isSynced: (map['is_synced'] as num?)?.toInt() == 1,
    );
  }
}

class PurchaseOrderItem {
  final String id;
  final String? orderId;
  final String productId;
  final double quantity;
  final double unitPrice;

  PurchaseOrderItem({
    String? id,
    this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String?,
      productId: map['product_id'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
    );
  }
}
