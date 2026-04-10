import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/domain/models/loyalty_settings.dart';

final loyaltySettingsProvider = FutureProvider<LoyaltySettings>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final List<Map<String, dynamic>> maps = await db.query('loyalty_settings', limit: 1);
  if (maps.isEmpty) {
    return LoyaltySettings(
      id: 'default_loyalty',
      pointsPerAmount: 1000.0,
      amountPerPoint: 10.0,
      isEnabled: true,
    );
  }
  return LoyaltySettings.fromMap(maps.first);
});

final loyaltyActionsProvider = Provider((ref) => LoyaltyActions(ref));

class LoyaltyActions {
  final Ref ref;
  LoyaltyActions(this.ref);

  Future<void> updateSettings(LoyaltySettings settings) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.update(
      'loyalty_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );
    ref.invalidate(loyaltySettingsProvider);
  }
}
