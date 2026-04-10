import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/application/inventory_automation_service.dart';
import 'package:danaya_plus/features/inventory/data/product_repository.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';

final srmServiceProvider = Provider<SrmService>((ref) {
  return SrmService(ref);
});

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

class SrmService {
  final Ref _ref;
  final _uuid = const Uuid();

  SrmService(this._ref);

  /// Main method for processing a purchase order.
  /// Used by both the UI and the Assistant.
  Future<PurchaseOrder> processPurchase({
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
    DateTime? date,
  }) async {
    try {
      final db = await _ref.read(databaseServiceProvider).database;
      final activeSession = await _ref.read(activeSessionProvider.future);
      final user = await _ref.read(authServiceProvider.future);

      if (user == null) throw Exception("Authentification requise");

      // 1. Calculations
      final subTotal = items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
      final totalAmount = (subTotal - discountAmount) + taxAmount + shippingFees;

      if (amountPaid > totalAmount) {
        throw Exception("Le montant payé ($amountPaid) ne peut excéder le total ($totalAmount).");
      }

      final orderId = _uuid.v4();
      final orderDate = date ?? DateTime.now();

      final order = PurchaseOrder(
        id: orderId,
        supplierId: supplierId,
        accountId: accountId,
        reference: reference ?? "PUR-${orderId.substring(0, 8).toUpperCase()}",
        date: orderDate,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        shippingFees: shippingFees,
        paymentMethod: paymentMethod,
        isCredit: isCredit,
        status: OrderStatus.DELIVERED,
        sessionId: activeSession?.id,
      );

      await db.transaction((txn) async {
        // --- 2. PRE-FLIGHT CHECKS (Balance) ---
        if (accountId != null && amountPaid > 0) {
          final accRow = await txn.query('financial_accounts', columns: ['balance', 'name'], where: 'id = ?', whereArgs: [accountId]);
          if (accRow.isNotEmpty) {
            final currentBalance = (accRow.first['balance'] as num).toDouble();
            if (currentBalance < amountPaid) {
              final accName = accRow.first['name'] as String;
              throw Exception("Solde insuffisant dans '$accName'. Disponible: $currentBalance. Requis: $amountPaid.");
            }
          }
        }

        // --- 3. CORE INSERTS ---
        await txn.insert('purchase_orders', order.toMap());

        // Landed Cost Factor for distributing fees/discounts proportional to price
        final landedCostFactor = subTotal > 0 ? (totalAmount / subTotal) : 1.0;

        for (final item in items) {
          final itemId = _uuid.v4();
          await txn.insert('purchase_order_items', {
            ...item.toMap(),
            'id': itemId,
            'order_id': orderId,
          });

          // Stock & WAC Logic
          final productRows = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
          if (productRows.isNotEmpty) {
            final pRow = productRows.first;
            final currentQty = (pRow['quantity'] as num).toDouble();
            final currentWac = (pRow['weighted_average_cost'] as num? ?? pRow['purchasePrice'] as num? ?? 0.0).toDouble();

            final costPriceWithFees = item.unitPrice * landedCostFactor;
            final totalNewQty = currentQty + item.quantity;
            
            double newWac = costPriceWithFees;
            if (totalNewQty > 0 && currentQty > 0) {
              newWac = ((currentQty * currentWac) + (item.quantity * costPriceWithFees)) / totalNewQty;
            }

            await txn.update('products', {
              'quantity': totalNewQty,
              'weighted_average_cost': newWac,
              'purchasePrice': item.unitPrice, 
            }, where: 'id = ?', whereArgs: [item.productId]);
          }

          // Stock Movement
          await txn.insert('stock_movements', {
            'id': _uuid.v4(),
            'product_id': item.productId,
            'type': 'IN',
            'quantity': item.quantity,
            'reason': 'Achat Fournisseur : ${order.reference}',
            'date': orderDate.toIso8601String(),
            'user_id': user.id,
            'session_id': activeSession?.id,
          });
        }

        // --- 4. SUPPLIER & FINANCE UPDATES ---
        if (isCredit) {
          final debtIncrease = totalAmount - amountPaid;
          await txn.rawUpdate(
            'UPDATE suppliers SET total_purchases = total_purchases + ?, outstanding_debt = outstanding_debt + ? WHERE id = ?',
            [totalAmount, debtIncrease, supplierId],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE suppliers SET total_purchases = total_purchases + ? WHERE id = ?',
            [totalAmount, supplierId],
          );
        }

        if (amountPaid > 0 && accountId != null) {
          // Financial Transaction
          final tx = FinancialTransaction(
            accountId: accountId,
            type: TransactionType.OUT,
            amount: amountPaid,
            category: TransactionCategory.PURCHASE,
            description: "Paiement Achat : ${order.reference}",
            date: orderDate,
            referenceId: orderId,
            sessionId: activeSession?.id,
          );
          await txn.insert('financial_transactions', tx.toMap());

          // Account Balance
          await txn.execute(
            'UPDATE financial_accounts SET balance = balance - ? WHERE id = ?',
            [amountPaid, accountId],
          );
        }
      });

      // --- 5. POST-TRANSACTION AUTOMATIONS ---
      _onPostSuccess(order, items);

      return order;
    } catch (e) {
      debugPrint("❌ SrmService Error: $e");
      rethrow;
    }
  }

  void _onPostSuccess(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    // Invalidate providers
    _ref.invalidate(productListProvider);
    _ref.invalidate(supplierListProvider);
    _ref.read(treasuryProvider.notifier).refresh();

    // Sync
    try {
      _ref.read(clientSyncProvider).syncPendingAuditData();
    } catch (_) {}

    // Auto-Labels
    try {
      final settings = await _ref.read(shopSettingsProvider.future);
      if (settings.autoPrintLabelsOnStockIn) {
        final automation = _ref.read(inventoryAutomationServiceProvider);
        final List<Product> printQueue = [];
        for (final item in items) {
          final product = await _ref.read(productRepositoryProvider).getById(item.productId);
          if (product != null) {
            printQueue.addAll(List.generate(item.quantity.toInt(), (_) => product));
          }
        }
        if (printQueue.isNotEmpty) {
          await automation.printBarcodeLabels(printQueue);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Auto-print failed: $e");
    }
  }
}
