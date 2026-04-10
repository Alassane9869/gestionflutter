import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'maintenance_providers.dart';

/// 🔐 Compteur secret pour le cockpit (Fresh State Style)
final systemHealthSecretCounterProvider = NotifierProvider<SecretCounterNotifier, int>(() {
  return SecretCounterNotifier();
});

class SecretCounterNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    // Nettoyer le timer si le notifier est recréé
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  void increment() {
    state = state + 1;
    
    // Si on atteint le seuil, on lance le compte à rebours de masquage auto (120s)
    if (state >= 5) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 120), () {
        state = 0;
      });
    }
  }

  void reset() {
    _timer?.cancel();
    state = 0;
  }
}

/// 🛡️ État de visibilité de la session de nettoyage
final systemHealthIsUnlockedProvider = Provider<bool>((ref) {
  return ref.watch(systemHealthSecretCounterProvider) >= 5;
});

class SystemHealthState {
  final bool isScanning;
  final bool isOptimizing;
  final Map<String, dynamic>? lastScannerResult;
  final String? currentActionLabel;
  final double progress;

  SystemHealthState({
    this.isScanning = false,
    this.isOptimizing = false,
    this.lastScannerResult,
    this.currentActionLabel,
    this.progress = 0.0,
  });

  SystemHealthState copyWith({
    bool? isScanning,
    bool? isOptimizing,
    Map<String, dynamic>? lastScannerResult,
    String? currentActionLabel,
    double? progress,
  }) {
    return SystemHealthState(
      isScanning: isScanning ?? this.isScanning,
      isOptimizing: isOptimizing ?? this.isOptimizing,
      lastScannerResult: lastScannerResult ?? this.lastScannerResult,
      currentActionLabel: currentActionLabel ?? this.currentActionLabel,
      progress: progress ?? this.progress,
    );
  }
}

final systemHealthProvider = NotifierProvider<SystemHealthNotifier, SystemHealthState>(() {
  return SystemHealthNotifier();
});

class SystemHealthNotifier extends Notifier<SystemHealthState> {
  @override
  SystemHealthState build() {
    return SystemHealthState();
  }

  /// 💎 Lance un diagnostic complet du système
  Future<void> runFullDiagnostic() async {
    state = state.copyWith(isScanning: true, progress: 0.1, currentActionLabel: "Analyse de la base de données...");
    
    try {
      final result = await ref.read(maintenanceServiceProvider).performIntegrityCheck();
      state = state.copyWith(isScanning: false, lastScannerResult: result, progress: 1.0, currentActionLabel: "Diagnostic terminé.");
    } catch (e) {
      state = state.copyWith(isScanning: false, currentActionLabel: "Erreur lors du diagnostic: $e");
    }
  }

  /// 💎 Lance une optimisation Maître (Full Clean & Optimize)
  Future<void> runMasterOptimization() async {
    state = state.copyWith(isOptimizing: true, progress: 0.1, currentActionLabel: "Démarrage de l'optimisation...");
    
    try {
      // Étape 0: Réparation Intégrité Stock
      state = state.copyWith(progress: 0.1, currentActionLabel: "Réparation des écarts de stock...");
      await ref.read(maintenanceServiceProvider).repairStockIntegrity();

      // Étape 1: Nettoyage Images
      state = state.copyWith(progress: 0.25, currentActionLabel: "Nettoyage des images orphelines...");
      await ref.read(maintenanceServiceProvider).cleanupOrphanImages();
      
      // Étape 2: Recalcul PMP
      state = state.copyWith(progress: 0.45, currentActionLabel: "Recalcul des coûts moyens (PMP)...");
      await ref.read(maintenanceServiceProvider).recalculateAllWacs();
      
      // Étape 3: Purge Logs (Default 6 months)
      state = state.copyWith(progress: 0.6, currentActionLabel: "Archivage des anciens journaux...");
      await ref.read(maintenanceServiceProvider).purgeActivityLogs(6);
      
      // Étape 4: VACUUM
      state = state.copyWith(progress: 0.8, currentActionLabel: "Compactage de la base de données...");
      await ref.read(maintenanceServiceProvider).optimizeDatabase();

      // Final: Re-scan
      await runFullDiagnostic();
      state = state.copyWith(isOptimizing: false, currentActionLabel: "Système optimisé avec succès.");
    } catch (e) {
      state = state.copyWith(isOptimizing: false, currentActionLabel: "Échec de l'optimisation: $e");
    }
  }

  /// ☢️ Réinitialisation Nucléaire
  Future<void> nuclearReset() async {
    state = state.copyWith(isOptimizing: true, currentActionLabel: "RÉINITIALISATION TOTALE EN COURS...");
    await ref.read(maintenanceServiceProvider).resetFullDatabase();
    await runFullDiagnostic();
    state = state.copyWith(isOptimizing: false, currentActionLabel: "Système remis à zéro.");
  }

  /// 📉 Suppression des Ventes uniquement
  Future<void> clearSalesOnly() async {
    state = state.copyWith(isOptimizing: true, currentActionLabel: "PURGE DES VENTES EN COURS...");
    await ref.read(maintenanceServiceProvider).clearSalesData();
    await runFullDiagnostic();
    state = state.copyWith(isOptimizing: false, currentActionLabel: "Ventes et Devis purgés.");
  }

  /// 📦 Reset Inventaire uniquement
  Future<void> clearInventoryOnly() async {
    state = state.copyWith(isOptimizing: true, currentActionLabel: "RÉINITIALISATION DU STOCK...");
    await ref.read(maintenanceServiceProvider).clearInventoryData();
    await runFullDiagnostic();
    state = state.copyWith(isOptimizing: false, currentActionLabel: "Quantités remises à zéro.");
  }

  /// 👥 Reset CRM uniquement
  Future<void> clearCRMOnly() async {
    state = state.copyWith(isOptimizing: true, currentActionLabel: "NETTOYAGE CLIENTS & FOURNISSEURS...");
    await ref.read(maintenanceServiceProvider).clearCRMData();
    await runFullDiagnostic();
    state = state.copyWith(isOptimizing: false, currentActionLabel: "Fichier CRM réinitialisé.");
  }

  /// 📝 Reset Logs uniquement
  Future<void> clearLogsOnly() async {
    state = state.copyWith(isOptimizing: true, currentActionLabel: "PURGE DES LOGS...");
    await ref.read(maintenanceServiceProvider).clearSystemLogs();
    await runFullDiagnostic();
    state = state.copyWith(isOptimizing: false, currentActionLabel: "Historique d'audit effacé.");
  }
}
