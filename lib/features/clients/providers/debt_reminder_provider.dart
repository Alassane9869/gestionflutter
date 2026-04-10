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
