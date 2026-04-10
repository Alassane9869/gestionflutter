import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

final userListProvider = FutureProvider<List<User>>((ref) async {
  final db = await ref.watch(databaseServiceProvider).database;
  final maps = await db.query('users', orderBy: 'username ASC');
  return maps.map((m) {
    final map = Map<String, dynamic>.from(m);
    
    // SQLite stores booleans as INTEGER (0/1).
    map['is_active'] = map['is_active'] == 1;
    
    // JSON Permissions
    if (map['permissions'] != null && map['permissions'] is String) {
      try {
        map['permissions'] = jsonDecode(map['permissions']);
      } catch (_) {
        map['permissions'] = null;
      }
    }
    
    // JSON Assigned Account IDs
    if (map['assigned_account_ids'] != null && map['assigned_account_ids'] is String) {
      try {
        List<dynamic> parsed = jsonDecode(map['assigned_account_ids']);
        map['assigned_account_ids'] = parsed.map((e) => e.toString()).toList();
      } catch (_) {
        map['assigned_account_ids'] = [];
      }
    }
    
    return User.fromJson(map);
  }).toList();
});

final userManagementServiceProvider = Provider<UserManagementService>((ref) {
  return UserManagementService(ref);
});

class UserManagementService {
  final Ref _ref;

  UserManagementService(this._ref);
  
  Future<void> _ensureUniqueness(User user, {String? excludeId}) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    // Vérification de l'identifiant (Username)
    final sameUsername = await db.query(
      'users', 
      where: 'username = ? AND id != ?', 
      whereArgs: [user.username, excludeId ?? '']
    );
    if (sameUsername.isNotEmpty) {
      throw Exception("L'identifiant '${user.username}' est déjà utilisé par un autre employé.");
    }

    // Vérification du Téléphone (si renseigné)
    if (user.phone != null && user.phone!.trim().isNotEmpty) {
      final samePhone = await db.query(
        'users', 
        where: 'phone = ? AND id != ?', 
        whereArgs: [user.phone!.trim(), excludeId ?? '']
      );
      if (samePhone.isNotEmpty) {
        throw Exception("Le numéro de téléphone '${user.phone}' est déjà attribué à un autre compte.");
      }
    }
  }

  Future<void> createUser(User user) async {
    final db = await _ref.read(databaseServiceProvider).database;
    if (user.id == 'sysadmin') {
      throw Exception("L'identifiant 'sysadmin' est réservé au système.");
    }
    
    await _ensureUniqueness(user);
    
    await db.insert('users', _prepareForDb(user));
    _ref.invalidate(userListProvider);
  }

  Future<void> updateUser(User user) async {
    final db = await _ref.read(databaseServiceProvider).database;
    
    // Hardened Security for sysadmin
    User userToSave = user;
    if (user.id == 'sysadmin') {
      userToSave = user.copyWith(
        role: UserRole.admin,
        isActive: true,
      );
    } else {
      await _ensureUniqueness(user, excludeId: user.id);
    }
    
    await db.update('users', _prepareForDb(userToSave), where: 'id = ?', whereArgs: [userToSave.id]);
    _ref.invalidate(userListProvider);
  }

  Map<String, dynamic> _prepareForDb(User user) {
    final json = user.toJson();
    
    // Convert bool to int for SQLite
    json['is_active'] = (json['is_active'] == true) ? 1 : 0;
    
    // Convert Permissions to JSON String
    json['permissions'] = jsonEncode(user.permissions.toJson());
    
    // Convert Assigned Accounts to JSON String
    json['assigned_account_ids'] = jsonEncode(user.assignedAccountIds);
    
    // Ensure dates are strings (toJson already does this if configured, but let's be safe)
    if (user.birthDate != null) json['birth_date'] = user.birthDate!.toIso8601String();
    if (user.hireDate != null) json['hire_date'] = user.hireDate!.toIso8601String();
    
    return json;
  }

  Future<void> deleteUser(String id) async {
    final db = await _ref.read(databaseServiceProvider).database;
    if (id == 'sysadmin') {
      throw Exception("Vous ne pouvez pas supprimer l'administrateur principal.");
    }
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
    _ref.invalidate(userListProvider);
  }
}
