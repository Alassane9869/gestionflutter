import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/pos/domain/models/sale.dart';

import 'package:danaya_plus/features/auth/application/auth_service.dart';

class SaleWithDetails {
  final Sale sale;
  final String? clientName;
  final String? userName;
  final String? refundedByUserName;
  final List<SaleItemWithProduct> items;

  SaleWithDetails({required this.sale, this.clientName, this.userName, this.refundedByUserName, required this.items});
}

class SaleItemWithProduct {
  final SaleItem item;
  final String productName;

  SaleItemWithProduct({required this.item, required this.productName});
}

final salesHistoryProvider = FutureProvider<List<SaleWithDetails>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final user = ref.read(authServiceProvider).value;
  final isGlobalRole = user?.canViewGlobalSalesHistory ?? false;

  String query = '''
    SELECT s.*, c.name as client_name, u.username as user_name, ru.username as refunded_by_user_name 
    FROM sales s 
    LEFT JOIN clients c ON s.client_id = c.id 
    LEFT JOIN users u ON s.user_id = u.id
    LEFT JOIN users ru ON s.refunded_by_user_id = ru.id
''';
  List<dynamic> args = [];

  if (!isGlobalRole && user != null) {
    query += ' WHERE s.user_id = ?';
    args.add(user.id);
  }

  query += ' ORDER BY s.date DESC LIMIT 100';

  final List<Map<String, dynamic>> salesData = await db.rawQuery(query, args);

  List<SaleWithDetails> result = [];

  for (var row in salesData) {
    final sale = Sale.fromMap(row);
    final clientName = row['client_name'] as String?;
    final userName = row['user_name'] as String?;

    final List<Map<String, dynamic>> itemsData = await db.rawQuery('''
      SELECT si.*, p.name as product_name 
      FROM sale_items si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [sale.id]);

    List<SaleItemWithProduct> items = [];
    for (var itemRow in itemsData) {
      final saleItem = SaleItem.fromMap(itemRow);
      final name = itemRow['product_name'] as String? ?? saleItem.description ?? 'Article';
      items.add(SaleItemWithProduct(
        item: saleItem,
        productName: name,
      ));
    }

    final refundedByUserName = row['refunded_by_user_name'] as String?;

    result.add(SaleWithDetails(sale: sale, clientName: clientName, userName: userName, refundedByUserName: refundedByUserName, items: items));
  }

  return result;
});

class SalesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String val) => state = val;
}
final salesSearchQueryProvider = NotifierProvider<SalesSearchQueryNotifier, String>(SalesSearchQueryNotifier.new);

class SalesStatusFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';
  void update(String val) => state = val;
}
final salesStatusFilterProvider = NotifierProvider<SalesStatusFilterNotifier, String>(SalesStatusFilterNotifier.new);

class SalesPaymentFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';
  void update(String val) => state = val;
}
final salesPaymentFilterProvider = NotifierProvider<SalesPaymentFilterNotifier, String>(SalesPaymentFilterNotifier.new);
