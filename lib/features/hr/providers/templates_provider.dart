import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/services/hr_templates.dart';

class TemplatesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return _loadTemplates();
  }

  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    final dbService = ref.read(databaseServiceProvider);
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'hr_templates',
      where: 'is_system = 0',
      orderBy: 'title ASC',
    );
    
    final List<Map<String, dynamic>> staticModels = [];
    int counter = 1;
    for (var entry in HrTemplates.allContracts.entries) {
      staticModels.add({
        'id': 'S_MOD_$counter',
        'title': entry.key,
        'category': 'contract',
        'content': entry.value,
        'is_system': 1,
      });
      counter++;
    }
    return [...staticModels, ...maps];
  }

  Future<String> saveTemplate(String? id, String title, String htmlContent) async {
    final dbService = ref.read(databaseServiceProvider);
    final db = await dbService.database;
    final now = DateTime.now().toIso8601String();
    
    if (id != null && id.startsWith("P:")) {
      await db.update(
        'hr_templates',
        {'title': title, 'content': htmlContent, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _loadTemplates());
      return id;
    } else {
      final newId = "P:${const Uuid().v4()}";
      await db.insert('hr_templates', {
        'id': newId,
        'title': title,
        'category': 'contract',
        'content': htmlContent,
        'is_system': 0,
        'created_at': now,
        'updated_at': now,
      });
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _loadTemplates());
      return newId;
    }
  }

  Future<void> deleteTemplate(String id) async {
    if (!id.startsWith("P:")) return;
    final dbService = ref.read(databaseServiceProvider);
    final db = await dbService.database;
    await db.delete('hr_templates', where: 'id = ?', whereArgs: [id]);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadTemplates());
  }
}

final templatesProvider = AsyncNotifierProvider<TemplatesNotifier, List<Map<String, dynamic>>>(() {
  return TemplatesNotifier();
});
