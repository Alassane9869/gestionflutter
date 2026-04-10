
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

class InventoryAutomationService {
  final Ref _ref;
  final _uuid = const Uuid();

  InventoryAutomationService(this._ref);

  /// Génère un modèle Excel "Ultra Pro V3" pour l'importation des produits
  Future<List<int>?> generateTemplate() async {
    final settings = await _ref.read(shopSettingsProvider.future);
    final xlsio.Workbook workbook = xlsio.Workbook();
    
    // --- FEUILLE 1 : INSTRUCTIONS ---
    final xlsio.Worksheet helpSheet = workbook.worksheets[0];
    helpSheet.name = "INSTRUCTIONS";
    helpSheet.showGridlines = false;
    
    final helpTitle = helpSheet.getRangeByIndex(2, 2);
    helpTitle.setText(settings.name.toUpperCase());
    helpTitle.cellStyle.fontSize = 24;
    helpTitle.cellStyle.bold = true;
    helpTitle.cellStyle.fontColor = '#1E3A8A';
    
    final helpSubtitle = helpSheet.getRangeByIndex(4, 2);
    helpSubtitle.setText("GABARIT PROFESSIONNEL V3 - UNITÉS & SERVICES");
    helpSubtitle.cellStyle.fontSize = 14;
    helpSubtitle.cellStyle.italic = true;
    helpSubtitle.cellStyle.fontColor = '#4B5563';

    final instructions = [
      "✅ ÉDITION : Allez sur l'onglet 'IMPORT_PRODUITS' pour saisir vos articles.",
      "📌 TYPES : Colonne E -> Utilisez '0' pour un Article Physique et '1' pour un Service.",
      "⚖️ UNITÉS : Colonne D -> Choisissez l'unité (kg, g, Pièce, Heure, etc.).",
      "🎨 COULEURS : Les colonnes BLEUES sont obligatoires. Les VERTES sont automatiques.",
      "💰 MARGE : La colonne 'Marge' calcule votre profit potentiel en temps réel (H = G - F).",
      "⚡ STOCK : Pour les Services (Type 1), le stock n'est pas géré.",
      "📂 FINALISATION : Enregistrez et importez ce fichier dans Danaya+."
    ];
    
    for (int i = 0; i < instructions.length; i++) {
        final cell = helpSheet.getRangeByIndex(7 + i, 2);
        cell.setText(instructions[i]);
        cell.cellStyle.fontSize = 11;
    }
    
    helpSheet.setColumnWidthInPixels(2, 650);
    helpSheet.protect("danaya_plus_secure");

    // --- FEUILLE 2 : DONNÉES ---
    final xlsio.Worksheet sheet = workbook.worksheets.addWithName("IMPORT_PRODUITS");
    sheet.showGridlines = true;

    final headerRange = sheet.getRangeByName('A1:N1');
    headerRange.merge();
    final headerTitle = sheet.getRangeByName('A1');
    headerTitle.setText("📦 RÉFÉRENTIEL PRODUITS V3 - ${settings.name.toUpperCase()}");
    headerTitle.cellStyle.backColor = '#1F2937';
    headerTitle.cellStyle.fontColor = '#FFFFFF';
    headerTitle.cellStyle.bold = true;
    headerTitle.cellStyle.fontSize = 16;
    headerTitle.cellStyle.hAlign = xlsio.HAlignType.center;
    headerTitle.cellStyle.vAlign = xlsio.VAlignType.center;
    sheet.setRowHeightInPixels(1, 50);

    final categories = await _ref.read(productRepositoryProvider).getCategories();
    final warehouses = await _ref.read(warehouseListProvider.future);
    
    final catList = categories.isEmpty ? ["Divers", "Alimentation", "BTP", "Services"] : categories;
    final whList = warehouses.isEmpty ? ["Magasin Principal"] : warehouses.map((w) => w.name).toList();
    final unitList = ['Pièce', 'kg', 'g', 'Litre', 'Mètre', 'Sac', 'Boîte', 'Heure', 'Jour', 'Forfait', 'Unité'];

    // Styles
    final xlsio.Style headerStyleOpt = workbook.styles.add('headerStyleOpt');
    headerStyleOpt.backColor = '#374151'; headerStyleOpt.fontColor = '#FFFFFF'; headerStyleOpt.bold = true;
    headerStyleOpt.hAlign = xlsio.HAlignType.center; headerStyleOpt.vAlign = xlsio.VAlignType.center;
    headerStyleOpt.borders.all.lineStyle = xlsio.LineStyle.thin;

    final xlsio.Style headerStyleMandatory = workbook.styles.add('headerStyleMandatory');
    headerStyleMandatory.backColor = '#1E40AF'; headerStyleMandatory.fontColor = '#FFFFFF'; headerStyleMandatory.bold = true;
    headerStyleMandatory.hAlign = xlsio.HAlignType.center; headerStyleMandatory.vAlign = xlsio.VAlignType.center;
    headerStyleMandatory.borders.all.lineStyle = xlsio.LineStyle.thin;

    final xlsio.Style headerStyleAuto = workbook.styles.add('headerStyleAuto');
    headerStyleAuto.backColor = '#065F46'; headerStyleAuto.fontColor = '#FFFFFF'; headerStyleAuto.bold = true;
    headerStyleAuto.hAlign = xlsio.HAlignType.center; headerStyleAuto.vAlign = xlsio.VAlignType.center;
    headerStyleAuto.borders.all.lineStyle = xlsio.LineStyle.thin;

    final List<String> headers = [
      "Référence", "Nom*", "Catégorie", "Unité", "Type (0:Art, 1:Serv)*", "Prix Achat*", 
      "Prix Vente*", "Marge Brute (Auto)", "Quantité*", "Alerte Stock", "Description", "Code-barres", "Entrepôt", "Emplacement"
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(2, i + 1);
      cell.setText(headers[i]);
      if (["Nom*", "Type (0:Art, 1:Serv)*", "Prix Achat*", "Prix Vente*", "Quantité*"].contains(headers[i])) {
        cell.cellStyle = headerStyleMandatory;
      } else if (headers[i] == "Marge Brute (Auto)") {
        cell.cellStyle = headerStyleAuto;
      } else {
        cell.cellStyle = headerStyleOpt;
      }
      
      double width = 15;
      if (i == 1) width = 35; // Nom
      if (i == 4) width = 18; // Type
      if (i == 7) width = 18; // Marge
      if (i == 10) width = 40; // Description
      sheet.setColumnWidthInPixels(i + 1, (width * 8).toInt());
    }
    sheet.setRowHeightInPixels(2, 25);

    sheet.autoFilters.filterRange = sheet.getRangeByName('A2:N2000');
    sheet.getRangeByName('A3').freezePanes();

    // Validations
    final validationCat = sheet.getRangeByName('C3:C1000').dataValidation;
    validationCat.listOfValues = catList.take(25).toList();
    
    final validationUnit = sheet.getRangeByName('D3:D1000').dataValidation;
    validationUnit.listOfValues = unitList;

    final validationType = sheet.getRangeByName('E3:E1000').dataValidation;
    validationType.listOfValues = ['0', '1'];
    validationType.errorBoxText = '0 pour Produit Physique, 1 pour Service.';

    final validationWh = sheet.getRangeByName('M3:M1000').dataValidation;
    validationWh.listOfValues = whList.take(25).toList();

    // Formules & Formats
    final String currencyFormat = '#,##0 "${settings.currency}"';
    for (int r = 3; r <= 100; r++) {
        for (int col = 1; col <= 14; col++) {
          sheet.getRangeByIndex(r, col).cellStyle.fontColor = '#000000';
        }
        final margeCell = sheet.getRangeByIndex(r, 8);
        margeCell.setFormula("=G$r-F$r");
        margeCell.cellStyle.backColor = '#F9FAFB';
        margeCell.cellStyle.numberFormat = currencyFormat;
        sheet.getRangeByIndex(r, 6).cellStyle.numberFormat = currencyFormat;
        sheet.getRangeByIndex(r, 7).cellStyle.numberFormat = currencyFormat;
    }

    // Conditionnel
    final conditions = sheet.getRangeByName('H3:H100').conditionalFormats;
    final pC = conditions.addCondition();
    pC.formatType = xlsio.ExcelCFType.cellValue; pC.operator = xlsio.ExcelComparisonOperator.greater;
    pC.firstFormula = '0'; pC.backColor = '#DCFCE7'; pC.fontColor = '#166534';
    
    final lC = conditions.addCondition();
    lC.formatType = xlsio.ExcelCFType.cellValue; lC.operator = xlsio.ExcelComparisonOperator.less;
    lC.firstFormula = '0'; lC.backColor = '#FEE2E2'; lC.fontColor = '#991B1B';

    // Exemple
    sheet.getRangeByIndex(3, 1).setText("REF-V3-01");
    sheet.getRangeByIndex(3, 2).setText("Article Exemple");
    sheet.getRangeByIndex(3, 4).setText("kg");
    sheet.getRangeByIndex(3, 5).setText("0");
    sheet.getRangeByIndex(3, 6).setNumber(1000); 
    sheet.getRangeByIndex(3, 7).setNumber(1500); 
    sheet.getRangeByIndex(3, 9).setNumber(50.5);

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  /// Importe les produits depuis un fichier Excel (Support V1, V2 et V3)
  Future<ImportResult> importFromExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return ImportResult(0, 1, ["Fichier vide."]);
    Sheet? importSheet = excel.tables["IMPORT_PRODUITS"] ?? excel.tables.values.first;
    
    int importedCount = 0; int errorCount = 0; List<String> errors = [];
    final settings = await _ref.read(shopSettingsProvider.future);
    final warehouses = await _ref.read(warehouseListProvider.future);

    // Détection de version par en-tête
    int startRow = 1;
    bool isV3 = false; bool isV2 = false;
    
    if (importSheet.maxRows > 2) {
      final h = importSheet.rows[1];
      if (h.length > 5 && h[4]?.value?.toString().contains("Type") == true) {
        isV3 = true;
      } else if (h.length > 5 && h[5]?.value?.toString().contains("Marge") == true) { isV2 = true; }
      if (isV3 || isV2) {
        startRow = 2;
      }
    }

    for (var i = startRow; i < importSheet.maxRows; i++) {
      try {
        final row = importSheet.rows[i];
        if (row.isEmpty || row[1]?.value == null) continue;

        int cRef = 0, cName = 1, cCat = 2, cUnit = -1, cType = -1, cAchat = 3, cVente = 4, cQte = 5, cAlert = 6, cDesc = 7, cBar = 8, cWh = -1, cLoc = -1;
        
        if (isV3) {
           cUnit = 3; cType = 4; cAchat = 5; cVente = 6; cQte = 8; cAlert = 9; cDesc = 10; cBar = 11; cWh = 12; cLoc = 13;
        } else if (isV2) {
           cQte = 6; cAlert = 7; cDesc = 8; cBar = 9; cWh = 10; cLoc = 11;
        }

        String? refCode = row[cRef]?.value?.toString();
        final name = row[cName]!.value.toString();
        final category = row[cCat]?.value?.toString();
        final unit = (cUnit != -1 && row.length > cUnit) ? row[cUnit]?.value?.toString() : null;
        final typeVal = (cType != -1 && row.length > cType) ? row[cType]?.value?.toString() : "0";
        final isService = typeVal == "1";
        
        final purchasePrice = (double.tryParse(row[cAchat]?.value?.toString() ?? '0') ?? 0.0).abs();
        final sellingPrice = (double.tryParse(row[cVente]?.value?.toString() ?? '0') ?? 0.0).abs();
        final quantity = (double.tryParse(row[cQte]?.value?.toString() ?? '0') ?? 0.0).abs();
        final alert = (double.tryParse(row[cAlert]?.value?.toString() ?? '5') ?? 5.0).abs();
        final desc = (cDesc != -1 && row.length > cDesc) ? row[cDesc]?.value?.toString() : null;
        String? barcode = (cBar != -1 && row.length > cBar) ? row[cBar]?.value?.toString() : null;
        String? whName = (cWh != -1 && row.length > cWh) ? row[cWh]?.value?.toString() : null;
        String? loc = (cLoc != -1 && row.length > cLoc) ? row[cLoc]?.value?.toString() : null;

        String? whId;
        if (whName != null && whName.isNotEmpty) {
          try { whId = warehouses.firstWhere((w) => w.name.toLowerCase() == whName.trim().toLowerCase()).id; } catch (_) {}
        }

        if (settings.useAutoRef && (refCode == null || refCode.isEmpty)) {
          refCode = await generateAutoRef(category, settings.refPrefix, null, i);
        }
        if (barcode == null || barcode.isEmpty) barcode = await generateNumericBarcode(null, i);

        final product = Product(
          id: _uuid.v4(), name: name, reference: refCode, barcode: barcode,
          category: category, unit: unit, isService: isService,
          quantity: isService ? 0.0 : quantity,
          purchasePrice: purchasePrice, sellingPrice: sellingPrice,
          alertThreshold: isService ? 0.0 : alert,
          description: desc, location: loc,
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

  /// Assigne des références automatiques aux produits qui n'en ont pas
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

  /// Génère un PDF avec des étiquettes de codes-barres pour impression
  Future<void> printBarcodeLabels(List<Product> products) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final settings = await _ref.read(shopSettingsProvider.future);
    
    final printable = products.where((p) => p.barcode != null && p.barcode!.isNotEmpty).toList();

    if (printable.isEmpty) throw Exception("Aucun code-barres trouvé.");

    if (settings.labelFormat == LabelPrintingFormat.a4Sheets) {
      final List<List<Product>> rows = [];
      for (var i = 0; i < printable.length; i += 3) {
        rows.add(printable.sublist(i, i + 3 > printable.length ? printable.length : i + 3));
      }
      pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          build: (context) => [
            pw.Column(children: rows.map((row) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(children: [
                ...row.map((p) => pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  child: InventoryAutomationService._buildLabelWidget(p, settings, isVertical: true)))),
                if (row.length < 3) ...List.generate(3 - row.length, (_) => pw.Expanded(child: pw.SizedBox())),
              ]))).toList()),
          ]));
    } else {
      final pageFormat = PdfPageFormat((settings.labelWidth / 25.4) * 72, (settings.labelHeight / 25.4) * 72, marginAll: 2);
      for (final p in printable) {
        pdf.addPage(pw.Page(pageFormat: pageFormat, build: (context) => pw.Center(child: InventoryAutomationService._buildLabelWidget(p, settings, isVertical: false, compact: true))));
      }
    }

    await PrintingHelper.printWithFallback(
      doc: pdf,
      targetPrinterName: settings.labelPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Etiquettes_Produits',
    );
  }

  static Future<Uint8List> generateSampleLabelPdf(ShopSettings settings) async {
    final font = PdfResourceService.instance.regular; final fontBold = PdfResourceService.instance.bold;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    final p = Product(id: "demo", name: "Article Démonstration", sellingPrice: 75000, barcode: "1234567890128", alertThreshold: 5, quantity: 10);
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat((settings.labelWidth / 25.4) * 72, (settings.labelHeight / 25.4) * 72, marginAll: 2),
      build: (context) => pw.Center(child: _buildLabelWidget(p, settings, isVertical: false, compact: true))));
    return pdf.save();
  }

  static pw.Widget _buildLabelWidget(Product p, ShopSettings settings, {required bool isVertical, bool compact = false}) {
    final barcodeData = p.barcode ?? "";
    bool isEan13 = barcodeData.length == 13 && RegExp(r'^\d+$').hasMatch(barcodeData);
    return pw.Container(margin: const pw.EdgeInsets.all(2), padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(fontSize: compact ? 6 : 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          if (settings.showNameOnLabels) pw.Text(p.name, maxLines: 1, style: pw.TextStyle(fontSize: compact ? 7 : 10, fontWeight: pw.FontWeight.bold)),
          pw.BarcodeWidget(barcode: isEan13 ? Barcode.ean13() : Barcode.code128(), data: barcodeData, width: double.infinity, height: compact ? 25 : 35, drawText: false),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              if (settings.showSkuOnLabels) pw.Text(p.barcode ?? p.reference ?? "", style: pw.TextStyle(fontSize: compact ? 6 : 8)),
              if (settings.showPriceOnLabels) pw.Text("  ${DateFormatter.formatCurrency(p.sellingPrice, settings.currency)}", style: pw.TextStyle(fontSize: compact ? 8 : 11, fontWeight: pw.FontWeight.bold)),
          ]),
      ]));
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
    if (m == BarcodeGenerationModel.ean13) return _addEan13Checksum("200${now.substring(now.length - 9).padLeft(9, '0')}");
    return "BRC${now.substring(now.length - 8)}";
  }

  String _addEan13Checksum(String s) {
    int sum = 0; for (int i = 0; i < 12; i++) { sum += int.parse(s[i]) * (i % 2 == 0 ? 1 : 3); }
    return "$s${(10 - (sum % 10)) % 10}";
  }
}
