import 'package:uuid/uuid.dart';

enum StockAuditStatus { draft, completed }

class StockAudit {
  final String id;
  final DateTime date;
  final StockAuditStatus status;
  final String? notes;
  final String? category;

  StockAudit({
    required this.id,
    required this.date,
    required this.status,
    this.notes,
    this.category,
  });

  factory StockAudit.create({String? notes, String? category}) {
    return StockAudit(
      id: const Uuid().v4(),
      date: DateTime.now(),
      status: StockAuditStatus.draft,
      notes: notes,
      category: category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'status': status.name.toUpperCase(),
      'notes': notes,
      'category': category,
    };
  }

  factory StockAudit.fromMap(Map<String, dynamic> map) {
    return StockAudit(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      status: StockAuditStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (map['status'] as String).toLowerCase(),
      ),
      notes: map['notes'] as String?,
      category: map['category'] as String?,
    );
  }
}

class StockAuditItem {
  final String id;
  final String auditId;
  final String productId;
  final double theoreticalQty;
  final double actualQty;
  final double difference;
  // Extras joined from products
  final String? productName;

  StockAuditItem({
    required this.id,
    required this.auditId,
    required this.productId,
    required this.theoreticalQty,
    required this.actualQty,
    required this.difference,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audit_id': auditId,
      'product_id': productId,
      'theoretical_qty': theoreticalQty,
      'actual_qty': actualQty,
      'difference': difference,
    };
  }

  factory StockAuditItem.fromMap(Map<String, dynamic> map) {
    return StockAuditItem(
      id: map['id'] as String,
      auditId: map['audit_id'] as String,
      productId: map['product_id'] as String,
      theoreticalQty: (map['theoretical_qty'] as num?)?.toDouble() ?? 0.0,
      actualQty: (map['actual_qty'] as num?)?.toDouble() ?? 0.0,
      difference: (map['difference'] as num?)?.toDouble() ?? 0.0,
      productName: map['product_name'] as String?,
    );
  }
}
