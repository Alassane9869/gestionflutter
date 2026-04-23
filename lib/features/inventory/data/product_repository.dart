import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseServiceProvider), ref);
});

class ProductRepository {
  final DatabaseService _dbService;
  final Ref _ref;
  static const _uuid = Uuid();

  ProductRepository(this._dbService, this._ref);

  Future<List<Product>> getAll({String? warehouseId, bool includeArchived = false}) async {
    final db = await _dbService.database;
    
    if (warehouseId == null) {
      final maps = await db.query(
        'products', 
        where: includeArchived ? null : 'is_active = 1',
        orderBy: 'name ASC',
      );
      return maps.map((m) => Product.fromMap(m)).toList();
    } else {
      final maps = await db.rawQuery('''
        SELECT p.*, COALESCE(ws.quantity, 0) as warehouse_qty
        FROM products p
        LEFT JOIN warehouse_stock ws ON p.id = ws.product_id AND ws.warehouse_id = ?
        ${includeArchived ? '' : 'WHERE p.is_active = 1'}
        ORDER BY p.name ASC
      ''', [warehouseId]);
      return maps.map((m) {
        final p = Product.fromMap(m);
        return p.copyWith(quantity: (m['warehouse_qty'] as num?)?.toDouble() ?? 0.0);
      }).toList();
    }
  }

  Future<Product?> getById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<void> insert(Product product, {String? warehouseId}) async {
    final db = await _dbService.database;
    final productId = product.id.isEmpty ? _uuid.v4() : product.id;
    final p = product.copyWith(id: productId);
    
    await db.insert('products', p.toMap());

    // Assigner le stock initial à l'entrepôt
    final targetWarehouse = warehouseId ?? 'default_warehouse';
    await db.insert('warehouse_stock', {
      'id': _uuid.v4(),
      'warehouse_id': targetWarehouse,
      'product_id': productId,
      'quantity': p.quantity,
    });

    // Audit log (Ultra Pro)
    final currentUser = _ref.read(authServiceProvider).value;
    unawaited(_dbService.logActivity(
      userId: currentUser?.id,
      actionType: 'PRODUCT_CREATE',
      entityType: 'PRODUCT',
      entityId: productId,
      description: "Ajout du produit ${p.name} (Ref: ${p.reference})",
    ));
  }

  Future<void> update(Product product) async {
    final db = await _dbService.database;
    
    // Supreme Audit: Asset Lifecycle Management
    final oldProduct = await getById(product.id);
    final oldImagePath = oldProduct?.imagePath;

    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);

    // Cleanup old image if it was replaced
    if (oldImagePath != null && oldImagePath != product.imagePath && !oldImagePath.startsWith('assets/')) {
      try {
        final file = File(oldImagePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Supreme Asset Manager: Old image deleted ($oldImagePath)');
        }
      } catch (e) {
        debugPrint('⚠️ Supreme Asset Manager Error: $e');
      }
    }

    // Log d'audit
    final currentUser = _ref.read(authServiceProvider).value;
    unawaited(_dbService.logActivity(
      userId: currentUser?.id,
      actionType: 'PRODUCT_UPDATE',
      entityType: 'PRODUCT',
      entityId: product.id,
      description: "Modification du produit ${product.name} (Ref: ${product.reference})",
      metadata: {
        'name': product.name,
        'price': product.sellingPrice,
        'qty': product.quantity,
        'image_changed': oldImagePath != product.imagePath,
      },
    ));
  }

  Future<void> delete(String id) async {
    final db = await _dbService.database;

    // PROTECTION: Ne pas supprimer si historique présent
    final saleCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM sale_items WHERE product_id = ?',
      [id],
    )) ?? 0;

    final movementCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM stock_movements WHERE product_id = ?',
      [id],
    )) ?? 0;

    if (saleCount > 0 || movementCount > 0) {
      // Logic Pro: On archive au lieu de supprimer si historique présent
      await archive(id);
      return;
    }

    // Récupérer les infos avant suppression
    final product = await getById(id);
    final productName = product?.name ?? id;
    final imagePath = product?.imagePath;

    await db.delete('products', where: 'id = ?', whereArgs: [id]);

    // Supprimer l'image du disque si elle existe
    if (imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Erreur suppression image produit: $e");
      }
    }

    // Log d'audit
    final currentUser = _ref.read(authServiceProvider).value;
    unawaited(_dbService.logActivity(
      userId: currentUser?.id,
      actionType: 'PRODUCT_DELETE',
      entityType: 'PRODUCT',
      entityId: id,
      description: "Suppression définitive du produit $productName",
    ));
  }

  Future<void> archive(String id) async {
    final db = await _dbService.database;
    final product = await getById(id);
    if (product == null) return;

    await db.update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);

    // Log d'audit
    final currentUser = _ref.read(authServiceProvider).value;
    unawaited(_dbService.logActivity(
      userId: currentUser?.id,
      actionType: 'PRODUCT_ARCHIVE',
      entityType: 'PRODUCT',
      entityId: id,
      description: "Archivage du produit ${product.name}",
    ));
  }

  Future<List<Product>> search(String query, {String? warehouseId, bool includeArchived = false}) async {
    final db = await _dbService.database;
    
    // Supreme Performance: Use FTS5 MATCH for ultra-fast multi-criteria search
    // We escape the query for safety and use '*' for prefix matching
    final cleanQuery = query.replaceAll("'", "''");
    final ftsQuery = "$cleanQuery*";

    if (warehouseId == null) {
      final maps = await db.rawQuery('''
        SELECT p.* 
        FROM products p
        JOIN products_fts fts ON p.id = fts.id
        WHERE products_fts MATCH ? ${includeArchived ? '' : 'AND p.is_active = 1'}
        ORDER BY rank, p.name ASC
      ''', [ftsQuery]);
      return maps.map((m) => Product.fromMap(m)).toList();
    } else {
      final maps = await db.rawQuery('''
        SELECT p.*, COALESCE(ws.quantity, 0) as warehouse_qty
        FROM products p
        JOIN products_fts fts ON p.id = fts.id
        LEFT JOIN warehouse_stock ws ON p.id = ws.product_id AND ws.warehouse_id = ?
        WHERE products_fts MATCH ? ${includeArchived ? '' : 'AND p.is_active = 1'}
        ORDER BY rank, p.name ASC
      ''', [warehouseId, ftsQuery]);
      return maps.map((m) {
        final p = Product.fromMap(m);
        return p.copyWith(quantity: (m['warehouse_qty'] as num?)?.toDouble() ?? 0.0);
      }).toList();
    }
  }

  Future<List<String>> getCategories() async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != "" ORDER BY category ASC');
    return maps.map((m) => m['category'] as String).toList();
  }
}
