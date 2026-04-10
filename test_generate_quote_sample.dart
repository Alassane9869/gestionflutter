// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:danaya_plus/features/pos/services/quote_service.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';

void main() async {
  print("Generating Supreme Quote sample...");
  
  // Create a base settings with QuoteTemplate.supreme
  final settings = ShopSettings(
    name: "Danaya+ Technologies",
    slogan: "Innovation et Excellence",
    address: "BP 1234, Abidjan Plateau",
    phone: "+225 0102030405",
    rc: "CI-ABJ-2023-B-12345",
    nif: "1234567A",
    currency: "FCFA",
    removeDecimals: true,
    defaultQuote: QuoteTemplate.supreme,
    useTax: true,
    taxRate: 0.18,
    taxName: "TVA",
    quoteValidityDays: 15,
  );

  try {
    final Uint8List pdfBytes = await QuoteService.generateSamplePdf(settings);
    final file = File('supreme_quote_sample.pdf');
    await file.writeAsBytes(pdfBytes);
    print("Sample generated at ${file.absolute.path}");
  } catch (e) {
    print("Error: $e");
  }
  exit(0);
}
