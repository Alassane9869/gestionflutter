import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(databaseServiceProvider));
});

class SupplierRepository {
  final DatabaseService _dbService;

  SupplierRepository(this._dbService);

  Future<void> insert(Supplier supplier) async {
    final db = await _dbService.database;
    await db.insert('suppliers', supplier.toMap());
  }

  Future<void> update(Supplier supplier) async {
    final db = await _dbService.database;
    await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbService.database;
    
    // Empêcher la suppression si des commandes d'achat existent (ON DELETE CASCADE les détruirait)
    final orderCount = await db.rawQuery(
      'SELECT COUNT(*) as count FROM purchase_orders WHERE supplier_id = ?',
      [id],
    );
    final count = orderCount.first['count'] as int;
    if (count > 0) {
      throw Exception('Ce fournisseur a $count commande(s) d\'achat enregistrée(s). Supprimer ce fournisseur détruirait tout cet historique.');
    }

    await db.delete(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Supplier>> getAll() async {
    final db = await _dbService.database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<Supplier?> getById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Supplier.fromMap(maps.first);
    }
    return null;
  }
}
