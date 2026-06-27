import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(databaseServiceProvider));
});

class AuthRepository {
  final DatabaseService _dbService;

  AuthRepository(this._dbService);

  Future<User?> authenticate(String username, String pinHash) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? COLLATE NOCASE AND pin_hash = ? AND is_active = 1',
      whereArgs: [username, pinHash],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return _mapToUser(maps.first);
  }

  Future<List<User>> getAllUsers() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    
    return maps.map((map) => _mapToUser(map)).toList();
  }

  User _mapToUser(Map<String, dynamic> map) {
    final m = Map<String, dynamic>.from(map);
    
    // SQLite booleans (1/0)
    m['is_active'] = m['is_active'] == 1;
    
    // JSON Permissions
    if (m['permissions'] != null && m['permissions'] is String) {
      try {
        m['permissions'] = jsonDecode(m['permissions']);
      } catch (_) {
        m['permissions'] = null; // Let Default work
      }
    }

    // JSON Assigned Accounts
    if (m['assigned_account_ids'] != null && m['assigned_account_ids'] is String) {
      try {
        m['assigned_account_ids'] = jsonDecode(m['assigned_account_ids']);
      } catch (_) {
        m['assigned_account_ids'] = []; // Let Default work
      }
    }

    return User.fromJson(m);
  }
}
