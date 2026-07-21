import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/pos/domain/models/sale.dart';

/// Provider that identifies overdue credit sales.
final overdueDebtsProvider = FutureProvider<List<Sale>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final now = DateTime.now().toIso8601String();
  
  // Fetch sales that are credits, have remaining balance, and are past due date
  final result = await db.query(
    'sales',
    where: 'is_credit = 1 AND (total_amount - amount_paid) > 0 AND due_date IS NOT NULL AND due_date <= ?',
    whereArgs: [now],
  );
  
  return result.map((m) => Sale.fromMap(m)).toList();
});

/// Provider that identifies debts due in the next 3 days (approaching).
final approachingDebtsProvider = FutureProvider<List<Sale>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final now = DateTime.now();
  final threeDaysLater = now.add(const Duration(days: 3)).toIso8601String();
  final nowStr = now.toIso8601String();
  
  final result = await db.query(
    'sales',
    where: 'is_credit = 1 AND (total_amount - amount_paid) > 0 AND due_date IS NOT NULL AND due_date > ? AND due_date <= ?',
    whereArgs: [nowStr, threeDaysLater],
  );
  
  return result.map((m) => Sale.fromMap(m)).toList();
});

Future<void> healClientSalesDebt(String clientId, dynamic db) async {
  // 1. Reset all credit sales to initial checkout paid amount
  await db.rawUpdate('''
    UPDATE sales 
    SET amount_paid = total_amount - credit_amount 
    WHERE client_id = ? AND is_credit = 1
  ''', [clientId]);

  // 2. Fetch all payments made by this client
  final payments = await db.query(
    'client_payments',
    columns: ['amount'],
    where: 'client_id = ?',
    whereArgs: [clientId],
    orderBy: 'date ASC',
  );

  double totalPayments = payments.fold(0.0, (sum, row) => sum + (row['amount'] as num).toDouble());

  // 3. Fetch all credit sales for this client
  final sales = await db.query(
    'sales',
    columns: ['id', 'total_amount', 'amount_paid'],
    where: 'client_id = ? AND is_credit = 1',
    whereArgs: [clientId],
    orderBy: 'date ASC',
  );

  double remainingPayment = totalPayments;
  for (final saleRow in sales) {
    if (remainingPayment <= 0) break;

    final saleId = saleRow['id'] as String;
    final totalAmount = (saleRow['total_amount'] as num).toDouble();
    final amountPaid = (saleRow['amount_paid'] as num).toDouble();
    final unpaidAmount = totalAmount - amountPaid;

    if (unpaidAmount <= 0) continue;

    final double allocation = remainingPayment >= unpaidAmount ? unpaidAmount : remainingPayment;

    await db.rawUpdate(
      'UPDATE sales SET amount_paid = amount_paid + ? WHERE id = ?',
      [allocation, saleId],
    );

    remainingPayment -= allocation;
  }
}

/// Provider that fetches all active unpaid debts (credit sales) for a specific client.
final clientActiveDebtsProvider = FutureProvider.family<List<Sale>, String>((ref, clientId) async {
  final db = await ref.read(databaseServiceProvider).database;
  
  // HEAL FIRST: Sync sales amount_paid with client payments history!
  await healClientSalesDebt(clientId, db);
  
  final result = await db.query(
    'sales',
    where: 'client_id = ? AND is_credit = 1 AND (total_amount - amount_paid) > 0',
    whereArgs: [clientId],
    orderBy: 'due_date ASC',
  );
  
  return result.map((m) => Sale.fromMap(m)).toList();
});

/// Provider that fetches all credit sales (both active and settled) for a specific client.
final clientAllCreditSalesProvider = FutureProvider.family<List<Sale>, String>((ref, clientId) async {
  final db = await ref.read(databaseServiceProvider).database;
  
  // HEAL FIRST
  await healClientSalesDebt(clientId, db);
  
  final result = await db.query(
    'sales',
    where: 'client_id = ? AND is_credit = 1',
    whereArgs: [clientId],
    orderBy: 'date DESC',
  );
  
  return result.map((m) => Sale.fromMap(m)).toList();
});
