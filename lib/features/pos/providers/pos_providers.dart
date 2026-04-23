import 'dart:async';
import 'package:path/path.dart' as p_path;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/pos/domain/models/sale.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/core/network/server_service.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';

import 'package:danaya_plus/core/utils/safe_math.dart';

class PosFullScreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void setFullScreen(bool val) => state = val;
}

final posFullScreenProvider = NotifierProvider<PosFullScreenNotifier, bool>(
  PosFullScreenNotifier.new,
);

class PosCartItem {
  final String productId;
  final String name;
  final double unitPrice;
  final double qty;
  final String? imagePath;
  final double discountPercent; // New field for per-item discount

  PosCartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    this.qty = 1.0,
    this.imagePath,
    this.discountPercent = 0.0,
  });

  double get lineTotalBrut => SafeMath.round2(unitPrice * qty);
  double get lineDiscountAmount => SafeMath.round2((lineTotalBrut * discountPercent) / 100);
  double get lineTotal => SafeMath.round2(lineTotalBrut - lineDiscountAmount);

  PosCartItem copyWith({double? qty, double? discountPercent}) {
    return PosCartItem(
      productId: productId,
      name: name,
      unitPrice: unitPrice,
      imagePath: imagePath,
      qty: qty ?? this.qty,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}

class CartNotifier extends Notifier<List<PosCartItem>> {
  @override
  List<PosCartItem> build() => [];

  void _broadcastCart() {
    final settings = ref.read(shopSettingsProvider).value;
    final loyaltyEnabled = settings?.loyaltyEnabled ?? false;
    final pointsPerAmount = settings?.pointsPerAmount ?? 1000;
    
    // Calcul des points potentiels
    final currentSubtotal = subtotal;
    int potentialPoints = 0;
    if (loyaltyEnabled && currentSubtotal >= pointsPerAmount) {
      potentialPoints = (currentSubtotal / pointsPerAmount).floor();
    }

    final selectedClientId = ref.read(selectedClientIdProvider);
    String? clientName;
    int? currentPoints;
    bool isGuest = selectedClientId == null;

    if (!isGuest) {
      final clients = ref.read(clientListProvider).value ?? [];
      try {
        final client = clients.firstWhere((c) => c.id == selectedClientId);
        clientName = client.name;
        currentPoints = client.loyaltyPoints;
      } catch (_) {}
    }

    try {
      ref.read(serverServiceProvider).broadcastEvent('cart_updated', {
        'items': state.map((item) => {
          'name': item.name,
          'qty': item.qty,
          'price': item.unitPrice,
          'total': item.lineTotal,
          'image': item.imagePath != null ? p_path.basename(item.imagePath!) : null,
        }).toList(),
        'subtotal': currentSubtotal,
        'total': currentSubtotal,
        'potentialPoints': potentialPoints,
        'isGuest': isGuest,
        'clientName': clientName,
        'currentPoints': currentPoints,
      });
    } catch (e) {
      debugPrint("🚫 PosNotifier: Failed to broadcast cart update: $e");
    }
  }

  void addProduct(Product p) {
    if (p.isOutOfStock && !p.isService) return;
    final idx = state.indexWhere((item) => item.productId == p.id);
    if (idx >= 0) {
      if (p.isService || state[idx].qty < p.quantity) {
        state = [
          for (final item in state)
            if (item.productId == p.id)
              item.copyWith(qty: item.qty + 1.0)
            else
              item,
        ];
      }
    } else {
      state = [
        ...state,
        PosCartItem(
          productId: p.id, 
          name: p.name, 
          unitPrice: p.sellingPrice,
          qty: 1.0,
          imagePath: p.imagePath,
        ),
      ];
    }
    _broadcastCart();
  }
  
  // Method to manually trigger broadcast when client changes
  void forceBroadcast() => _broadcastCart();

  void removeProduct(String productId) {
    state = state.where((item) => item.productId != productId).toList();
    _broadcastCart();
  }

  void updateQty(String productId, double qty) {
    if (qty <= 0) {
      removeProduct(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.productId == productId) item.copyWith(qty: qty) else item,
    ];
    _broadcastCart();
  }

  void updateDiscount(String productId, double discount) {
    state = [
      for (final item in state)
        if (item.productId == productId)
          item.copyWith(discountPercent: discount.clamp(0.0, 100.0))
        else
          item,
    ];
    _broadcastCart();
  }

  void clear() {
    state = [];
    _broadcastCart();
  }

  void loadFromQuote(List<dynamic> quoteItems) {
    state = quoteItems.map((i) {
      return PosCartItem(
        productId: i['product_id'] ?? 'custom',
        name: i['custom_name'] ?? 'Article',
        unitPrice: (i['unit_price'] as num).toDouble(),
        qty: (i['quantity'] as num).toDouble(),
        discountPercent: (i['discount_percent'] as num? ?? 0.0).toDouble(),
      );
    }).toList();
  }

  double get subtotal => SafeMath.round2(state.fold(0.0, (sum, item) => sum + item.lineTotal));
  double get totalDiscountItems =>
      SafeMath.round2(state.fold(0.0, (sum, item) => sum + item.lineDiscountAmount));
  double get totalItems => SafeMath.round2(state.fold(0.0, (sum, item) => sum + item.qty));
}

final cartProvider = NotifierProvider<CartNotifier, List<PosCartItem>>(
  CartNotifier.new,
);

final posProvider = Provider<PosService>((ref) {
  return PosService(ref);
});

class PosService {
  final Ref _ref;

  PosService(this._ref);

  /// [cart] items: { 'product_id': String, 'qty': int, 'price': double }
  Future<String?> checkout({
    required List<Map<String, dynamic>> cart,
    required double totalAmount,
    required double amountPaid,
    String? clientId,
    String? accountId,
    String? paymentMethod,
    required bool isCredit,
    int? pointsToRedeem,
    List<Map<String, dynamic>>? multiPayments,
    double discountAmount = 0.0,
    DateTime? dueDate,
  }) async {
    try {
      final db = await _ref.read(databaseServiceProvider).database;
      final user = await _ref.read(authServiceProvider.future);
      final activeSession = await _ref.read(activeSessionProvider.future);

      if (user == null) throw Exception("Non authentifié");

      final saleId = const Uuid().v4();
      final saleDate = DateTime.now();
      final settings = _ref.read(shopSettingsProvider).value;
      final isClient = settings?.networkMode == NetworkMode.client;

      final totalAmountSafe = SafeMath.round2(totalAmount);
      final amountPaidSafe = SafeMath.round2(amountPaid);
      final discountAmountSafe = SafeMath.round2(discountAmount);

      final netAmountPaid = amountPaidSafe > totalAmountSafe ? totalAmountSafe : amountPaidSafe;
      final creditAmount = isCredit ? SafeMath.round2(totalAmountSafe - netAmountPaid) : 0.0;

      final sale = Sale(
        id: saleId,
        clientId: clientId,
        accountId: accountId,
        date: saleDate,
        totalAmount: totalAmountSafe,
        amountPaid: amountPaidSafe,
        paymentMethod: paymentMethod,
        isCredit: isCredit,
        userId: user.id,
        discountAmount: discountAmountSafe,
        creditAmount: creditAmount,
        isSynced: !isClient,
        dueDate: dueDate,
        sessionId: activeSession?.id,
      );

      await db.transaction((txn) async {
        // --- 1. STRICT STOCK VALIDATION ---
        for (var item in cart) {
          final productId = item['product_id'] as String?;
          if (productId != null && productId != 'custom') {
            final qtyRequested = (item['qty'] as num).toDouble();
            final productRow = await txn.query('products', columns: ['quantity', 'name', 'is_service'], where: 'id = ?', whereArgs: [productId]);
            if (productRow.isNotEmpty) {
              final isService = (productRow.first['is_service'] as int?) == 1;
              if (!isService) {
                final currentQty = (productRow.first['quantity'] as num).toDouble();
                if (currentQty < qtyRequested) {
                  final name = productRow.first['name'] as String;
                  throw Exception("Stock insuffisant pour '$name'. Disponible: $currentQty, Demandé: $qtyRequested.");
                }
              }
            }
          }
        }

        // --- 2. CLIENT CREDIT LIMIT VALIDATION ---
        if (clientId != null && isCredit && creditAmount > 0) {
           final clientRow = await txn.query('clients', columns: ['credit', 'max_credit', 'name'], where: 'id = ?', whereArgs: [clientId]);
           if (clientRow.isNotEmpty) {
             final currentCredit = (clientRow.first['credit'] as num).toDouble();
             final maxCredit = (clientRow.first['max_credit'] as num?)?.toDouble() ?? 50000.0;
             if ((currentCredit + creditAmount) > maxCredit) {
                 final name = clientRow.first['name'] as String;
                 final currency = settings?.currency ?? 'FCFA';
                 throw Exception("Plafond dépassé pour '$name'. Restant autorisé: ${maxCredit >= currentCredit ? maxCredit - currentCredit : 0} $currency.");
             }
           }
        }

        // Insert the sale record
        await txn.insert('sales', sale.toMap());

        // Handle payments
        if (amountPaidSafe > 0) {
          final List<Map<String, dynamic>> actualPayments =
              multiPayments ??
              [
                {
                  'accountId': accountId,
                  'amount': amountPaidSafe, // Record actual amount paid
                  'method': paymentMethod,
                },
              ];

          for (final p in actualPayments) {
            final pAccountId = p['accountId'] as String?;
            final double pAmount = SafeMath.round2((p['amount'] as num?)?.toDouble() ?? 0.0);
            final pMethod = p['method'] as String? ?? "CASH";

            if (pAccountId != null && pAmount > 0) {
              final tx = FinancialTransaction(
                accountId: pAccountId,
                type: TransactionType.IN,
                amount: pAmount,
                category: TransactionCategory.SALE,
                description:
                    "Encaissement Vente #${saleId.substring(0, 8).toUpperCase()} ($pMethod)",
                date: saleDate,
                referenceId: saleId,
                sessionId: activeSession?.id,
              );
              await txn.insert('financial_transactions', tx.toMap());

              await txn.execute(
                'UPDATE financial_accounts SET balance = balance + ? WHERE id = ?',
                [pAmount, pAccountId],
              );
            }
          }

          // --- CHANGE (RELIQUAT) TRACEABILITY ---
          final changeAmount = SafeMath.round2(amountPaidSafe - totalAmountSafe);
          if (changeAmount > 0) {
             // Logic Pro: On déduit toujours le rendu monnaie du compte CASH (Espèces) si possible, 
             // car on rend rarement de la monnaie via Orange Money ou Banque.
             String? changeAccountId;
             
             // 1. Chercher un compte CASH dans les paiements effectués
             final cashPayment = actualPayments.firstWhere(
               (p) => (p['method'] as String? ?? "CASH") == "CASH", 
               orElse: () => {},
             );
             if (cashPayment.isNotEmpty) {
               changeAccountId = cashPayment['accountId'] as String?;
             }

             // 2. Si pas trouvé, chercher le compte CASH par défaut dans la base
             if (changeAccountId == null) {
               final cashAccountRow = await txn.query(
                 'financial_accounts', 
                 where: 'type = ?', 
                 whereArgs: ['CASH'], 
                 limit: 1,
               );
               if (cashAccountRow.isNotEmpty) {
                 changeAccountId = cashAccountRow.first['id'] as String;
               }
             }

             // 3. Fallback sur le compte principal de la vente
             changeAccountId ??= accountId;
             
             if (changeAccountId != null) {
                final txOut = FinancialTransaction(
                  accountId: changeAccountId,
                  type: TransactionType.OUT,
                  amount: changeAmount,
                  category: TransactionCategory.SALE,
                  description: "Rendu Monnaie Vente #${saleId.substring(0, 8).toUpperCase()}",
                  date: saleDate,
                  referenceId: saleId,
                  sessionId: activeSession?.id,
                );
                await txn.insert('financial_transactions', txOut.toMap());
                
                await txn.execute(
                  'UPDATE financial_accounts SET balance = balance - ? WHERE id = ?',
                  [changeAmount, changeAccountId],
                );
             }
          }
        }

        final batch = txn.batch();

        for (var item in cart) {
          final productId = item['product_id'] as String?;
          final qty = (item['qty'] as num).toDouble();
          final price = (item['price'] as num).toDouble();
          final discountPercent = (item['discount_percent'] as num? ?? 0.0).toDouble();
          final isCustom = productId == null || productId == 'custom';
          
          double costPrice = 0.0;
          if (!isCustom) {
            final pRow = await txn.query('products', columns: ['weighted_average_cost', 'purchasePrice'], where: 'id = ?', whereArgs: [productId]);
            if (pRow.isNotEmpty) {
              costPrice = (pRow.first['weighted_average_cost'] as num? ?? pRow.first['purchasePrice'] as num? ?? 0.0).toDouble();
            }
          }

          // Insert each sale line item
          batch.insert(
            'sale_items',
            SaleItem(
              id: const Uuid().v4(),
              saleId: saleId,
              productId: isCustom ? null : productId,
              quantity: qty,
              unitPrice: price,
              discountPercent: discountPercent,
              costPrice: costPrice,
            ).toMap(),
          );

          if (!isCustom) {
            // Deduct stock
            batch.rawUpdate(
              'UPDATE products SET quantity = quantity - ? WHERE id = ?',
              [qty, productId],
            );

            // Record stock movement
            batch.insert('stock_movements', {
              'id': const Uuid().v4(),
              'product_id': productId,
              'type': 'OUT',
              'quantity': qty,
              'reason': 'Vente #${saleId.substring(0, 8).toUpperCase()}',
              'date': saleDate.toIso8601String(),
              'user_id': user.id,
              'session_id': activeSession?.id,
            });
          }
        }

        await batch.commit(noResult: true);

        // Update client stats
        if (clientId != null) {
          if (isCredit) {
            final balanceToUpdate = SafeMath.round2(totalAmountSafe - amountPaidSafe);
            await txn.rawUpdate(
              'UPDATE clients SET total_purchases = total_purchases + 1, total_spent = total_spent + ?, credit = credit + ?, last_purchase_date = ? WHERE id = ?',
              [totalAmountSafe, balanceToUpdate, saleDate.toIso8601String(), clientId],
            );
          } else {
            await txn.rawUpdate(
              'UPDATE clients SET total_purchases = total_purchases + 1, total_spent = total_spent + ?, last_purchase_date = ? WHERE id = ?',
              [totalAmountSafe, saleDate.toIso8601String(), clientId],
            );
          }

          // LOYALTY POINTS LOGIC
          if (settings != null && settings.loyaltyEnabled) {
            final pointsPerAmount = settings.pointsPerAmount;

            // 1. Gain points (based on amount actually paid, not total)
            if (netAmountPaid >= pointsPerAmount) {
              final gainedPoints = (netAmountPaid / pointsPerAmount).floor();
              await txn.rawUpdate(
                'UPDATE clients SET loyalty_points = loyalty_points + ? WHERE id = ?',
                [gainedPoints, clientId],
              );
            }

            // 2. Redeem points
            if (pointsToRedeem != null && pointsToRedeem > 0) {
              await txn.rawUpdate(
                'UPDATE clients SET loyalty_points = loyalty_points - ? WHERE id = ?',
                [pointsToRedeem, clientId],
              );
            }
          }
        }
      });

      // Log d'audit
      unawaited(_ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'SALE',
        entityType: 'SALE',
        entityId: saleId,
        description: "Vente finalisée (#${saleId.substring(0, 8).toUpperCase()}) - Total: $totalAmountSafe",
        metadata: {
          'total': totalAmountSafe,
          'items_count': cart.length,
          'is_credit': isCredit,
        },
      ));

      // --- SYNCHRONISATION RÉSEAU (Phase Interconnexion) ---
      try {
        final settings = _ref.read(shopSettingsProvider).value;
        if (settings != null && settings.networkMode == NetworkMode.client) {
          // Préparation des items pour le serveur
          final List<SaleItem> saleItems = [];
          for (var item in cart) {
            final productId = item['product_id'] as String?;
            final isCustom = productId == null || productId == 'custom';
            
            saleItems.add(SaleItem(
              id: const Uuid().v4(),
              saleId: saleId,
              productId: isCustom ? null : productId,
              quantity: (item['qty'] as num).toDouble(),
              unitPrice: (item['price'] as num).toDouble(),
              discountPercent: (item['discount_percent'] as num? ?? 0.0).toDouble(),
            ));
          }

          // Envoi asynchrone (ne bloque pas l'UI du ticket)
          _ref.read(clientSyncProvider).sendSaleToServer(sale, saleItems);
          // Déclencher la synchro de l'audit (transactions, sessions, mouvements)
          _ref.read(clientSyncProvider).syncPendingAuditData();
        }
      } catch (e) {
        debugPrint('⚠️ Erreur déclenchement synchro: $e');
      }

      // Refresh providers
      _ref.invalidate(productListProvider);
      _ref.invalidate(clientListProvider);
      _ref.read(treasuryProvider.notifier).refresh(); 
      
      // Calculate points for display
      int gainedPoints = 0;
      if (clientId != null && settings != null && settings.loyaltyEnabled) {
        gainedPoints = (netAmountPaid / settings.pointsPerAmount).floor();
      }

      // Notify Customer Display of success
      _ref.read(serverServiceProvider).broadcastEvent('sale_completed', {
        'total': totalAmount,
        'paid': amountPaid,
        'change': amountPaid - totalAmount,
        'pointsGained': gainedPoints,
        'pointsRedeemed': pointsToRedeem ?? 0,
        'potentialPoints': gainedPoints == 0 ? (totalAmount / (settings?.pointsPerAmount ?? 1000)).floor() : 0,
        'isGuest': clientId == null,
      });
      
      // Clear cart locally
      _ref.read(cartProvider.notifier).clear();

      return saleId;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> processReturn({
    required String saleId,
    required Map<String, double> returnedQuantities, // productId -> qty
  }) async {
    try {
      final db = await _ref.read(databaseServiceProvider).database;
      final user = await _ref.read(authServiceProvider.future);
      final activeSession = await _ref.read(activeSessionProvider.future);

      if (user == null) throw Exception("Non authentifié");

      await db.transaction((txn) async {
        final saleRows = await txn.query(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
        );
        if (saleRows.isEmpty) throw Exception("Vente introuvable");
        final saleData = saleRows.first;
        final accountId = saleData['account_id'] as String?;
        final clientId = saleData['client_id'] as String?;
        double refundAmount = 0.0;
        final refundDate = DateTime.now();

        for (var entry in returnedQuantities.entries) {
          final entryKey = entry.key; // Peut être 'productId' ou 'custom_itemId'
          final qtyToReturn = entry.value;
          if (qtyToReturn <= 0) continue;

          // Retrouver l'item de vente par son ID ou ProductID
          // On va chercher l'item exact dans la table sale_items
          // Pour les articles personnalisés, la clé dans returnedQuantities est 'custom_itemId'
          String where;
          List<Object?> whereArgs;
          
          if (entryKey.startsWith('custom_')) {
            final itemId = entryKey.replaceFirst('custom_', '');
            where = 'id = ?';
            whereArgs = [itemId];
          } else {
            where = 'sale_id = ? AND product_id = ?';
            whereArgs = [saleId, entryKey];
          }

          final itemRows = await txn.query(
            'sale_items',
            where: where,
            whereArgs: whereArgs,
          );
          
          if (itemRows.isEmpty) continue;
          final itemData = itemRows.first;
          final unitPrice = (itemData['unit_price'] as num).toDouble();
          final discountPercent = (itemData['discount_percent'] as num? ?? 0.0).toDouble();
          final productId = itemData['product_id'] as String?;
          
          final quantitySold = (itemData['quantity'] as num).toDouble();
          final currentReturned = (itemData['returned_quantity'] as num? ?? 0.0).toDouble();

          if (currentReturned + qtyToReturn > quantitySold) {
            throw Exception("Quantité de retour invalide");
          }

          await txn.rawUpdate(
            'UPDATE sale_items SET returned_quantity = returned_quantity + ? WHERE id = ?',
            [qtyToReturn, itemData['id']],
          );

          final netPrice = unitPrice * (1 - discountPercent / 100);
          refundAmount += qtyToReturn * netPrice;

          // Ne mettre à jour le stock que si c'est un vrai produit
          if (productId != null) {
            await txn.rawUpdate(
              'UPDATE products SET quantity = quantity + ? WHERE id = ?',
              [qtyToReturn, productId],
            );

            await txn.insert('stock_movements', {
              'id': const Uuid().v4(),
              'product_id': productId,
              'type': 'IN',
              'quantity': qtyToReturn,
              'reason':
                  'Retour Client Vente #${saleId.substring(0, 8).toUpperCase()}',
              'date': refundDate.toIso8601String(),
              'user_id': user.id,
              'session_id': activeSession?.id,
            });
          }
        }

        if (refundAmount > 0) {
          final newRefunded =
              (saleData['refunded_amount'] as num? ?? 0.0) + refundAmount;
          final totalAmount = (saleData['total_amount'] as num).toDouble();
          final saleCreditAmount = (saleData['credit_amount'] as num? ?? 0.0).toDouble();

          final status = (newRefunded >= totalAmount)
              ? 'REFUNDED'
              : 'PARTIAL_REFUND';

          // --- 1. COMPENSATION DE LA DETTE (Credit Sales) ---
          double amountToCancelDebt = 0.0;
          double actualCashRefund = refundAmount;

          if (saleCreditAmount > 0) {
            amountToCancelDebt = refundAmount > saleCreditAmount ? saleCreditAmount : refundAmount;
            actualCashRefund = refundAmount - amountToCancelDebt;
          }

          // Update sale record
          await txn.rawUpdate(
            'UPDATE sales SET status = ?, refunded_amount = ?, credit_amount = credit_amount - ? WHERE id = ?',
            [status, newRefunded, amountToCancelDebt, saleId],
          );

          // Update client record
          if (clientId != null) {
            // Calculate penalty for loyalty points
            int lostPoints = 0;
            final settings = _ref.read(shopSettingsProvider).value;
            if (settings != null && settings.loyaltyEnabled) {
              final pointsPerAmount = settings.pointsPerAmount;
              if (pointsPerAmount > 0) {
                 // On retire les points seulement sur la partie cash réellement remboursée
                 lostPoints = (actualCashRefund / pointsPerAmount).floor();
              }
            }

            await txn.rawUpdate(
              'UPDATE clients SET total_spent = total_spent - ?, credit = credit - ?, loyalty_points = MAX(0, loyalty_points - ?) WHERE id = ?',
              [refundAmount, amountToCancelDebt, lostPoints, clientId],
            );
          }

          // --- 2. REMBOURSEMENT ARGENT VÉRITABLE ---
          if (actualCashRefund > 0 && accountId != null) {
            // --- STRICT BALANCE CHECK ---
            final accRow = await txn.query('financial_accounts', columns: ['balance', 'name'], where: 'id = ?', whereArgs: [accountId]);
            if (accRow.isNotEmpty) {
              final currentBalance = (accRow.first['balance'] as num).toDouble();
              if (currentBalance < actualCashRefund) {
                final name = accRow.first['name'] as String;
                final settings = _ref.read(shopSettingsProvider).value;
                final currency = settings?.currency ?? 'FCFA';
                throw Exception("Remboursement impossible : Solde insuffisant dans '$name' ($currentBalance $currency disponible). Requis: $actualCashRefund $currency.");
              }
            }

            final tx = FinancialTransaction(
              accountId: accountId,
              type: TransactionType.OUT, // Out because we give money back
              amount: actualCashRefund,
              category: TransactionCategory.REFUND,
              description:
                  "Remb. Retour Vente #${saleId.substring(0, 8).toUpperCase()}",
              date: refundDate,
              referenceId: saleId,
              sessionId: activeSession?.id,
            );
            await txn.insert('financial_transactions', tx.toMap());

            await txn.execute(
              'UPDATE financial_accounts SET balance = balance - ? WHERE id = ?',
              [actualCashRefund, accountId],
            );
          }
        }
      });

      // Log d'audit
      unawaited(_ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'UPDATE',
        entityType: 'SALE',
        entityId: saleId,
        description: "Retour d'articles sur la vente (#${saleId.substring(0, 8).toUpperCase()})",
      ));

      _ref.invalidate(productListProvider);
      _ref.invalidate(clientListProvider);
      _ref.read(treasuryProvider.notifier).refresh();

      // --- SYNCHRO RÉSEAU ---
      try {
        final settings = _ref.read(shopSettingsProvider).value;
        if (settings != null && settings.networkMode == NetworkMode.client) {
          _ref.read(clientSyncProvider).syncPendingAuditData();
        }
      } catch (e) {
        debugPrint('⚠️ Erreur déclenchement synchro retour: $e');
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider that fetches today's sales total from the database
final todaySalesProvider = FutureProvider<double>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final today = DateTime.now();
  final dayStart = DateTime(
    today.year,
    today.month,
    today.day,
  ).toIso8601String();
  final dayEnd = DateTime(
    today.year,
    today.month,
    today.day,
    23,
    59,
    59,
  ).toIso8601String();
  final user = ref.read(authServiceProvider).value;
  final isGlobalRole = user?.role == UserRole.admin || 
                       user?.role == UserRole.manager || 
                       user?.role == UserRole.adminPlus;

  String query = 'SELECT SUM(total_amount) as total FROM sales WHERE date >= ? AND date <= ?';
  List<dynamic> args = [dayStart, dayEnd];

  if (!isGlobalRole && user != null) {
    query += ' AND user_id = ?';
    args.add(user.id);
  }

  final result = await db.rawQuery(query, args);
  return (result.first['total'] as num?)?.toDouble() ?? 0.0;
});

class SelectedClientNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setClient(String? id) => state = id;
}
final selectedClientIdProvider = NotifierProvider<SelectedClientNotifier, String?>(SelectedClientNotifier.new);

/// Provider that fetches the total sales count from the database
final totalSalesCountProvider = FutureProvider<int>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final user = ref.read(authServiceProvider).value;
  final isGlobalRole = user?.role == UserRole.admin || 
                       user?.role == UserRole.manager || 
                       user?.role == UserRole.adminPlus;

  String query = 'SELECT COUNT(*) AS cnt FROM sales';
  List<dynamic> args = [];

  if (!isGlobalRole && user != null) {
    query += ' WHERE user_id = ?';
    args.add(user.id);
  }

  final result = await db.rawQuery(query, args);
  return (result.first['cnt'] as num).toInt();
});
