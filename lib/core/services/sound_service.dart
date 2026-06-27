import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/server_service.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService(ref);
});

// ═══════════════════════════════════════════════════════════════════
// Windows Native Audio — winmm.dll PlaySoundW
// Zéro dépendance externe, zéro erreur de threading, 100% offline.
// ═══════════════════════════════════════════════════════════════════

// Signatures FFI pour winmm.dll
typedef _PlaySoundNative = Int32 Function(
    Pointer<Utf16> pszSound, IntPtr hmod, Uint32 fdwSound);
typedef _PlaySoundDart = int Function(
    Pointer<Utf16> pszSound, int hmod, int fdwSound);

// Flags Windows PlaySound constants
const int _sndFilename = 0x00020000;
const int _sndAsync = 0x0001;
const int _sndNodefault = 0x0002;

/// Service de notifications sonores "Elite" pour le POS.
/// Utilise l'API native Windows (winmm.dll) — 100% Offline, zéro plugin.
/// Déclenchement instantané, aucune erreur de threading.
class SoundService {
  final Ref _ref;

  // Fonction native chargée une seule fois
  static _PlaySoundDart? _playSound;

  // Chemins absolus pré-résolus pour un déclenchement instantané
  final Map<String, String> _resolvedPaths = {};

  // Noms des sons et chemins relatifs dans les assets
  static const Map<String, String> _soundAssets = {
    'scan_success': 'assets/sounds/scan_success.wav',
    'sale_success': 'assets/sounds/sale_success.wav',
    'error': 'assets/sounds/error.wav',
    'stock_alert': 'assets/sounds/stock_alert.wav',
    'session_start': 'assets/sounds/session_start.wav',
    'test': 'assets/sounds/test.wav',
  };

  SoundService(this._ref) {
    _init();
  }

  void _init() {
    if (!Platform.isWindows) {
      debugPrint('⚠️ SoundService: Plateforme non-Windows, sons désactivés.');
      return;
    }

    try {
      // 1. Charger winmm.dll et la fonction PlaySoundW
      if (_playSound == null) {
        final winmm = DynamicLibrary.open('winmm.dll');
        _playSound = winmm.lookupFunction<_PlaySoundNative, _PlaySoundDart>(
            'PlaySoundW');
      }

      // 2. Résoudre les chemins absolus des fichiers WAV
      // Dans un build Flutter Windows, les assets sont dans :
      //   <exe_dir>/data/flutter_assets/<asset_path>
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final assetsBase = '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets';

      int loaded = 0;
      for (final entry in _soundAssets.entries) {
        final fullPath = '$assetsBase${Platform.pathSeparator}${entry.value.replaceAll('/', Platform.pathSeparator)}';
        if (File(fullPath).existsSync()) {
          _resolvedPaths[entry.key] = fullPath;
          loaded++;
        } else {
          debugPrint('⚠️ SoundService: Fichier introuvable: $fullPath');
        }
      }

      debugPrint('🔊 SoundService: $loaded/${_soundAssets.length} sons chargés (Windows natif, offline)');
    } catch (e) {
      debugPrint('⚠️ SoundService: Erreur d\'init: $e');
    }
  }

  bool get _isAppEnabled {
    final settings = _ref.read(shopSettingsProvider);
    return settings.when(
      data: (s) => s.enableAppSounds,
      loading: () => false,
      error: (_, __) => true,
    );
  }

  bool get _isClientEnabled {
    final settings = _ref.read(shopSettingsProvider);
    return settings.when(
      data: (s) => s.enableCustomerDisplaySounds,
      loading: () => false,
      error: (_, __) => true,
    );
  }

  Future<void> _play(String soundKey) async {
    if (_playSound == null) return;

    try {
      // 1. Jouer localement si activé
      if (_isAppEnabled) {
        final soundPath = _resolvedPaths[soundKey];
        if (soundPath != null) {
          final pathPointer = soundPath.toNativeUtf16();
          _playSound!(pathPointer, 0, _sndFilename | _sndAsync | _sndNodefault);
          calloc.free(pathPointer);
        }
      }

      // 2. Broadcast vers l'afficheur client si activé
      if (_isClientEnabled) {
        _ref.read(serverServiceProvider).broadcastSound(soundKey);
      }
    } catch (e) {
      debugPrint('❌ Erreur SoundService: $e');
    }
  }

  /// 1. Son de caisse enregistreuse (Ka-ching!) — Vente validée
  Future<void> playSaleSuccess() => _play('sale_success');

  /// 2. Bip de confirmation — Produit scanné
  Future<void> playScanSuccess() => _play('scan_success');

  /// 3. Son d'erreur — Code-barres inconnu
  Future<void> playScanError() => _play('error');

  /// 4. Alerte attention — Stock épuisé
  Future<void> playStockAlert() => _play('stock_alert');

  /// 5. Son de démarrage — Ouverture de session
  Future<void> playSessionStart() => _play('session_start');

  /// Son de test (pour les paramètres)
  Future<void> playTest() => _play('test');

  void dispose() {
    _resolvedPaths.clear();
  }
}
