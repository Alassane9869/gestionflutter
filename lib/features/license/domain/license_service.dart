import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());

class LicenseService {
  static const String _licenseKeyPref = 'activation_key';
  static const String _activationDatePref = 'activation_date';
  // ignore: constant_identifier_names
  static const String _SECRET_SALT = 'DANAYA_PLUS_ULTRA_SECURE_2024_SALT';

  // Obtenir le Hardware ID unique (HID)
  Future<String> getHardwareId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = "";
    String computerName = "";

    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      deviceId = windowsInfo.deviceId;
      computerName = windowsInfo.computerName;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      computerName = androidInfo.model;
    }

    final bytes = utf8.encode("$computerName-$deviceId");
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16).toUpperCase();
  }

  // Vérifier si l'app est activée et non expirée
  Future<bool> isAppActivated() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_licenseKeyPref);
    final activationDateStr = prefs.getString(_activationDatePref);

    if (key == null || activationDateStr == null) return false;

    final hid = await getHardwareId();
    final validation = _validateKey(key, hid);

    if (!validation.isValid) return false;

    // Si version illimitée
    if (validation.durationInDays >= 30000) return true;

    // Vérifier l'expiration
    final activationDate = DateTime.parse(activationDateStr);
    final now = DateTime.now();
    
    // ANTI-FRAUDE : Vérification du recul de l'horloge (Clock Rollback)
    final lastSessionStr = prefs.getString('last_session_timestamp');
    if (lastSessionStr != null) {
      final lastSession = DateTime.parse(lastSessionStr);
      if (now.isBefore(lastSession)) {
        debugPrint("🚨 ALERTE SÉCURITÉ : Horloge système reculée détectée !");
        return false; // Bloquer l'accès si l'heure est manipulée
      }
    }
    
    // Mettre à jour le timestamp de la dernière session
    await prefs.setString('last_session_timestamp', now.toIso8601String());

    // GARDE CONTRE LE BACK-DATING (Changement d'heure système pour tricher)
    if (now.isBefore(activationDate)) {
      debugPrint("⚠️ ALERTE LICENCE : Heure système incohérente (Back-dating détecté)");
      return false;
    }

    final expiryDate = activationDate.add(Duration(days: validation.durationInDays));
    
    return now.isBefore(expiryDate);
  }

  // Obtenir les jours restants
  Future<int?> getDaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_licenseKeyPref);
    final activationDateStr = prefs.getString(_activationDatePref);

    if (key == null || activationDateStr == null) return null;

    final hid = await getHardwareId();
    final validation = _validateKey(key, hid);

    if (!validation.isValid) return 0;
    if (validation.durationInDays >= 30000) return 9999;

    final activationDate = DateTime.parse(activationDateStr);
    final expiryDate = activationDate.add(Duration(days: validation.durationInDays));
    
    return expiryDate.difference(DateTime.now()).inDays;
  }

  // Activer l'application
  Future<bool> activateApp(String enteredKey) async {
    final hid = await getHardwareId();
    final validation = _validateKey(enteredKey, hid);

    if (validation.isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKeyPref, enteredKey);
      await prefs.setString(_activationDatePref, DateTime.now().toIso8601String());
      return true;
    }
    return false;
  }

  // Logique de validation de la clé
  LicenseValidation _validateKey(String key, String hid) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) return LicenseValidation(false, 0);

      final keyHid = parts[0];
      final durationStr = parts[1]; 
      final hash = parts[2];

      if (keyHid != hid) {
        return LicenseValidation(false, 0);
      }

      int days = 0;
      switch (durationStr) {
        case "D7": days = 7; break;
        case "M1": days = 30; break;
        case "M3": days = 90; break;
        case "M6": days = 180; break;
        case "Y1": days = 365; break;
        case "Y2": days = 730; break;
        case "Y3": days = 1095; break;
        case "INF": days = 36500; break; // ~100 ans
        default: return LicenseValidation(false, 0);
      }

      // Recalculer le hash attendu
      final expectedHash = _generateHash(hid, durationStr);
      
      if (hash == expectedHash) {
        return LicenseValidation(true, days);
      }
    } catch (e) {
      return LicenseValidation(false, 0);
    }
    return LicenseValidation(false, 0);
  }

  String _generateHash(String hid, String duration) {
    final bytes = utf8.encode("$hid-$duration-$_SECRET_SALT");
    return sha256.convert(bytes).toString().substring(0, 8).toUpperCase();
  }

  // Méthode utilitaire pour VOUS (Admin) générer une clé
  String generateLicenseKey(String hid, String type) {
    final hash = _generateHash(hid, type);
    return "$hid-$type-$hash";
  }
}

class LicenseValidation {
  final bool isValid;
  final int durationInDays;
  LicenseValidation(this.isValid, this.durationInDays);
}
