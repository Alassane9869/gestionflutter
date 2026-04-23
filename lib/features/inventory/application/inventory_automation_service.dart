import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode/barcode.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../domain/models/product.dart';
import '../data/product_repository.dart';
import '../../settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';

final inventoryAutomationServiceProvider = Provider((ref) => InventoryAutomationService(ref));

class ImportResult {
  final int count;
  final int errors;
  final List<String> errorMessages;

  ImportResult(this.count, this.errors, this.errorMessages);
}

class ExcelMappingConfig {
  final String sheetName;
  final Map<String, int> columnMap;
  final bool skipFirstRow;

  ExcelMappingConfig({
    required this.sheetName,
    required this.columnMap,
    this.skipFirstRow = true,
  });
}

class InventoryAutomationService {
  final Ref _ref;
  final _uuid = const Uuid();

  InventoryAutomationService(this._ref);

  /// Analyse n'importe quel fichier Excel pour en extraire la structure (feuilles et colonnes)
  Future<Map<String, List<String>>> getExcelStructure(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    Map<String, List<String>> structure = {};

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet != null && sheet.maxRows > 0) {
        final firstRow = sheet.rows[0];
        structure[table] = firstRow.map((cell) => cell?.value?.toString() ?? "Colonne ${firstRow.indexOf(cell) + 1}").toList();
      }
    }
    return structure;
  }

  /// Importation flexible avec mapping dynamique
  Future<ImportResult> importWithMapping(Uint8List bytes, ExcelMappingConfig config) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[config.sheetName];
    if (sheet == null) return ImportResult(0, 0, ["Feuille introuvable"]);

    final settings = await _ref.read(shopSettingsProvider.future);
    final warehouses = await _ref.read(warehouseListProvider.future);
    
    int importedCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    int startRow = config.skipFirstRow ? 1 : 0;

    for (var i = startRow; i < sheet.maxRows; i++) {
      try {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        String getValue(String field) {
          final index = config.columnMap[field];
          if (index == null || index < 0 || index >= row.length) return "";
          return row[index]?.value?.toString().trim() ?? "";
        }

        final name = getValue('name');
        if (name.isEmpty) continue;

        final category = getValue('category');
        final unit = getValue('unit');
        final refCode = getValue('reference');
        final barcode = getValue('barcode');
        
        final typeVal = getValue('isService'); 
        final isService = typeVal.toLowerCase() == "1" || typeVal.toLowerCase().contains("serv");
        
        double priceParser(String val) {
          if (val.isEmpty) return 0.0;
          String cleaned = val.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
          return (double.tryParse(cleaned) ?? 0.0).abs();
        }

        final purchasePrice = priceParser(getValue('purchasePrice'));
        final sellingPrice = priceParser(getValue('sellingPrice'));
        final quantity = priceParser(getValue('quantity'));
        final alert = priceParser(getValue('alertThreshold'));
        
        final desc = getValue('description');
        final whName = getValue('warehouse');
        final loc = getValue('location');

        String? whId;
        if (whName.isNotEmpty) {
          try { whId = warehouses.firstWhere((w) => w.name.toLowerCase() == whName.toLowerCase().trim()).id; } catch (_) {}
        }

        String finalRef = refCode;
        if (settings.useAutoRef && finalRef.isEmpty) {
          finalRef = await generateAutoRef(category, settings.refPrefix, null, i);
        }
        
        String finalBarcode = barcode;
        if (finalBarcode.isEmpty) finalBarcode = await generateNumericBarcode(null, i);

        final product = Product(
          id: _uuid.v4(), name: name, reference: finalRef, barcode: finalBarcode,
          category: category.isEmpty ? null : category, 
          unit: unit.isEmpty ? null : unit, 
          isService: isService,
          quantity: isService ? 0.0 : quantity,
          purchasePrice: purchasePrice, sellingPrice: sellingPrice,
          alertThreshold: isService ? 0.0 : alert,
          description: desc.isEmpty ? null : desc, 
          location: loc.isEmpty ? null : loc,
        );

        await _ref.read(productRepositoryProvider).insert(product, warehouseId: whId);
        importedCount++;
      } catch (e) {
        errorCount++;
        errors.add("Ligne ${i + 1}: ${e.toString()}");
      }
    }
    return ImportResult(importedCount, errorCount, errors);
  }

  /// ALPHA-GENIUS: Génère un aperçu des produits (sans sauvegarde)
  Future<List<Product>> previewProducts(Uint8List bytes, ExcelMappingConfig config, {int limit = 5}) async {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[config.sheetName];
    if (sheet == null) return [];

    List<Product> preview = [];
    int startRow = config.skipFirstRow ? 1 : 0;
    int endRow = (startRow + limit).clamp(0, sheet.maxRows);

    for (var i = startRow; i < endRow; i++) {
      try {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        String getValue(String field) {
          final index = config.columnMap[field];
          if (index == null || index < 0 || index >= row.length) return "";
          return row[index]?.value?.toString() ?? "";
        }

        final name = getValue('name');
        if (name.isEmpty) continue;

        double priceParser(String val) {
          if (val.isEmpty) return 0.0;
          String cleaned = val.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
          return (double.tryParse(cleaned) ?? 0.0).abs();
        }

        preview.add(Product(
          id: "preview_$i",
          name: name,
          reference: getValue('reference'),
          barcode: getValue('barcode'),
          category: getValue('category'),
          unit: getValue('unit'),
          quantity: priceParser(getValue('quantity')),
          purchasePrice: priceParser(getValue('purchasePrice')),
          sellingPrice: priceParser(getValue('sellingPrice')),
          isService: getValue('isService').toLowerCase() == "1" || getValue('isService').toLowerCase().contains("serv"),
          description: getValue('description'),
          location: getValue('location'),
        ));
      } catch (_) {}
    }
    return preview;
  }

  Future<int> assignAutoRefsToExisting() async {
    final products = await _ref.read(productRepositoryProvider).getAll();
    final settings = await _ref.read(shopSettingsProvider.future);
    int count = 0;

    for (final p in products) {
      bool updated = false;
      String? newRef = p.reference;
      String? newBar = p.barcode;

      if (p.reference == null || p.reference!.isEmpty) {
        newRef = await generateAutoRef(p.category, settings.refPrefix, null, count);
        updated = true;
      }

      if (p.barcode == null || p.barcode!.isEmpty) {
        newBar = await generateNumericBarcode(null, count);
        updated = true;
      }

      if (updated) {
        final updatedProduct = p.copyWith(reference: newRef, barcode: newBar);
        await _ref.read(productRepositoryProvider).update(updatedProduct);
        count++;
      }
    }
    return count;
  }

  Future<void> printBarcodeLabels(List<Product> products) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    final settings = await _ref.read(shopSettingsProvider.future);
    
    final printable = products.where((p) => p.barcode != null && p.barcode!.isNotEmpty).toList();
    if (printable.isEmpty) throw Exception("Aucun code-barres trouvé.");
    if (printable.length > 500) {
      throw Exception("Impression bloquée : Trop d'étiquettes (${printable.length}). Maximum 500.");
    }

    final double marginX = settings.marginLabelX * PdfPageFormat.mm;
    final double marginY = settings.marginLabelY * PdfPageFormat.mm;

    if (settings.labelFormat == LabelPrintingFormat.a4Sheets) {
      final List<List<Product>> rows = [];
      for (var i = 0; i < printable.length; i += 3) {
        rows.add(printable.sublist(i, i + 3 > printable.length ? printable.length : i + 3));
      }
      pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 12 + marginX, vertical: 12 + marginY),
          build: (context) => [
            pw.Column(children: rows.map((row) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(children: [
                ...row.map((p) => pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: _buildLabelWidget(p, settings, isVertical: true)))),
                if (row.length < 3) ...List.generate(3 - row.length, (_) => pw.Expanded(child: pw.SizedBox())),
              ]))).toList()),
          ]));
    } else {
      final pageFormat = PdfPageFormat(
        (settings.labelWidth / 25.4) * 72, 
        (settings.labelHeight / 25.4) * 72, 
        marginLeft: marginX, 
        marginTop: marginY, 
        marginRight: marginX, 
        marginBottom: marginY,
      );
      for (final p in printable) {
        pdf.addPage(pw.Page(pageFormat: pageFormat, build: (context) => pw.Center(child: _buildLabelWidget(p, settings, isVertical: false, compact: true))));
      }
    }

    await PrintingHelper.printWithFallback(
      doc: pdf,
      targetPrinterName: settings.labelPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Etiquettes_Produits',
    );
  }

  static pw.Widget _buildLabelWidget(Product p, ShopSettings settings, {required bool isVertical, bool compact = false}) {
    final barcodeData = (p.barcode?.trim() ?? "").isEmpty ? "123456789012" : p.barcode!.trim();
    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(barcodeData);
    
    Barcode barcodeType;
    String finalData = barcodeData;
    BarcodeGenerationModel effectiveModel = settings.barcodeModel;
    
    if (!isNumeric && (effectiveModel == BarcodeGenerationModel.ean13 || effectiveModel == BarcodeGenerationModel.upcA)) {
      effectiveModel = BarcodeGenerationModel.code128;
    }
    
    switch (effectiveModel) {
      case BarcodeGenerationModel.ean13:
        barcodeType = Barcode.ean13();
        finalData = barcodeData.padLeft(12, '0').substring(0, 12);
        finalData += _addEan13Checksum(finalData).substring(12);
        break;
      case BarcodeGenerationModel.upcA:
        barcodeType = Barcode.upcA();
        finalData = barcodeData.padLeft(11, '0').substring(0, 11);
        finalData += _addUpcAChecksum(finalData).substring(11);
        break;
      case BarcodeGenerationModel.numeric9:
        barcodeType = Barcode.code128(useCode128C: true);
        finalData = barcodeData.padLeft(9, '0').substring(0, 9);
        break;
      case BarcodeGenerationModel.code128:
        barcodeType = Barcode.code128();
        finalData = barcodeData;
        break;
    }

    final double labelHeightPts = (settings.labelHeight / 25.4) * 72;
    final double titleSize = labelHeightPts * (compact ? 0.14 : 0.12);
    final double priceSize = labelHeightPts * (compact ? 0.18 : 0.15);

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: pw.EdgeInsets.all(compact ? 2 : 4),
      decoration: compact ? null : pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5), 
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(settings.name.toUpperCase(), 
            style: pw.TextStyle(fontSize: titleSize * 0.7, fontWeight: pw.FontWeight.bold, color: compact ? PdfColors.black : PdfColors.grey700)),
          if (settings.showNameOnLabels) 
            pw.Text(p.name, maxLines: 1, 
              style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold, color: PdfColors.black), 
              overflow: pw.TextOverflow.clip),
          pw.SizedBox(height: compact ? 1 : 2),
          pw.Expanded(
            child: pw.BarcodeWidget(
              barcode: barcodeType, 
              data: finalData, 
              width: double.infinity, 
              height: double.infinity, 
              drawText: settings.showSkuOnLabels,
              textStyle: pw.TextStyle(fontSize: priceSize * 0.55, fontWeight: pw.FontWeight.bold),
              color: PdfColors.black,
            ),
          ),
          if (settings.showPriceOnLabels) ...[
            pw.SizedBox(height: compact ? 1 : 2),
            pw.Text(
              DateFormatter.formatCurrency(p.sellingPrice, settings.currency, removeDecimals: settings.removeDecimals), 
              style: pw.TextStyle(fontSize: priceSize, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ],
        ],
      ),
    );
  }

  static Future<Uint8List> generateSampleLabelPdf(ShopSettings settings) async {
    final font = PdfResourceService.instance.regular; 
    final fontBold = PdfResourceService.instance.bold;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    
    // Données de démonstration adaptées au standard pour un rendu visuel parlant
    String sampleBarcode = "123456789012";
    if (settings.barcodeModel == BarcodeGenerationModel.code128) {
      sampleBarcode = "PROD-ABC-123";
    } else if (settings.barcodeModel == BarcodeGenerationModel.numeric9) {
      sampleBarcode = "987654321";
    }

    final p = Product(
      id: "demo", 
      name: "Article Démonstration", 
      sellingPrice: 75000, 
      barcode: sampleBarcode, 
      alertThreshold: 5, 
      quantity: 10
    );

    final double marginX = settings.marginLabelX * PdfPageFormat.mm;
    final double marginY = settings.marginLabelY * PdfPageFormat.mm;

    if (settings.labelFormat == LabelPrintingFormat.a4Sheets) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.symmetric(horizontal: 12 + marginX, vertical: 12 + marginY),
        build: (context) => pw.Column(
          children: List.generate(4, (rowIndex) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              children: List.generate(3, (colIndex) => pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: _buildLabelWidget(p, settings, isVertical: true),
                ),
              )),
            ),
          )),
        ),
      ));
    } else {
      final pageFormat = PdfPageFormat(
        (settings.labelWidth / 25.4) * 72, 
        (settings.labelHeight / 25.4) * 72, 
        marginLeft: 2 + marginX, 
        marginTop: 2 + marginY, 
        marginRight: 2 + marginX, 
        marginBottom: 2 + marginY,
      );
      pdf.addPage(pw.Page(
        pageFormat: pageFormat, 
        build: (context) => pw.Center(
          child: _buildLabelWidget(p, settings, isVertical: false, compact: true),
        ),
      ));
    }
    return pdf.save();
  }


  Future<String> generateAutoRef(String? cat, String prefix, [ReferenceGenerationModel? model, int offset = 0]) async {
    final s = await _ref.read(shopSettingsProvider.future);
    final m = model ?? s.refModel;
    final now = (DateTime.now().millisecondsSinceEpoch + offset).toString();
    switch (m) {
      case ReferenceGenerationModel.categorical: return "${prefix.toUpperCase()}-${(cat ?? "GEN").substring(0, 3).toUpperCase()}-${now.substring(now.length - 4)}";
      case ReferenceGenerationModel.sequential: return "${prefix.toUpperCase()}-${(await _ref.read(productRepositoryProvider).getAll()).length + 1 + offset}";
      case ReferenceGenerationModel.random: return "${prefix.toUpperCase()}-${now.substring(now.length - 4)}";
      case ReferenceGenerationModel.timestamp: return "${prefix.toUpperCase()}-${now.substring(now.length - 6)}";
    }
  }

  Future<String> generateNumericBarcode([BarcodeGenerationModel? model, int offset = 0]) async {
    final s = await _ref.read(shopSettingsProvider.future);
    final m = model ?? s.barcodeModel;
    final now = (DateTime.now().millisecondsSinceEpoch + offset).toString();
    
    switch (m) {
      case BarcodeGenerationModel.ean13:
        return _addEan13Checksum("200${now.substring(now.length - 9).padLeft(9, '0')}");
      case BarcodeGenerationModel.upcA:
        return _addUpcAChecksum("0${now.substring(now.length - 10).padLeft(10, '0')}");
      case BarcodeGenerationModel.numeric9:
        return now.substring(now.length - 9).padLeft(9, '0');
      case BarcodeGenerationModel.code128:
        return "BRC${now.substring(now.length - 8)}";
    }
  }

  static String _addEan13Checksum(String data) {
    if (data.length < 12) data = data.padLeft(12, '0');
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(data[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checksum = (10 - (sum % 10)) % 10;
    return data + checksum.toString();
  }

  static String _addUpcAChecksum(String data) {
    if (data.length < 11) data = data.padLeft(11, '0');
    int sum = 0;
    for (int i = 0; i < 11; i++) {
      int digit = int.parse(data[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    int checksum = (10 - (sum % 10)) % 10;
    return data + checksum.toString();
  }

  Future<String> generateUniqueBarcode() async {
    return await generateNumericBarcode(null, 0);
  }

  Future<List<int>?> generateTemplate() async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Modele_Import';

    final headers = [
      'Nom du Produit (Obligatoire)',
      'Catégorie',
      'Référence (Optionnel)',
      'Code-barres (Optionnel)',
      'Unité (ex: Pièce, Kg)',
      'Prix d\'Achat',
      'Prix de Vente',
      'Quantité Initiale',
      'Seuil d\'Alerte',
      'Est un Service ? (1=Oui, 0=Non)',
      'Description',
      'Entrepôt'
    ];

    for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }
}
