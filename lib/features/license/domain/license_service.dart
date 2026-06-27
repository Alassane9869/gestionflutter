import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:danaya_plus/core/config/security_config.dart';

final licenseServiceProvider = Provider<LicenseService>((ref) => LicenseService());

class LicenseService {
  static const String _licenseKeyPref = 'activation_key';
  static const String _activationDatePref = 'activation_date';
  
  static final String _secretSalt = SecurityConfig.licenseSalt;

  // Custom string scrambling function to add cryptographic complexity
  String _scrambleString(String input) {
    final chars = input.split('');
    if (chars.length < 10) return input;
    // Deterministically swap pairs of elements to disrupt simple text analysis
    for (int i = 0; i < chars.length - 1; i += 2) {
      final t = chars[i];
      chars[i] = chars[i + 1];
      chars[i + 1] = t;
    }
    // Reverse the whole list of characters
    return chars.reversed.join();
  }

  // Obtenir le Hardware ID unique (HID) - Obfusqué et renforcé
  Future<String> getHardwareId() async {
    final deviceInfo = DeviceInfoPlugin();
    String details = "";

    try {
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        // Combines machineGuid, computerName, productName, and core count
        details = "${windowsInfo.computerName}-${windowsInfo.numberOfCores}-${windowsInfo.deviceId}-${windowsInfo.productName}";
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        details = "${androidInfo.manufacturer}-${androidInfo.model}-${androidInfo.id}";
      }
    } catch (_) {
      details = "fallback-danaya-license-hardware";
    }

    final scrambled = _scrambleString(details);
    final bytes = utf8.encode(scrambled);
    final hash = sha256.convert(bytes);
    // Return first 16 characters of custom hash as the official HID
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

  // Internal helper to calculate validation hash and noise bits
  Map<String, String> _generateHashAndNoise(String hid, String duration) {
    final bytes = utf8.encode("$hid-$duration-$_secretSalt");
    final fullHash = sha256.convert(bytes).toString().toUpperCase();
    return {
      'hash': fullHash.substring(0, 8),
      'noise': fullHash.substring(8, 14),
    };
  }

  // Assembles key using a transposition matrix (interleaved layout)
  String _assembleKey(String hid, String duration, String hash, String noise) {
    final List<String> result = List.filled(32, "");
    
    final hashIndices = [0, 4, 8, 12, 16, 20, 24, 28];
    final durationIndices = [2, 14];
    final hidIndices = [1, 3, 5, 6, 7, 9, 10, 11, 13, 15, 17, 18, 19, 21, 22, 23];
    final noiseIndices = [25, 26, 27, 29, 30, 31];

    for (int i = 0; i < hashIndices.length; i++) {
      result[hashIndices[i]] = hash[i];
    }
    for (int i = 0; i < durationIndices.length; i++) {
      result[durationIndices[i]] = duration[i];
    }
    for (int i = 0; i < hidIndices.length; i++) {
      result[hidIndices[i]] = hid[i];
    }
    for (int i = 0; i < noiseIndices.length; i++) {
      result[noiseIndices[i]] = noise[i];
    }

    return result.join();
  }

  // Disassembles the transposed license key back into constituent fields
  Map<String, String>? _disassembleKey(String key) {
    if (key.length != 32) return null;
    
    final hashIndices = [0, 4, 8, 12, 16, 20, 24, 28];
    final durationIndices = [2, 14];
    final hidIndices = [1, 3, 5, 6, 7, 9, 10, 11, 13, 15, 17, 18, 19, 21, 22, 23];
    final noiseIndices = [25, 26, 27, 29, 30, 31];

    final sbHash = StringBuffer();
    final sbDuration = StringBuffer();
    final sbHid = StringBuffer();
    final sbNoise = StringBuffer();

    for (final idx in hashIndices) {
      sbHash.write(key[idx]);
    }
    for (final idx in durationIndices) {
      sbDuration.write(key[idx]);
    }
    for (final idx in hidIndices) {
      sbHid.write(key[idx]);
    }
    for (final idx in noiseIndices) {
      sbNoise.write(key[idx]);
    }

    return {
      'hash': sbHash.toString(),
      'duration': sbDuration.toString(),
      'hid': sbHid.toString(),
      'noise': sbNoise.toString(),
    };
  }

  // Logique de validation de la clé (Interleaved/Transposed format)
  LicenseValidation _validateKey(String key, String hid) {
    try {
      final keyClean = key.replaceAll(RegExp(r'\s+|-'), '').toUpperCase();
      final parsed = _disassembleKey(keyClean);
      if (parsed == null) return LicenseValidation(false, 0);

      final keyHid = parsed['hid'];
      final durationStr = parsed['duration'];
      final keyHash = parsed['hash'];
      final keyNoise = parsed['noise'];

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
        case "IN": days = 36500; break; // ~100 ans
        default: return LicenseValidation(false, 0);
      }

      final expected = _generateHashAndNoise(hid, durationStr!);
      if (keyHash == expected['hash'] && keyNoise == expected['noise']) {
        return LicenseValidation(true, days);
      }
    } catch (e) {
      return LicenseValidation(false, 0);
    }
    return LicenseValidation(false, 0);
  }

  // Méthode utilitaire pour VOUS (Admin) générer une clé
  String generateLicenseKey(String hid, String type) {
    final formattedType = type == "INF" ? "IN" : type;
    final expected = _generateHashAndNoise(hid, formattedType);
    return _assembleKey(hid, formattedType, expected['hash']!, expected['noise']!);
  }

  // Vérifier si la licence Labs/AI est valide
  Future<bool> isLabsActivated() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('labs_activation_key');
    if (key == null) return false;
    final hid = await getHardwareId();
    return validateLabsKey(key, hid).isValid;
  }

  LicenseValidation validateLabsKey(String key, String hid) {
    try {
      final keyClean = key.replaceAll(RegExp(r'\s+|-'), '').toUpperCase();
      final parsed = _disassembleKey(keyClean);
      if (parsed == null) return LicenseValidation(false, 0);

      final keyHid = parsed['hid'];
      final durationStr = parsed['duration'];
      final keyHash = parsed['hash'];
      final keyNoise = parsed['noise'];

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
        case "IN": days = 36500; break;
        default: return LicenseValidation(false, 0);
      }

      final expected = _generateHashAndNoiseForLabs(hid, durationStr!);
      if (keyHash == expected['hash'] && keyNoise == expected['noise']) {
        return LicenseValidation(true, days);
      }
    } catch (e) {
      return LicenseValidation(false, 0);
    }
    return LicenseValidation(false, 0);
  }

  Map<String, String> _generateHashAndNoiseForLabs(String hid, String duration) {
    final bytes = utf8.encode("$hid-$duration-$_secretSalt-labs-secret");
    final fullHash = sha256.convert(bytes).toString().toUpperCase();
    return {
      'hash': fullHash.substring(0, 8),
      'noise': fullHash.substring(8, 14),
    };
  }

  String generateLabsLicenseKey(String hid, String type) {
    final formattedType = type == "INF" ? "IN" : type;
    final expected = _generateHashAndNoiseForLabs(hid, formattedType);
    return _assembleKey(hid, formattedType, expected['hash']!, expected['noise']!);
  }
}

class LicenseValidation {
  final bool isValid;
  final int durationInDays;
  LicenseValidation(this.isValid, this.durationInDays);
}
