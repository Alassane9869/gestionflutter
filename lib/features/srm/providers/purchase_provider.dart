import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';

final purchaseActionsProvider = Provider((ref) => PurchaseActions(ref));

final purchaseListProvider = FutureProvider<List<PurchaseOrder>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final List<Map<String, dynamic>> maps = await db.query('purchase_orders', orderBy: 'date DESC');
  return maps.map((m) => PurchaseOrder.fromMap(m)).toList();
});

final purchaseItemsProvider = FutureProvider.family<List<PurchaseOrderItem>, String>((ref, orderId) async {
  final db = await ref.read(databaseServiceProvider).database;
  final List<Map<String, dynamic>> maps = await db.query('purchase_order_items', where: 'order_id = ?', whereArgs: [orderId]);
  return maps.map((m) => PurchaseOrderItem.fromMap(m)).toList();
});

class PurchaseActions {

  final Ref ref;
  PurchaseActions(this.ref);

  Future<PurchaseOrder> createPurchaseOrder({
    required String supplierId,
    required List<PurchaseOrderItem> items,
    required double amountPaid,
    required bool isCredit,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    double shippingFees = 0.0,
    String? accountId,
    String? paymentMethod,
    String? reference,
  }) async {
    final db = await ref.read(databaseServiceProvider).database;
    final activeSession = await ref.read(activeSessionProvider.future);
    if (activeSession == null) {
       // Optional: Log warning or handle session-less state
    }
    final user = await ref.read(authServiceProvider.future);
    
    final subTotal = items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
    final totalAmount = (subTotal - discountAmount) + taxAmount + shippingFees;

    final order = PurchaseOrder(
      supplierId: supplierId,
      accountId: accountId,
      reference: reference ?? "PUR-${DateTime.now().millisecondsSinceEpoch}",
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      shippingFees: shippingFees,
      paymentMethod: paymentMethod,
      isCredit: isCredit,
      status: OrderStatus.DELIVERED,
    );

    await db.transaction((txn) async {
      // 1. Insert Order
      await txn.insert('purchase_orders', order.toMap());

      // 2. Calcul du Landed Cost Factor (Coefficient de frais d'approche)
      // On répartit les frais (livraison + taxes - remise globale) au prorata du prix d'achat
      final landedCostFactor = subTotal > 0 ? (totalAmount / subTotal) : 1.0;
      
      // 3. Insert Items & Update Stock/WAC
      for (final item in items) {
        await txn.insert('purchase_order_items', {
          ...item.toMap(),
          'order_id': order.id,
        });

        final productMap = (await txn.query('products', where: 'id = ?', whereArgs: [item.productId])).first;
        final currentQty = (productMap['quantity'] as num).toDouble();
        final currentWac = (productMap['weighted_average_cost'] as num?)?.toDouble() ?? (productMap['purchasePrice'] as num).toDouble();

        // Le prix de revient Inclut maintenant les frais d'approche
        final costPriceWithFees = item.unitPrice * landedCostFactor;

        double newWac = costPriceWithFees;
        if (currentQty > 0) {
          newWac = ((currentQty * currentWac) + (item.quantity * costPriceWithFees)) / (currentQty + item.quantity);
        }

        await txn.update('products', {
          'quantity': currentQty + item.quantity,
          'weighted_average_cost': newWac,
          'purchasePrice': item.unitPrice, // On garde le prix facon unitaire brut ici
        }, where: 'id = ?', whereArgs: [item.productId]);

        await txn.insert('stock_movements', {
          'id': DateTime.now().millisecondsSinceEpoch.toString() + item.productId,
          'product_id': item.productId,
          'type': 'IN',
          'quantity': item.quantity,
          'reason': 'Achat Fournisseur : ${order.reference}',
          'date': DateTime.now().toIso8601String(),
          'user_id': user?.id ?? 'system',
        });
      }

      if (isCredit) {
        final debtIncrease = totalAmount - amountPaid;
        await txn.execute('UPDATE suppliers SET outstanding_debt = outstanding_debt + ? WHERE id = ?', [debtIncrease, supplierId]);
      }

      if (amountPaid > 0 && accountId != null) {
        await txn.execute('UPDATE financial_accounts SET balance = balance - ? WHERE id = ?', [amountPaid, accountId]);
        await txn.insert('financial_transactions', {
          'id': 'TX-PUR-${order.id}',
          'account_id': accountId,
          'type': 'OUT',
          'amount': amountPaid,
          'category': 'EXPENSE',
          'description': 'Paiement Achat : ${order.reference}',
          'date': DateTime.now().toIso8601String(),
          'reference_id': order.id,
          'session_id': activeSession?.id,
        });
      }
    });

    // --- SYNCHRONISATION RÉSEAU ---
    try {
      final settings = ref.read(shopSettingsProvider).value;
      if (settings != null && settings.networkMode == NetworkMode.client) {
        ref.read(clientSyncProvider).sendPurchaseToServer(order, items);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur déclenchement synchro achat: $e');
    }

    ref.invalidate(productListProvider);
    ref.invalidate(supplierListProvider);
    ref.invalidate(treasuryProvider);

    return order;
  }
}
