import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:archive/archive.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});

/// Résultat d'une opération de backup
class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  const BackupResult({required this.success, required this.message, this.filePath});
}

class BackupService {
  final Ref _ref;

  BackupService(this._ref);

  /// === EXPORT MANUEL ===
  /// Copie la base de données vers un dossier choisi par l'utilisateur.
  Future<BackupResult> exportDatabase() async {
    try {
      final dbService = _ref.read(databaseServiceProvider);
      final dbPath = await dbService.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return const BackupResult(success: false, message: "Fichier de base de données introuvable.");
      }

      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Sélectionner le dossier de sauvegarde',
      );

      if (selectedDirectory == null) {
        return const BackupResult(success: false, message: "Annulé par l'utilisateur.");
      }

      final timestamp = DateFormatter.formatFileName(DateTime.now());
      final backupFileName = 'backup_danaya_$timestamp.db';
      final backupFilePath = p.join(selectedDirectory, backupFileName);

      await dbFile.copy(backupFilePath);

      return BackupResult(
        success: true,
        message: "Sauvegarde réussie !\n📁 $backupFilePath",
        filePath: backupFilePath,
      );
    } catch (e) {
      return BackupResult(success: false, message: "Erreur lors de la sauvegarde : $e");
    }
  }

  /// === TEST EMAIL ===
  Future<BackupResult> manualEmailBackup() async {
    try {
      final settings = _ref.read(shopSettingsProvider).value;
      if (settings == null) return const BackupResult(success: false, message: "Réglages introuvables.");
      
      final dbService = _ref.read(databaseServiceProvider);
      final dbPath = await dbService.getDatabasePath();
      final dbFile = File(dbPath);

      final emailService = _ref.read(emailServiceProvider);
      final result = await emailService.sendDatabaseBackup(
        recipient: settings.backupEmailRecipient,
        backupFile: dbFile,
      );

      if (result.success) {
        return const BackupResult(success: true, message: "Sauvegarde envoyée avec succès !");
      } else {
        return BackupResult(
          success: false, 
          message: "Échec : ${result.errorMessage ?? 'Erreur SMTP.'}",
        );
      }
    } catch (e) {
      return BackupResult(success: false, message: "Erreur : $e");
    }
  }

  /// === RESTAURATION DEPUIS UN FICHIER SPÉCIFIQUE ===
  /// Remplace la base de données actuelle par le fichier fourni.
  Future<BackupResult> restoreSpecificFile(File backupFile) async {
    try {
      if (!await backupFile.exists()) {
        return const BackupResult(success: false, message: "Le fichier de sauvegarde est introuvable.");
      }

      // Valider SQLite
      try {
        DatabaseFactory factory = Platform.isWindows || Platform.isLinux ? databaseFactoryFfi : databaseFactory;
        final testDb = await factory.openDatabase(backupFile.path, options: OpenDatabaseOptions(readOnly: true));
        await testDb.close();
      } catch (e) {
        return const BackupResult(success: false, message: "Ce fichier n'est pas une base de données SQLite valide.");
      }

      // Fermer connexion actuelle propre
      final dbService = _ref.read(databaseServiceProvider);
      await dbService.disposeDatabase();

      final dbPath = await dbService.getDatabasePath();
      
      // Remplacer de manière atomique
      // On utilise un petit délai pour laisser Windows relâcher le verrou ffi
      await Future.delayed(const Duration(milliseconds: 300));

      final currentDbFile = File(dbPath);
      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }
      await backupFile.copy(dbPath);

      // Succès -> Exit pour recharger
      Future.delayed(const Duration(seconds: 2), () => exit(0));

      return const BackupResult(
        success: true,
        message: "✅ Restauration réussie !\n⚠️ L'application se fermera pour appliquer les changements.",
        filePath: null,
      );
    } catch (e) {
      return BackupResult(success: false, message: "Erreur lors de la restauration : $e");
    }
  }

  /// === IMPORT / RESTAURATION ===
  /// Remplace la base de données par un fichier (.db, .gz ou .zip) sélectionné.
  Future<BackupResult> importDatabase() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Sélectionner le fichier de sauvegarde (.db, .gz, .zip)',
      );

      if (result == null || result.files.single.path == null) {
        return const BackupResult(success: false, message: "Annulé par l'utilisateur.");
      }

      File pickedFile = File(result.files.single.path!);
      String extension = p.extension(pickedFile.path).toLowerCase();
      
      // --- DÉCOMPRESSION INTELLIGENTE ---
      File? finalDbFile;
      
      if (extension == '.gz' || extension == '.zip') {
        finalDbFile = await _decompressFile(pickedFile, extension);
      } else {
        finalDbFile = pickedFile;
      }

      if (finalDbFile == null || !await finalDbFile.exists()) {
        return const BackupResult(success: false, message: "Échec de l'extraction ou fichier introuvable.");
      }

      // Valider que c'est un SQLite valide
      try {
        DatabaseFactory factory = Platform.isWindows || Platform.isLinux ? databaseFactoryFfi : databaseFactory;
        final testDb = await factory.openDatabase(finalDbFile.path, options: OpenDatabaseOptions(readOnly: true));
        await testDb.close();
      } catch (e) {
        return const BackupResult(success: false, message: "Le contenu n'est pas une base de données SQLite valide.");
      }

      // Fermer la connexion actuelle propre
      final dbService = _ref.read(databaseServiceProvider);
      await dbService.disposeDatabase();

      final dbPath = await dbService.getDatabasePath();
      
      // Laisser le temps au système de relâcher les verrous
      await Future.delayed(const Duration(milliseconds: 500));

      final currentDbFile = File(dbPath);
      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }
      
      // Restauration
      await finalDbFile.copy(dbPath);

      // Si fichier temporaire (décompressé), on nettoie
      if (finalDbFile.path != pickedFile.path) {
        await finalDbFile.delete();
      }

      // Succès -> Exit pour rechargement complet
      Future.delayed(const Duration(seconds: 2), () => exit(0));

      return const BackupResult(
        success: true,
        message: "✅ Restauration réussie !\n⚠️ L'application se fermera pour redémarrer sur la nouvelle base.",
        filePath: null,
      );
    } catch (e) {
      return BackupResult(success: false, message: "Erreur lors de la restauration : $e");
    }
  }

  /// Helper pour décompresser Gzip ou Zip vers un fichier temporaire .db
  Future<File?> _decompressFile(File file, String extension) async {
    try {
      final bytes = await file.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final outPath = p.join(tempDir.path, 'restored_temp_${DateTime.now().millisecondsSinceEpoch}.db');
      final outFile = File(outPath);

      if (extension == '.gz') {
        final decompressed = gzip.decode(bytes);
        await outFile.writeAsBytes(decompressed);
      } else if (extension == '.zip') {
        final archive = ZipDecoder().decodeBytes(bytes);
        // On cherche le fichier database.db dans l'archive
        final dbInZip = archive.findFile('database.db');
        if (dbInZip == null) return null;
        await outFile.writeAsBytes(dbInZip.content as List<int>);
      }
      
      return outFile;
    } catch (e) {
      debugPrint("Décompression Error: $e");
      return null;
    }
  }

  /// === AUTO-BACKUP QUOTIDIEN ===
  /// Déclenché au démarrage si activé et si 24h écoulées depuis le dernier backup.
  Future<void> triggerAutoBackup() async {
    try {
      final settings = _ref.read(shopSettingsProvider).value;
      if (settings == null || !settings.autoBackupEnabled) return;

      final now = DateTime.now();
      if (settings.lastAutoBackup != null) {
        final diff = now.difference(settings.lastAutoBackup!);
        if (diff.inHours < 24) return;
      }

      final dbService = _ref.read(databaseServiceProvider);
      final dbPath = await dbService.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {

        return;
      }

      // Créer le dossier backups si nécessaire
      final appDir = await getApplicationSupportDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateFormatter.formatFileName(now);
      final backupPath = p.join(backupDir.path, 'auto_backup_$timestamp.db');

      await dbFile.copy(backupPath);


      // --- 1. Miroir Cloud (Optionnel) ---
      if (settings.cloudBackupPath != null) {
        try {
          final cloudDir = Directory(settings.cloudBackupPath!);
          if (await cloudDir.exists()) {
            final cloudBackupFileName = 'backup_danaya_cloud_$timestamp.db';
            final cloudBackupPath = p.join(cloudDir.path, cloudBackupFileName);
            await dbFile.copy(cloudBackupPath);

            
            // Nettoyage Cloud : Garder seulement les 5 dernières copies Cloud
            final cloudFiles = await cloudDir.list().where((e) => p.basename(e.path).startsWith('backup_danaya_cloud_')).toList();
            if (cloudFiles.length > 5) {
              cloudFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
              for (var i = 0; i < cloudFiles.length - 5; i++) {
                await cloudFiles[i].delete();
              }
            }
          }
          } catch (_) {}
      }

      // --- 2. Email Backup (Personnalisable) ---
      if (settings.emailBackupEnabled && settings.backupEmailRecipient.isNotEmpty) {
        int daysThreshold = 7;
        if (settings.emailBackupFrequency == EmailBackupFrequency.daily) {
          daysThreshold = 1;
        } else if (settings.emailBackupFrequency == EmailBackupFrequency.monthly) {
          daysThreshold = 30;
        }

        final isRightHour = now.hour >= settings.emailBackupHour;
        bool isOverdue = false;
        bool isTimeReached = false;
        
        if (settings.lastEmailBackup == null) {
          isTimeReached = true;
        } else {
          final diff = now.difference(settings.lastEmailBackup!);
          if (diff.inDays >= daysThreshold) {
            isTimeReached = true;
            // Si on a plus de jours que le seuil, c'est qu'on a raté le créneau d'hier
            if (diff.inDays > daysThreshold) isOverdue = true;
          }
        }

        // On envoie si c'est l'heure, OU si on est en retard (rattrapage)
        if (isTimeReached && (isRightHour || isOverdue)) {
          final result = await _sendEmailBackup(dbFile, settings);
          if (result.success) {
            await _ref.read(shopSettingsProvider.notifier).save(
              settings.copyWith(lastEmailBackup: now),
            );
          }
        }
      }

      // Mettre à jour la date de dernière sauvegarde
      await _ref.read(shopSettingsProvider.notifier).save(
            settings.copyWith(lastAutoBackup: now),
          );

      // Nettoyage : Garder seulement les 5 dernières sauvegardes
      final files = await backupDir.list().toList();
      if (files.length > 5) {
        files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        for (var i = 0; i < files.length - 5; i++) {
          await files[i].delete();
        }

      }
    } catch (_) {}
  }

  /// Retourne le chemin du dossier auto-backups pour affichage dans les settings
  Future<String> getAutoBackupDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'backups');
  }

  /// Retourne la liste des auto-backups existants
  Future<List<FileSystemEntity>> listAutoBackups() async {
    final dir = Directory(await getAutoBackupDirectory());
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// === ENVOI EMAIL ===
  Future<EmailSendResult> _sendEmailBackup(File dbFile, ShopSettings settings) async {
    try {
      // Unification avec GZip (plus robuste et utilisé dans EmailService)
      final bytes = await dbFile.readAsBytes();
      final compressed = gzip.encode(bytes);
      
      final tempDir = await getTemporaryDirectory();
      final gzFile = File(p.join(tempDir.path, 'danaya_backup_${DateFormatter.formatDateCompact(DateTime.now())}.db.gz'));
      await gzFile.writeAsBytes(compressed);

      // Utiliser le service d'email
      final emailService = _ref.read(emailServiceProvider);
      
      final result = await emailService.sendEmail(
        recipient: settings.backupEmailRecipient,
        subject: '📦 Sauvegarde Automatique - ${settings.name} - ${DateFormatter.formatDate(DateTime.now())}',
        body: 'Bonjour,\n\nVeuillez trouver ci-joint la sauvegarde automatique de votre base de données Danaya+.\n\nDate: ${DateTime.now()}\nBoutique: ${settings.name}',
        attachments: [gzFile],
      );
      
      if (await gzFile.exists()) await gzFile.delete();
      return result;
    } catch (e) {
      debugPrint('BackupService Email Error: $e');
      return EmailSendResult(success: false, errorMessage: e.toString());
    }
  }
}
