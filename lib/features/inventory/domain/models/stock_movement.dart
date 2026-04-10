import 'package:uuid/uuid.dart';

// ignore: constant_identifier_names
enum MovementType { IN, OUT, ADJUSTMENT, TRANSFER }

extension MovementTypeX on MovementType {
  String get label {
    switch (this) {
      case MovementType.IN: return 'Entrée de Stock';
      case MovementType.OUT: return 'Sortie de Stock';
      case MovementType.ADJUSTMENT: return 'Ajustement d\'Inventaire';
      case MovementType.TRANSFER: return 'Transfert Inter-Entrepôt';
    }
  }
}

class StockMovement {
  final String id;
  final String productId;
  final MovementType type;
  final double quantity;
  final String reason;
  final DateTime date;
  final String userId;
  final String? userName;
  final String? warehouseId;
  final String? sessionId;
  final bool isSynced;
  final double? balanceBefore;
  final double? balanceAfter;

  StockMovement({
    String? id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.reason,
    DateTime? date,
    this.userId = 'sysadmin',
    this.userName,
    this.warehouseId,
    this.sessionId,
    this.isSynced = false,
    this.balanceBefore,
    this.balanceAfter,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type.name,
      'quantity': quantity,
      'reason': reason,
      'date': date.toIso8601String(),
      'user_id': userId,
      'warehouse_id': warehouseId,
      'session_id': sessionId,
      'is_synced': isSynced ? 1 : 0,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      type: MovementType.values.firstWhere((e) => e.name == map['type']),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason'] as String,
      date: DateTime.parse(map['date'] as String),
      userId: map['user_id'] as String,
      userName: map['username'] as String?,
      warehouseId: map['warehouse_id'] as String?,
      sessionId: map['session_id'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      balanceBefore: (map['balance_before'] as num?)?.toDouble(),
      balanceAfter: (map['balance_after'] as num?)?.toDouble(),
    );
  }

  StockMovement copyWith({
    String? id,
    String? productId,
    MovementType? type,
    double? quantity,
    String? reason,
    DateTime? date,
    String? userId,
    String? userName,
    String? warehouseId,
    String? sessionId,
    bool? isSynced,
    double? balanceBefore,
    double? balanceAfter,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      warehouseId: warehouseId ?? this.warehouseId,
      sessionId: sessionId ?? this.sessionId,
      isSynced: isSynced ?? this.isSynced,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
    );
  }
}
