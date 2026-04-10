import 'package:flutter_test/flutter_test.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';

void main() {
  group('Product Model Logic Tests', () {
    test('Should calculate margin correctly without weighted average cost', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        purchasePrice: 1000,
        sellingPrice: 1500,
      );

      expect(product.margin, 500);
      expect(product.marginPercent, 50.0);
    });

    test('Should prioritize weighted average cost for margin calculation', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        purchasePrice: 1000,
        sellingPrice: 1500,
        weightedAverageCost: 1200,
      );

      expect(product.margin, 300);
      expect(product.marginPercent, 25.0);
    });

    test('Should calculate total stock value correctly', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        purchasePrice: 1000,
        quantity: 10,
      );

      expect(product.stockValue, 10000);
    });

    test('Should identify low stock correctly', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        quantity: 3,
        alertThreshold: 5,
      );

      expect(product.isLowStock, true);
      expect(product.isOutOfStock, false);
    });

    test('Should identify out of stock correctly', () {
      final product = Product(
        id: '1',
        name: 'Test Product',
        quantity: 0,
      );

      expect(product.isOutOfStock, true);
      expect(product.isLowStock, false);
    });
  });
}
