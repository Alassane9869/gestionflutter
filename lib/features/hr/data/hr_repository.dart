import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/features/hr/domain/models/payroll.dart';
import 'package:danaya_plus/features/hr/domain/models/leave_request.dart';
import 'package:danaya_plus/features/hr/domain/models/hr_stats.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:uuid/uuid.dart';

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return HrRepository(ref.watch(databaseServiceProvider));
});

final userContractsProvider = FutureProvider.family<List<EmployeeContract>, String>((ref, userId) async {
  return ref.watch(hrRepositoryProvider).getContractsForUser(userId);
});

final allContractsProvider = FutureProvider<List<EmployeeContract>>((ref) async {
  return ref.watch(hrRepositoryProvider).getAllContracts();
});

final userPayrollsProvider = FutureProvider.family<List<Payroll>, String>((ref, userId) async {
  return ref.watch(hrRepositoryProvider).getPayrollsForUser(userId);
});

final allPayrollsProvider = FutureProvider<List<Payroll>>((ref) async {
  return ref.watch(hrRepositoryProvider).getAllPayrolls();
});

final userLeavesProvider = FutureProvider.family<List<LeaveRequest>, String>((ref, userId) async {
  return ref.watch(hrRepositoryProvider).getLeaveRequestsForUser(userId);
});

final allLeavesProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  return ref.watch(hrRepositoryProvider).getAllLeaveRequests();
});

final hrStatsProvider = FutureProvider<HrStats>((ref) async {
  final users = await ref.watch(userListProvider.future);
  final contracts = await ref.watch(allContractsProvider.future);
  final payrolls = await ref.watch(allPayrollsProvider.future);
  final leaves = await ref.watch(allLeavesProvider.future);

  final now = DateTime.now();
  final currentMonth = now.month;
  final currentYear = now.year;

  final monthlyPayrollSum = payrolls
      .where((p) => p.month == currentMonth && p.year == currentYear)
      .fold(0.0, (sum, p) => sum + p.netSalary);

  return HrStats(
    totalEmployees: users.length,
    activeContracts: contracts.where((c) => c.status == ContractStatus.active).length,
    monthlyPayrollSum: monthlyPayrollSum,
    pendingLeaves: leaves.where((l) => l.status == LeaveStatus.pending).length,
    expiringContractsCount: contracts.where((c) => c.status == ContractStatus.active && (c.endDate != null && c.endDate!.difference(now).inDays <= 30)).length,
  );
});

class HrRepository {
  final DatabaseService _dbService;
  HrRepository(this._dbService);

  // --- CONTRACTS ---
  Future<void> saveContract(EmployeeContract contract) async {
    final db = await _dbService.database;
    await db.insert(
      'employee_contracts',
      _toSqlMap(contract.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<EmployeeContract>> getContractsForUser(String userId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employee_contracts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date DESC',
    );

    return List.generate(maps.length, (i) {
      return EmployeeContract.fromJson(_fromSqlMap(maps[i]));
    });
  }

  Future<List<EmployeeContract>> getAllContracts() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employee_contracts',
      orderBy: 'start_date DESC',
    );

    return List.generate(maps.length, (i) {
      return EmployeeContract.fromJson(_fromSqlMap(maps[i]));
    });
  }

  Future<void> deleteContract(String id) async {
    final db = await _dbService.database;
    await db.delete('employee_contracts', where: 'id = ?', whereArgs: [id]);
  }

  // --- PAYROLL ---
  Future<void> savePayroll(Payroll payroll) async {
    final db = await _dbService.database;
    await db.insert(
      'payrolls',
      _toSqlMap({
        ...payroll.toJson(),
        'extra_lines': jsonEncode(payroll.extraLines.map((e) => e.toJson()).toList()),
      }),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> savePayrollWithTreasury({
    required Payroll payroll,
    required String accountId,
  }) async {
    final db = await _dbService.database;
    
    await db.transaction((txn) async {
      // 1. Sauvegarder la paie
      await txn.insert(
        'payrolls',
        _toSqlMap({
          ...payroll.toJson(),
          'extra_lines': jsonEncode(payroll.extraLines.map((e) => e.toJson()).toList()),
        }),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Si c'est déjà payé, on déduit de la trésorerie
      if (payroll.status == PayrollStatus.paid) {
        // Vérifier le solde
        final List<Map<String, dynamic>> accountMaps = await txn.query(
          'financial_accounts',
          where: 'id = ?',
          whereArgs: [accountId],
        );
        
        if (accountMaps.isEmpty) throw Exception("Compte introuvable");
        final double currentBalance = (accountMaps.first['balance'] as num).toDouble();
        
        if (currentBalance < payroll.netSalary) {
          throw Exception("Solde insuffisant sur ce compte pour payer le salaire (${payroll.netSalary} FCFA).");
        }

        // Déduire le montant
        await txn.update(
          'financial_accounts',
          {'balance': currentBalance - payroll.netSalary},
          where: 'id = ?',
          whereArgs: [accountId],
        );

        // Créer la transaction financière
        await txn.insert('financial_transactions', {
          'id': const Uuid().v4(),
          'account_id': accountId,
          'type': 'OUT',
          'amount': payroll.netSalary,
          'category': 'SALARY',
          'description': "Salaire de ${payroll.periodLabel} pour ${payroll.userId}",
          'date': DateTime.now().toIso8601String(),
          'reference_id': payroll.id,
          'is_synced': 0,
        });
      }
    });
  }

  Future<List<Payroll>> getAllPayrolls() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payrolls',
      orderBy: 'year DESC, month DESC',
    );

    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      try {
        final extraRaw = map['extra_lines'];
        if (extraRaw is String && extraRaw.isNotEmpty) {
          map['extra_lines'] = jsonDecode(extraRaw);
        } else {
          map['extra_lines'] = [];
        }
      } catch (e) {
        debugPrint("HR Repository: Failed to parse extra_lines for payroll ${map['id']}: $e");
        map['extra_lines'] = [];
      }
      return Payroll.fromJson(_fromSqlMap(map));
    });
  }

  Future<List<Payroll>> getPayrollsForUser(String userId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payrolls',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'year DESC, month DESC',
    );

    return List.generate(maps.length, (i) {
      final map = Map<String, dynamic>.from(maps[i]);
      try {
        final extraRaw = map['extra_lines'];
        if (extraRaw is String && extraRaw.isNotEmpty) {
          map['extra_lines'] = jsonDecode(extraRaw);
        } else {
          map['extra_lines'] = [];
        }
      } catch (e) {
        debugPrint("HR Repository: Failed to parse user extra_lines: $e");
        map['extra_lines'] = [];
      }
      return Payroll.fromJson(_fromSqlMap(map));
    });
  }

  // --- LEAVE REQUESTS ---
  Future<void> saveLeaveRequest(LeaveRequest request) async {
    final db = await _dbService.database;
    await db.insert(
      'leave_requests',
      _toSqlMap(request.toJson()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LeaveRequest>> getAllLeaveRequests() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'leave_requests',
      orderBy: 'start_date DESC',
    );

    return List.generate(maps.length, (i) {
      return LeaveRequest.fromJson(_fromSqlMap(maps[i]));
    });
  }

  Future<List<LeaveRequest>> getLeaveRequestsForUser(String userId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'leave_requests',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_date DESC',
    );

    return List.generate(maps.length, (i) {
      return LeaveRequest.fromJson(_fromSqlMap(maps[i]));
    });
  }

  // --- USER PROFILE UPDATES ---
  Future<void> updateUserHRProfile(User user) async {
    final db = await _dbService.database;
    await db.update(
      'users',
      _toSqlMap({
        'email': user.email,
        'phone': user.phone,
        'address': user.address,
        'birth_date': user.birthDate,
        'hire_date': user.hireDate,
        'nationality': user.nationality,
        'permissions': jsonEncode(user.permissions.toJson()),
      }),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // Helper to ensure dates and booleans are in the correct format for SQL
  Map<String, dynamic> _toSqlMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is bool) {
        result[key] = value ? 1 : 0;
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Map<String, dynamic> _fromSqlMap(Map<String, dynamic> map) {
    final newMap = Map<String, dynamic>.from(map);
    
    // Convert SQLite integers (0/1) back to booleans for freezed models
    newMap.forEach((key, value) {
      if (value is int && (key == 'printed' || key.startsWith('is_'))) {
        newMap[key] = value == 1;
      }
    });

    return newMap;
  }
}
