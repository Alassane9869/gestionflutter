import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/pos/domain/models/sale.dart';

import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

class SaleWithDetails {
  final Sale sale;
  final String? clientName;
  final List<SaleItemWithProduct> items;

  SaleWithDetails({required this.sale, this.clientName, required this.items});
}

class SaleItemWithProduct {
  final SaleItem item;
  final String productName;

  SaleItemWithProduct({required this.item, required this.productName});
}

final salesHistoryProvider = FutureProvider<List<SaleWithDetails>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final user = ref.read(authServiceProvider).value;
  final isGlobalRole = user?.role == UserRole.admin || 
                       user?.role == UserRole.manager || 
                       user?.role == UserRole.adminPlus;

  String query = '''
    SELECT s.*, c.name as client_name 
    FROM sales s 
    LEFT JOIN clients c ON s.client_id = c.id 
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

    final List<Map<String, dynamic>> itemsData = await db.rawQuery('''
      SELECT si.*, p.name as product_name 
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [sale.id]);

    List<SaleItemWithProduct> items = [];
    for (var itemRow in itemsData) {
      items.add(SaleItemWithProduct(
        item: SaleItem.fromMap(itemRow),
        productName: itemRow['product_name'] as String,
      ));
    }

    result.add(SaleWithDetails(sale: sale, clientName: clientName, items: items));
  }

  return result;
});
