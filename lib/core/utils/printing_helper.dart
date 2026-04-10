import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class PrintingHelper {
  /// Robust printer selection logic.
  /// 
  /// Attempts to find an exact match for the [targetPrinterName].
  /// If not found, it returns null instead of a random printer,
  /// allowing the caller to fallback to a standard print dialog.
  static Future<Printer?> findPrinter(String? targetPrinterName) async {
    if (targetPrinterName == null || targetPrinterName.trim().isEmpty) {
      return null;
    }

    try {
      final printers = await Printing.listPrinters();
      final normalizedTarget = targetPrinterName.toLowerCase().trim();

      // 1. Exact match (case insensitive)
      for (final printer in printers) {
        if (printer.name.toLowerCase().trim() == normalizedTarget) {
          return printer;
        }
      }

      // 2. Fuzzy match (if target is "Epson" and we find "EPSON TM-T20II")
      for (final printer in printers) {
        if (printer.name.toLowerCase().contains(normalizedTarget)) {
          debugPrint("🔍 PrintingHelper: Fuzzy match found for '$targetPrinterName' -> '${printer.name}'");
          return printer;
        }
      }
    } catch (e) {
      debugPrint("❌ PrintingHelper Error: $e");
    }

    debugPrint("⚠️ PrintingHelper: Configured printer '$targetPrinterName' not found on this system.");
    return null;
  }

  /// Centralized print command that handles direct printing with a fallback.
  static Future<void> printWithFallback({
    required pw.Document doc,
    required String? targetPrinterName,
    required bool directPrint,
    required String jobName,
  }) async {
    if (directPrint && targetPrinterName != null && targetPrinterName.isNotEmpty) {
      final printer = await findPrinter(targetPrinterName);
      
      if (printer != null) {
        try {
          await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => doc.save(),
          );
          return;
        } catch (e) {
          debugPrint("❌ Direct print failed: $e. Falling back to dialog.");
        }
      }
    }

    // Fallback to standard OS print dialog if direct printing fails or is disabled
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: jobName,
    );
  }
}
