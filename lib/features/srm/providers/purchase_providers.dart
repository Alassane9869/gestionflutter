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
import 'package:flutter/foundation.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref);
});

class PurchaseService {
  final Ref _ref;

  PurchaseService(this._ref);

  /// [cart] items: { 'product_id': String, 'qty': int, 'unit_price': double }
  Future<bool> checkout({
    required List<Map<String, dynamic>> cart,
    required double totalAmount,
    required double amountPaid,
    required String supplierId,
    String? accountId,
    String? paymentMethod,
    required bool isCredit,
  }) async {
    try {
      final db = await _ref.read(databaseServiceProvider).database;
      final activeSession = await _ref.read(activeSessionProvider.future);
      final user = await _ref.read(authServiceProvider.future);

      if (user == null) throw Exception("Non authentifié");

      final orderId = const Uuid().v4();
      final orderDate = DateTime.now();

      final order = PurchaseOrder(
        id: orderId,
        supplierId: supplierId,
        accountId: accountId,
        reference: "CMD-${orderId.substring(0, 8).toUpperCase()}",
        date: orderDate,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        isCredit: isCredit,
        status: OrderStatus.DELIVERED, // Assuming direct delivery for now
        sessionId: activeSession?.id,
      );

      await db.transaction((txn) async {
        // --- 1. STRICT VULNERABILITY CHECKS ---
        if (amountPaid > totalAmount) {
          throw Exception("Surpaiement refusé : Le montant payé ($amountPaid) ne peut excéder le total de la commande ($totalAmount).");
        }

        if (accountId != null && amountPaid > 0) {
           final accRow = await txn.query('financial_accounts', columns: ['balance', 'name'], where: 'id = ?', whereArgs: [accountId]);
           if (accRow.isNotEmpty) {
             final currentBalance = (accRow.first['balance'] as num).toDouble();
              if (currentBalance < amountPaid) {
                final accName = accRow.first['name'] as String;
                final settings = _ref.read(shopSettingsProvider).value;
                final currency = settings?.currency ?? 'FCFA';
                throw Exception("Solde insuffisant dans '$accName'. Disponible: $currentBalance $currency. Requis: $amountPaid $currency.");
              }
           }
        }

        // 2. Insert the purchase order record
        await txn.insert('purchase_orders', order.toMap());

        // 2. Handle financial transaction if money was paid (even partially)
        if (accountId != null && amountPaid > 0) {
          final tx = FinancialTransaction(
            accountId: accountId,
            type: TransactionType.OUT, // Money is leaving
            amount: amountPaid,
            category: TransactionCategory.PURCHASE, // Corrected from EXPENSE during audit
            description: "Achat Fournisseur #${order.reference}",
            date: orderDate,
            referenceId: orderId,
            sessionId: activeSession?.id,
          );
          await txn.insert('financial_transactions', tx.toMap());

          // Update account balance (Deduction)
          await txn.execute(
            'UPDATE financial_accounts SET balance = balance - ? WHERE id = ?',
            [amountPaid, accountId],
          );
        }

        // 3. Process each item in the cart
        final batch = txn.batch();
        for (var item in cart) {
          final productId = item['product_id'] as String;
          final qty = (item['qty'] as num).toDouble();
          final price = (item['unit_price'] as num).toDouble();

          // Insert order item
          batch.insert('purchase_order_items', PurchaseOrderItem(
            id: const Uuid().v4(),
            orderId: orderId,
            productId: productId,
            quantity: qty,
            unitPrice: price,
          ).toMap());

          // Recalculate WAC (Weighted Average Cost / CMUP)
          // New CMUP = ((Current_Stock * Current_CMUP) + (New_Qty * New_Price)) / (Current_Stock + New_Qty)
          final productRows = await txn.query('products', columns: ['quantity', 'weighted_average_cost', 'purchasePrice'], where: 'id = ?', whereArgs: [productId]);
          if (productRows.isNotEmpty) {
            final pRow = productRows.first;
            final currentQty = (pRow['quantity'] as num).toDouble();
            final currentWac = (pRow['weighted_average_cost'] as num? ?? pRow['purchasePrice'] as num? ?? 0.0).toDouble();
            
            final totalNewQty = currentQty + qty;
            double newWac = price; // Default if stock was 0
            
            if (totalNewQty > 0 && currentQty > 0) {
              newWac = ((currentQty * currentWac) + (qty * price)) / totalNewQty;
            }

            // Update product (WAC + new qty)
            batch.rawUpdate(
              'UPDATE products SET quantity = quantity + ?, weighted_average_cost = ?, purchasePrice = ? WHERE id = ?',
              [qty, newWac, price, productId],
            );
          } else {
            // Fallback: simple qty update if product lookup fails for some reason
            batch.rawUpdate(
              'UPDATE products SET quantity = quantity + ? WHERE id = ?',
              [qty, productId],
            );
          }

          // Record stock movement
          batch.insert('stock_movements', {
            'id': const Uuid().v4(),
            'product_id': productId,
            'type': 'IN',
            'quantity': qty,
            'reason': 'Réception Commande ${order.reference}',
            'date': orderDate.toIso8601String(),
            'user_id': user.id,
            'session_id': activeSession?.id,
          });
        }
        await batch.commit(noResult: true);

        // 4. Update supplier stats
        if (isCredit) {
          // If credit, add to outstanding debt
          final debtAmount = totalAmount - amountPaid;
          await txn.rawUpdate(
            'UPDATE suppliers SET total_purchases = total_purchases + ?, outstanding_debt = outstanding_debt + ? WHERE id = ?',
            [totalAmount, debtAmount, supplierId],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE suppliers SET total_purchases = total_purchases + ? WHERE id = ?',
            [totalAmount, supplierId],
          );
        }
      });

      // Refresh providers
      _ref.invalidate(productListProvider);
      _ref.invalidate(supplierListProvider);
      // We will create purchaseOrderListProvider shortly if needed
      _ref.read(treasuryProvider.notifier).refresh(); // Important for UI to update balances
      
      // Synchronisation réseau
      _ref.read(clientSyncProvider).syncPendingAuditData();

      // Ultra Pro: Auto-Etiquetage lors de la réception SRM
      try {
        final settings = await _ref.read(shopSettingsProvider.future);
        if (settings.autoPrintLabelsOnStockIn) {
          final automation = _ref.read(inventoryAutomationServiceProvider);
          final List<Product> printQueue = [];
          
          for (final item in cart) {
            final productId = item['product_id'] as String;
            final qty = (item['qty'] as num).toDouble();
            final product = await _ref.read(productRepositoryProvider).getById(productId);
            if (product != null) {
              // On génère autant d'étiquettes que d'articles reçus
              printQueue.addAll(List.generate(qty.toInt(), (_) => product));
            }
          }
          
          if (printQueue.isNotEmpty) {
            await automation.printBarcodeLabels(printQueue);
          }
        }
      } catch (e) {
        debugPrint("Auto-print error during SRM: $e");
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
