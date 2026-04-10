import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/pos/services/quote_service.dart';
import 'package:uuid/uuid.dart';

class QuoteRepository {
  final DatabaseService _dbService;

  QuoteRepository(this._dbService);

  Future<List<Map<String, dynamic>>> getAllQuotes() async {
    final db = await _dbService.database;
    final quotes = await db.query('quotes', orderBy: 'date DESC');

    List<Map<String, dynamic>> result = [];
    for (var quote in quotes) {
      final items = await db.query(
        'quote_items',
        where: 'quote_id = ?',
        whereArgs: [quote['id']],
      );
      final client = quote['client_id'] != null
          ? (await db.query(
              'clients',
              where: 'id = ?',
              whereArgs: [quote['client_id']],
            )).firstOrNull
          : null;

      result.add({...quote, 'items': items, 'client': client});
    }
    return result;
  }

  Future<String> createQuote({
    required String? clientId,
    required List<QuoteItem> items,
    required double subtotal,
    required double totalAmount,
    required String userId,
    DateTime? validUntil,
    String? productId,
  }) async {
    final db = await _dbService.database;
    final quoteId = const Uuid().v4();
    final quoteNumber =
        "DEV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    await db.transaction((txn) async {
      await txn.insert('quotes', {
        'id': quoteId,
        'quote_number': quoteNumber,
        'client_id': clientId,
        'date': DateTime.now().toIso8601String(),
        'valid_until': validUntil?.toIso8601String(),
        'subtotal': subtotal,
        'total_amount': totalAmount,
        'status': 'PENDING',
        'user_id': userId,
      });

      for (var item in items) {
        await txn.insert('quote_items', {
          'id': const Uuid().v4(),
          'quote_id': quoteId,
          'product_id': item is QuoteItemWithId ? item.productId : null,
          'custom_name': item.name,
          'quantity': item.qty,
          'unit_price': item.unitPrice,
          'unit': item.unit,
          'description': item.description,
          'discount_amount': item.discountAmount,
        });
      }
    });

    return quoteId;
  }

  Future<void> updateQuote({
    required String quoteId,
    required String? clientId,
    required List<QuoteItem> items,
    required double subtotal,
    required double totalAmount,
    DateTime? validUntil,
  }) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.update(
        'quotes',
        {
          'client_id': clientId,
          'valid_until': validUntil?.toIso8601String(),
          'subtotal': subtotal,
          'total_amount': totalAmount,
        },
        where: 'id = ?',
        whereArgs: [quoteId],
      );

      await txn.delete(
        'quote_items',
        where: 'quote_id = ?',
        whereArgs: [quoteId],
      );
      for (var item in items) {
        await txn.insert('quote_items', {
          'id': const Uuid().v4(),
          'quote_id': quoteId,
          'product_id': item is QuoteItemWithId ? item.productId : null,
          'custom_name': item.name,
          'quantity': item.qty,
          'unit_price': item.unitPrice,
          'unit': item.unit,
          'description': item.description,
          'discount_amount': item.discountAmount,
        });
      }
    });
  }

  Future<void> updateQuoteStatus(String quoteId, String status) async {
    final db = await _dbService.database;
    await db.update(
      'quotes',
      {'status': status},
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }

  Future<void> deleteQuote(String id) async {
    final db = await _dbService.database;
    await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }
}

// Subclass to handle product links
class QuoteItemWithId extends QuoteItem {
  final String? productId;
  const QuoteItemWithId({
    required super.name,
    required super.qty,
    required super.unitPrice,
    super.unit,
    super.description,
    super.discountAmount = 0,
    this.productId,
  });

  @override
  QuoteItemWithId copyWith({
    String? name,
    double? qty,
    double? unitPrice,
    String? unit,
    String? description,
    double? discountAmount,
    String? productId,
  }) {
    return QuoteItemWithId(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      discountAmount: discountAmount ?? this.discountAmount,
      productId: productId ?? this.productId,
    );
  }
}

final quoteRepositoryProvider = Provider((ref) {
  return QuoteRepository(ref.watch(databaseServiceProvider));
});

final quoteListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(quoteRepositoryProvider).getAllQuotes();
});
