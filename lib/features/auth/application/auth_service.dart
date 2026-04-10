import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/auth/data/auth_repository.dart';
import 'package:danaya_plus/core/services/sound_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/core/database/database_service.dart';

final authServiceProvider = AsyncNotifierProvider<AuthService, User?>(() {
  return AuthService();
});

class AuthService extends AsyncNotifier<User?> {
  late final AuthRepository _repository;
  // SECURITY NOTE (#5): Ce pepper devrait idéalement être stocké dans un secure storage
  // natif (Keychain/Keystore) au lieu d'être hardcodé. Acceptable pour un logiciel offline.
  static const String _pepper = "danaya_secure_pepper_2024_v1";

  // Rate limiting (#6)
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  User? _originalAdmin;

  @override
  FutureOr<User?> build() {
    _repository = ref.read(authRepositoryProvider);
    return null;
  }

  bool get isImpersonating => _originalAdmin != null;
  User? get originalAdmin => _originalAdmin;

  Future<void> impersonate(User targetUser) async {
    final currentAdmin = state.value;
    if (currentAdmin == null || currentAdmin.role != UserRole.admin) {
      throw Exception("Seul un administrateur peut utiliser le mode impersonnant.");
    }

    _originalAdmin = currentAdmin;
    state = AsyncData(targetUser);

    unawaited(ref.read(databaseServiceProvider).logActivity(
      userId: _originalAdmin!.id,
      actionType: 'IMPERSONATION_START',
      description: "L'admin ${_originalAdmin!.username} incarne ${targetUser.username}",
    ));
  }

  Future<void> stopImpersonation() async {
    if (_originalAdmin == null) return;

    final targetUser = state.value;
    final admin = _originalAdmin!;

    state = AsyncData(admin);
    _originalAdmin = null;

    unawaited(ref.read(databaseServiceProvider).logActivity(
      userId: admin.id,
      actionType: 'IMPERSONATION_STOP',
      description: "L'admin ${admin.username} a quitté le mode impersonnant (était sous ${targetUser?.username})",
    ));
  }

  Future<void> login(String username, String pin) async {
    // Rate limiting check
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      state = AsyncError('Trop de tentatives. Réessayez dans $remaining seconde(s).', StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    try {
      debugPrint('🔑 Tentative de connexion pour : $username');
      // 1. Essayer avec le nouveau format sécurisé (Pepper)
      final pinHash = _computeHash(pin);
      debugPrint('🔎 Hash calculé (SHA256+Pepper) : ${pinHash.substring(0, 8)}...');
      
      var user = await _repository.authenticate(username, pinHash);

      // 2. Si échec, essayer avec l'ancien format (Héritage) pour la migration
      if (user == null) {
        debugPrint('⚠️ Échec avec format Peppered. Test format Legacy...');
        final legacyHash = _computeLegacyHash(pin);
        user = await _repository.authenticate(username, legacyHash);
        
        if (user != null) {
          debugPrint('✅ Succès avec format Legacy. Migration vers Peppered...');
          await changePin(user.id, pin);
          user = await _repository.authenticate(username, pinHash);
        }
      }

      if (user != null) {
        debugPrint('✅ Connexion réussie pour ${user.username} (ID: ${user.id})');
        _failedAttempts = 0; // Reset on success
        _lockoutUntil = null;
        state = AsyncData(user);
        // Jouer le son de démarrage
        ref.read(soundServiceProvider).playSessionStart();
        // Log de connexion
        unawaited(ref.read(databaseServiceProvider).logActivity(
          userId: user.id,
          actionType: 'LOGIN',
          description: 'Connexion de ${user.username}',
        ));
      } else {
        debugPrint('❌ Échec final de connexion : Aucun utilisateur trouvé correspondant à $username et ce PIN.');
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
          _failedAttempts = 0;
          state = AsyncError('Trop de tentatives échouées. Compte verrouillé pour 30 secondes.', StackTrace.current);
        } else {
          state = AsyncError('Identifiants incorrects. Tentative $_failedAttempts/5.', StackTrace.current);
          ref.read(soundServiceProvider).playScanError();
        }
        // Log d alerte sécurité
        unawaited(ref.read(databaseServiceProvider).logActivity(
          actionType: 'SECURITY_ALERT',
          description: "Tentative de connexion échouée (User: $username) [Échec $_failedAttempts/5]",
        ));
      }
    } catch (e, st) {
      debugPrint('🚨 ERREUR CRITIQUE LOGIN : $e');
      debugPrint(st.toString());

      // AUTO-HEALING: Si on détecte une colonne manquante ou une erreur de table, on tente de réparer de force
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('no such column') || errorStr.contains('is_active')) {
        try {
          debugPrint('🛡️ AuthService: Déclenchement de la réparation d\'urgence...');
          final db = await ref.read(databaseServiceProvider).database;
          await ref.read(databaseServiceProvider).runSafetyChecks(db);
          // On change le message pour inviter l'utilisateur à réessayer après réparation
          state = AsyncError('Configuration système réparée. Veuillez réessayer de vous connecter.', st);
          return;
        } catch (repairErr) {
          debugPrint('🚨 Échec de la réparation d\'urgence: $repairErr');
        }
      }

      String userMessage = 'Erreur de connexion : $e';
      if (errorStr.contains('database is locked')) {
        userMessage = 'La base de données est occupée (verrouillée). Veuillez fermer les autres instances et réessayer.';
      } else if (errorStr.contains('file is not a database')) {
        userMessage = 'Base de données corrompue. Veuillez restaurer une sauvegarde.';
      } else if (errorStr.contains('no such column')) {
        userMessage = 'Structure de données incomplète. Une réparation a été tentée, réessayez.';
      }

      state = AsyncError(userMessage, st);
    }
  }

  String _computeHash(String pin) {
    final bytes = utf8.encode(pin + _pepper);
    return sha256.convert(bytes).toString();
  }

  String _computeLegacyHash(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  void logout() {
    final user = state.value;
    if (user != null) {
      unawaited(ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'LOGOUT',
        description: 'Déconnexion de ${user.username}',
      ));
    }
    _originalAdmin = null; // Important: Clear impersonation state on logout
    state = const AsyncData(null);
  }

  // SECURITY NOTE (#7): Cette méthode effectue une migration de hash comme
  // effet de bord lors de la vérification. C'est intentionnel pour la migration
  // progressive des anciens hashs vers le format pepperé.
  Future<bool> verifyAdminPin(String pin) async {
    final pinHash = _computeHash(pin);
    final legacyHash = _computeLegacyHash(pin);

    // 1. Vérifier si c'est le PIN de l'utilisateur actuel (s'il est admin)
    final currentUser = state.value;
    if (currentUser != null && currentUser.role == UserRole.admin) {
      if (currentUser.pinHash == pinHash || currentUser.pinHash == legacyHash) {
        return true;
      }
    }

    // 2. Rechercher n'importe quel administrateur dans la base avec ce PIN
    final db = await ref.read(databaseServiceProvider).database;
    final result = await db.query(
      'users',
      where: '(pin_hash = ? OR pin_hash = ?) AND role = ?',
      whereArgs: [pinHash, legacyHash, UserRole.admin.name.toUpperCase()],
      limit: 1,
    );

    if (result.isNotEmpty) {
      // Si trouvé avec legacy, on migre
      if (result.first['pin_hash'] == legacyHash) {
        await changePin(result.first['id'] as String, pin);
      }
      return true;
    }
    
    return false;
  }

  Future<void> changePin(String userId, String newPin) async {
    final pinHash = _computeHash(newPin);
    
    final db = await ref.read(databaseServiceProvider).database;
    await db.update(
      'users',
      {'pin_hash': pinHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    // Update local state if it's the current user
    if (state.value?.id == userId) {
      state = AsyncData(state.value!.copyWith(pinHash: pinHash));
    }
  }

  // --- Système de Récupération ---

  String generateRecoveryKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars like O, 0, I, 1
    final rnd = Random.secure();
    String key = '';
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) key += '-';
      key += chars[rnd.nextInt(chars.length)];
    }
    return key;
  }

  Future<void> storeRecoveryToken(String userId, String key) async {
    final db = await ref.read(databaseServiceProvider).database;
    await db.update(
      'users',
      {'recovery_token': key},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> resetPinWithRecoveryKey(String recoveryKey, String newPin) async {
    final db = await ref.read(databaseServiceProvider).database;
    final maps = await db.query(
      'users',
      where: 'recovery_token = ? AND role = ?',
      whereArgs: [recoveryKey, UserRole.admin.name.toUpperCase()],
    );

    if (maps.isEmpty) return false;

    final userId = maps.first['id'] as String;
    await changePin(userId, newPin);
    return true;
  }

  Future<String?> getAdminRecoveryKey() async {
    final db = await ref.read(databaseServiceProvider).database;
    final maps = await db.query(
      'users',
      columns: ['id', 'recovery_token'],
      where: 'role = ?',
      whereArgs: [UserRole.admin.name.toUpperCase()],
    );

    if (maps.isEmpty) return null;
    
    final userId = maps.first['id'] as String;
    String? key = maps.first['recovery_token'] as String?;

    // Si la clé est manquante (vieille installation), on la génère maintenant
    if (key == null || key.isEmpty) {
      key = generateRecoveryKey();
      await storeRecoveryToken(userId, key);
    }
    
    return key;
  }
}
