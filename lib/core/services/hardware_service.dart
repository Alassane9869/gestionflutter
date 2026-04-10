import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DeviceClass { usb, printer, unknown }

class ExternalDevice {
  final String name;
  final String status;
  final DeviceClass deviceClass;
  final Map<String, dynamic> rawData;

  ExternalDevice({
    required this.name,
    required this.status,
    required this.deviceClass,
    this.rawData = const {},
  });
}

final hardwareServiceProvider = Provider((ref) => HardwareService());

class HardwareService {
  /// Liste les périphériques USB/HID (scanners, douchettes, etc.)
  Future<List<ExternalDevice>> listUsbDevices() async {
    if (!Platform.isWindows) return [];

    try {
      // Commande PowerShell pour lister les périphériques PnP présent
      // On cible les classes HIDClass et USB pour les accessoires POS
      final result = await Process.run('powershell', [
        '-Command',
        "Get-PnpDevice -PresentOnly | Where-Object { \$_.Class -eq 'HIDClass' -or \$_.Class -eq 'USB' -or \$_.Class -eq 'Ports' } | Select-Object FriendlyName, Status, Class | ConvertTo-Json"
      ]);

      if (result.exitCode != 0 || result.stdout.toString().isEmpty) return [];

      final dynamic data = jsonDecode(result.stdout.toString());
      final List<dynamic> list = data is List ? data : [data];

      return list.map((item) {
        return ExternalDevice(
          name: item['FriendlyName'] ?? 'Périphérique inconnu',
          status: item['Status'] ?? 'Unknown',
          deviceClass: DeviceClass.usb,
          rawData: item as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur détection USB: $e');
      return [];
    }
  }

  /// Liste les imprimantes installées sur le système
  Future<List<ExternalDevice>> listPrinters() async {
    if (!Platform.isWindows) return [];

    try {
      final result = await Process.run('powershell', [
        '-Command',
        "Get-Printer | Select-Object Name, PrinterStatus, Default | ConvertTo-Json"
      ]);

      if (result.exitCode != 0 || result.stdout.toString().isEmpty) return [];

      final dynamic data = jsonDecode(result.stdout.toString());
      final List<dynamic> list = data is List ? data : [data];

      return list.map((item) {
        return ExternalDevice(
          name: item['Name'] ?? 'Imprimante sans nom',
          status: _parsePrinterStatus(item['PrinterStatus']),
          deviceClass: DeviceClass.printer,
          rawData: item as Map<String, dynamic>,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur détection Imprimantes: $e');
      return [];
    }
  }

  String _parsePrinterStatus(dynamic status) {
    if (status == 0) return 'Prêt';
    if (status == 1) return 'Pause';
    if (status == 2) return 'Erreur';
    if (status == 3) return 'Hors-ligne';
    return 'Inconnu ($status)';
  }

  /// Déclenche l'ouverture du tiroir-caisse via une commande Esc/POS
  Future<void> kickDrawer(String printerName) async {
    if (!Platform.isWindows || printerName.isEmpty) return;

    try {
      // Commande standard Esc/POS: ESC p m t1 t2
      // [27, 112, 0, 25, 250] est le plus commun
      // Utilisation de Out-Printer sur Windows
      final command = "\$cmd = [char]27+[char]112+[char]0+[char]25+[char]250; \$cmd | Out-Printer -Name \"$printerName\"";
      
      await Process.run('powershell', [
        '-Command',
        command
      ]);
    } catch (e) {
      debugPrint('❌ Erreur ouverture tiroir: $e');
    }
  }
}
