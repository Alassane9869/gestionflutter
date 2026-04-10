import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';

class PurchasePdfData {
  final PurchaseOrder order;
  final Supplier supplier;
  final List<PurchasePdfItem> items;
  final ShopSettings settings;

  const PurchasePdfData({
    required this.order,
    required this.supplier,
    required this.items,
    required this.settings,
  });
}

class PurchasePdfItem {
  final String productName;
  final double quantity;
  final double unitCost;

  const PurchasePdfItem({
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });

  double get total => quantity * unitCost;
}

class PurchasePdfService {
  static const _pageFormat = PdfPageFormat.a4;

  static Future<void> generateAndPrint(PurchasePdfData data) async {
    final doc = await _build(data);
    final settings = data.settings;

    await PrintingHelper.printWithFallback(
      doc: doc,
      targetPrinterName: settings.purchaseOrderPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Bon_Commande_${data.order.reference}',
    );
  }

  static Future<pw.Document> _build(PurchasePdfData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final currency = data.settings.currency;
    final template = data.settings.defaultPurchaseOrder;

    switch (template) {
      case PurchaseOrderTemplate.classic:
        return _buildClassic(doc, data, currency);
      case PurchaseOrderTemplate.modern:
        return _buildModern(doc, data, currency);
      case PurchaseOrderTemplate.professional:
      case PurchaseOrderTemplate.clean:
      case PurchaseOrderTemplate.supreme:
        return _buildPro(doc, data, currency);
      case PurchaseOrderTemplate.compact:
        return _buildCompact(doc, data, currency);
    }
  }

  static pw.Document _buildCompact(pw.Document doc, PurchasePdfData data, String currency) {
    final accent = PdfColor.fromHex('#1A237E'); // Deep Indigo
    final grey = PdfColors.grey700;
    
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // COMPACT LANDSCAPE HEADER
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(data.settings.name.toUpperCase(), 
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(data.settings.slogan, 
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("BON DE COMMANDE", 
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text("Réf: ${data.order.reference}", 
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey100)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // INFO SECTION IN 3 COLUMNS
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // SHOP INFO
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("ÉMETTEUR", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                    pw.SizedBox(height: 4),
                    pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("Tél: ${data.settings.phone}", style: const pw.TextStyle(fontSize: 9)),
                    if (data.settings.email.isNotEmpty) pw.Text(data.settings.email, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // SUPPLIER INFO
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("FOURNISSEUR", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                    pw.SizedBox(height: 4),
                    pw.Text(data.supplier.name.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    if (data.supplier.phone != null) pw.Text("Tél: ${data.supplier.phone}", style: const pw.TextStyle(fontSize: 9)),
                    if (data.supplier.address != null) pw.Text(data.supplier.address!, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // ORDER DETAILS
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("DÉTAILS", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                    pw.SizedBox(height: 4),
                    pw.Text("Date: ${DateFormatter.formatDate(data.order.date)}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("Statut: ${data.order.status.name.toUpperCase()}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Paiement: ${data.order.isCredit ? 'À Crédit' : 'Comptant'}", style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ITEMS TABLE
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: accent),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
            cellPadding: const pw.EdgeInsets.all(8),
            headers: ['DÉSIGNATION', 'QUANTITÉ', 'PRIX UNITAIRE', 'MONTANT TOTAL'],
            data: data.items.map((it) => [
              it.productName,
              DateFormatter.formatQuantity(it.quantity),
              DateFormatter.formatCurrency(it.unitCost, currency, removeDecimals: data.settings.removeDecimals),
              DateFormatter.formatCurrency(it.total, currency, removeDecimals: data.settings.removeDecimals),
            ]).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(100),
              2: const pw.FixedColumnWidth(150),
              3: const pw.FixedColumnWidth(150),
            },
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 20),

          // FOOTER / SIGNATURES
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Notes:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grey)),
                  pw.Text("Merci pour votre partenariat.", style: pw.TextStyle(fontSize: 8, color: grey)),
                ],
              ),
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("TOTAL COMMANDE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
                        pw.Text(DateFormatter.formatCurrency(data.order.totalAmount, currency, removeDecimals: data.settings.removeDecimals), 
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return doc;
  }

  static pw.Document _buildClassic(pw.Document doc, PurchasePdfData data, String currency) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.all(data.settings.marginInvoiceTop),
        header: (ctx) => _buildStandardHeader(data, PdfColors.black),
        footer: (ctx) => _buildStandardFooter(data),
        build: (ctx) => [
          _buildInfoSection(data, PdfColors.black),
          pw.SizedBox(height: 20),
          _buildItemsTable(data, currency, PdfColors.black),
          pw.SizedBox(height: 20),
          _buildTotalSection(data, currency, PdfColors.black),
        ],
      ),
    );
    return doc;
  }

  static pw.Document _buildModern(pw.Document doc, PurchasePdfData data, String currency) {
    final accent = PdfColors.teal700;
    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.all(data.settings.marginInvoiceTop),
        header: (ctx) => _buildStandardHeader(data, accent, isModern: true),
        footer: (ctx) => _buildStandardFooter(data),
        build: (ctx) => [
          _buildInfoSection(data, accent),
          pw.SizedBox(height: 20),
          _buildItemsTable(data, currency, accent, isModern: true),
          pw.SizedBox(height: 20),
          _buildTotalSection(data, currency, accent),
        ],
      ),
    );
    return doc;
  }

  static pw.Document _buildPro(pw.Document doc, PurchasePdfData data, String currency) {
    final accent = PdfColors.blue800;
    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.all(data.settings.marginInvoiceTop),
        header: (ctx) => _buildProHeader(data, accent),
        footer: (ctx) => _buildStandardFooter(data),
        build: (ctx) => [
          _buildInfoSection(data, accent),
          pw.SizedBox(height: 20),
          _buildItemsTable(data, currency, accent, isPro: true),
          pw.SizedBox(height: 20),
          _buildTotalSection(data, currency, accent, isPro: true),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _buildStandardHeader(PurchasePdfData data, PdfColor accent, {bool isModern = false}) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Tél: ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("BON DE COMMANDE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.Text('Réf: ${data.order.reference}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Date: ${DateFormatter.formatDate(data.order.date)}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1, color: accent),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildProHeader(PurchasePdfData data, PdfColor accent) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: accent)),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(color: accent, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Text("BON DE COMMANDE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Tél: ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('N° ${data.order.reference}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text('Date: ${DateFormatter.formatPremium(data.order.date)}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 2, color: accent),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildInfoSection(PurchasePdfData data, PdfColor accent) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("FOURNISSEUR", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.SizedBox(height: 4),
                pw.Text(data.supplier.name.toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                if (data.supplier.phone != null) pw.Text('Tél: ${data.supplier.phone}', style: const pw.TextStyle(fontSize: 9)),
                if (data.supplier.email != null) pw.Text('Email: ${data.supplier.email}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(child: pw.SizedBox()),
      ],
    );
  }

  static pw.Widget _buildItemsTable(PurchasePdfData data, String currency, PdfColor accent, {bool isModern = false, bool isPro = false}) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: (isModern || isPro) ? PdfColors.white : PdfColors.black),
      headerDecoration: (isModern || isPro) ? pw.BoxDecoration(color: accent) : null,
      headers: ['DÉSIGNATION', 'QTÉ', 'P.U ($currency)', 'TOTAL ($currency)'],
      data: data.items.map((it) => [
        it.productName,
        DateFormatter.formatQuantity(it.quantity),
        DateFormatter.formatCurrency(it.unitCost, '', removeDecimals: data.settings.removeDecimals),
        DateFormatter.formatCurrency(it.total, '', removeDecimals: data.settings.removeDecimals),
      ]).toList(),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(100),
        3: const pw.FixedColumnWidth(100),
      },
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      border: isPro ? null : pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static pw.Widget _buildTotalSection(PurchasePdfData data, String currency, PdfColor accent, {bool isPro = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(12),
          decoration: isPro ? pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))) : null,
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL BRUT', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(DateFormatter.formatCurrency(data.order.totalAmount, currency, removeDecimals: data.settings.removeDecimals), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 1, color: accent),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('À RÉGLER', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: accent)),
                  pw.Text(DateFormatter.formatCurrency(data.order.totalAmount, currency, removeDecimals: data.settings.removeDecimals), 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStandardFooter(PurchasePdfData data) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('${_c(data.settings.name)} - ${_c(data.settings.address)} - Tél: ${_c(data.settings.phone)}', 
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('Bon de Commande - Document Interne', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic)),
          ],
        ),
      ],
    );
  }

  static String _c(String? t) {
    if (t == null) return "";
    return t.replaceAll('—', '-').replaceAll('📞', 'Tél: ').replaceAll('™', '').replaceAll('®', '');
  }
}
