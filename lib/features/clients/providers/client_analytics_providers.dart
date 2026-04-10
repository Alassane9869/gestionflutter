import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';

final clientProfitProvider = FutureProvider.family<double, String>((ref, clientId) async {
  final db = await ref.read(databaseServiceProvider).database;
  
  // Requête consolidée pour le profit par client (Ventes - Coût Revient)
  // On prend le cost_price capturé, sinon fallback sur le CMUP actuel du produit.
  final result = await db.rawQuery('''
    SELECT SUM(
      ( (si.unit_price * (1.0 - (COALESCE(si.discount_percent, 0.0) / 100.0))) - 
        CASE 
          WHEN COALESCE(si.cost_price, 0.0) > 0 THEN si.cost_price 
          ELSE COALESCE(p.weighted_average_cost, COALESCE(p.purchasePrice, 0.0))
        END
      ) * (si.quantity - COALESCE(si.returned_quantity, 0.0))
    ) as total_profit
    FROM sale_items si
    JOIN sales s ON s.id = si.sale_id
    LEFT JOIN products p ON p.id = si.product_id
    WHERE s.client_id = ?
  ''', [clientId]);

  return (result.first['total_profit'] as num?)?.toDouble() ?? 0.0;
});
