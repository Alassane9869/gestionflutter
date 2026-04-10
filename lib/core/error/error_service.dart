import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database_service.dart';

final errorServiceProvider = Provider<ErrorService>((ref) {
  return ErrorService(ref);
});

class ErrorService {
  final Ref _ref;
  ErrorService(this._ref);

  Future<void> logError(Object error, {StackTrace? stackTrace, String? context}) async {
    try {
      final db = await _ref.read(databaseServiceProvider).database;
      await db.insert('internal_errors', {
        'id': const Uuid().v4(),
        'error_message': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'context': context,
        'date': DateTime.now().toIso8601String(),
        'is_resolved': 0,
      });
    } catch (e) {
      // Éviter la boucle infinie si la DB elle-même crash
      debugPrint("CRITICAL: Error logging failed: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getUnresolvedErrors() async {
    final db = await _ref.read(databaseServiceProvider).database;
    return await db.query(
      'internal_errors',
      where: 'is_resolved = 0',
      orderBy: 'date DESC',
    );
  }

  Future<void> resolveError(String id) async {
    final db = await _ref.read(databaseServiceProvider).database;
    await db.update(
      'internal_errors',
      {'is_resolved': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
