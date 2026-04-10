import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
class QuoteData {
  final String quoteNumber;
  final DateTime date;
  final DateTime? validUntil;
  final List<QuoteItem> items;
  final double subtotal;
  final double taxRate;
  final double totalAmount;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final String cashierName;
  final ShopSettings settings;
  final String? saleId;
  final String? clientEmail;
  final QuoteTemplate? template;

  const QuoteData({
    required this.quoteNumber,
    required this.date,
    this.validUntil,
    required this.items,
    required this.subtotal,
    this.taxRate = 0,
    required this.totalAmount,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    required this.cashierName,
    required this.settings,
    this.saleId,
    this.clientEmail,
    this.template,
  });

  QuoteData copyWith({
    String? quoteNumber,
    DateTime? date,
    DateTime? validUntil,
    List<QuoteItem>? items,
    double? subtotal,
    double? taxRate,
    double? totalAmount,
    String? clientName,
    String? clientPhone,
    String? clientAddress,
    String? cashierName,
    ShopSettings? settings,
    String? saleId,
    String? clientEmail,
    QuoteTemplate? template,
  }) {
    return QuoteData(
      quoteNumber: quoteNumber ?? this.quoteNumber,
      date: date ?? this.date,
      validUntil: validUntil ?? this.validUntil,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      totalAmount: totalAmount ?? this.totalAmount,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAddress: clientAddress ?? this.clientAddress,
      cashierName: cashierName ?? this.cashierName,
      settings: settings ?? this.settings,
      saleId: saleId ?? this.saleId,
      clientEmail: clientEmail ?? this.clientEmail,
      template: template ?? this.template,
    );
  }

  String get documentTitle => settings.titleQuote;

  double get taxAmount => subtotal - (subtotal / (1 + taxRate));
  double get subtotalHT => subtotal - taxAmount;

  bool get shouldShowTax {
    if (!settings.useTax) return false;
    if (template != null) return settings.getTemplateShowTax('quote', template!.name);
    return settings.showTaxOnQuotes;
  }

  bool get shouldBeDetailed {
    if (!settings.useTax) return false;
    if (template != null) return settings.getTemplateDetailed('quote', template!.name);
    return settings.useDetailedTaxOnQuotes;
  }
}

class QuoteItem {
  final String name;
  final double qty;
  final double unitPrice;
  final String? unit;
  final String? description;
  final double discountAmount;

  const QuoteItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.unit,
    this.description,
    this.discountAmount = 0,
  });

  QuoteItem copyWith({
    String? name,
    double? qty,
    double? unitPrice,
    String? unit,
    String? description,
    double? discountAmount,
  }) {
    return QuoteItem(
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  double get lineTotal => (qty * unitPrice) - discountAmount;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote template enum
// ─────────────────────────────────────────────────────────────────────────────

// QuoteTemplate moved to settings_models.dart

// ─────────────────────────────────────────────────────────────────────────────
// QuoteService — builds and prints professional quotes
// ─────────────────────────────────────────────────────────────────────────────

class QuoteService {
  static const _pageFormat = PdfPageFormat.a4;

  static final _accent = PdfColor.fromHex(
    '#4F46E5',
  ); // Indigo moderne pour les devis Ultra Pro

  static Future<pw.Document> buildDocument(
    QuoteData data,
    QuoteTemplate template,
  ) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    return _build(eliteData, template);
  }

  static Future<Uint8List> generateSamplePdf(ShopSettings settings) async {
    final data = QuoteData(
      quoteNumber: "DEV-2024-0042",
      date: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 15)),
      items: [
        const QuoteItem(name: "Prestation Audit Informatique", qty: 1, unitPrice: 150000),
        const QuoteItem(name: "Installation Serveur Danaya", qty: 2, unitPrice: 75000),
      ],
      subtotal: 300000,
      totalAmount: 300000,
      cashierName: "DÉMO PRO",
      settings: settings,
      clientName: "Entreprise Cliente Démo",
      taxRate: settings.useTax ? (settings.taxRate / 100) : 0,
      template: settings.defaultQuote,
    );
    final doc = await _build(data, settings.defaultQuote);
    return doc.save();
  }

  static Future<void> print(QuoteData data, QuoteTemplate template) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    final doc = await _build(eliteData, template);
    final settings = data.settings;

    await PrintingHelper.printWithFallback(
      doc: doc,
      targetPrinterName: settings.quotePrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Devis_${data.quoteNumber.replaceAll(' ', '_')}',
    );
  }

  static String _c(String? t) {
    if (t == null) return "";
    return t.replaceAll('—', '-').replaceAll('📞', 'Tél: ').replaceAll('™', '').replaceAll('®', '').replaceAll('—', '-');
  }

  static Future<pw.Document> _build(QuoteData data, QuoteTemplate template) async {
    // Fonts are now pre-loaded at startup or lazily loaded synchronously via getters
    
    switch (template) {
      case QuoteTemplate.minimaliste:
        return _buildMinimaliste(data);
      case QuoteTemplate.style:
        return _buildStyle(data);
      case QuoteTemplate.prestige:
        return _buildPrestige(data);
      case QuoteTemplate.modern:
        return _buildModern(data);
      case QuoteTemplate.professional:
        return _buildProfessional(data);
      case QuoteTemplate.clean:
        return _buildClean(data);
      case QuoteTemplate.minimalist:
        return _buildMinimalist(data);
      case QuoteTemplate.corporate:
        return _buildCorporate(data);
      case QuoteTemplate.supreme:
        return _buildSupreme(data);
    }
  }

  // NOTE: Les signatures des méthodes de build sont similaires aux factures
  // mais adaptées pour afficher "DEVIS" et les dates de validité.

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 2 — MINIMALISTE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildMinimaliste(QuoteData data) async =>
      _baseBuild(data, "MINIMALISTE");

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 4 — STYLE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildStyle(QuoteData data) async =>
      _baseBuild(data, "STYLE");

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — CORPORATE (Cobalt bleu institutionnel)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildCorporate(QuoteData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final corporateBlue = PdfColor.fromHex('#0D47A1');
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(val, currency, removeDecimals: removeDecimals);


    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: _pageFormat,
        theme: doc.theme,
        margin: pw.EdgeInsets.fromLTRB(data.settings.marginInvoiceLeft, data.settings.marginInvoiceTop, data.settings.marginInvoiceRight, data.settings.marginInvoiceBottom),
      ),
      footer: (ctx) => _buildInstitutionnelFooter(data),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 20),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: corporateBlue, width: 2))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _buildAdaptiveLogo(data, maxWidth: 90, maxHeight: 55, margin: const pw.EdgeInsets.only(bottom: 8)),
                pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: corporateBlue, letterSpacing: 2)),
                if (data.settings.address.isNotEmpty) pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 8)),
                if (data.settings.phone.isNotEmpty) pw.Text('Tél: ${data.settings.phone}', style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(data.documentTitle, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: corporateBlue, letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(color: corporateBlue),
                  child: pw.Text('N° ${data.quoteNumber}', style: pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _sectionTitle('PROPOSÉ À'),
            pw.Text(data.clientName ?? 'Client Potentiel', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (data.clientPhone != null) pw.Text('Tél: ${data.clientPhone}', style: const pw.TextStyle(fontSize: 9)),
            if (data.clientAddress != null) pw.Text(data.clientAddress!, style: const pw.TextStyle(fontSize: 9)),
          ])),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _sectionTitle('VALIDITÉ'),
            pw.Text('Émis le: ${DateFormatter.formatLongDate(data.date)}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Valable jusqu\'au: ${data.validUntil != null ? DateFormatter.formatLongDate(data.validUntil!) : "30 jours"}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
          ])),
        ]),
        pw.SizedBox(height: 20),
        pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: corporateBlue), children: [
              _pCell('DÉSIGNATION', isHeader: true), _pCell('QTÉ', isHeader: true, align: pw.TextAlign.center),
              _pCell('P. UNITAIRE', isHeader: true, align: pw.TextAlign.right), _pCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
            ]),
            ...data.items.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : PdfColors.grey50),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e.value.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  if (e.value.description != null) pw.Text(e.value.description!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ])),
                _pCell(DateFormatter.formatQuantity(e.value.qty), align: pw.TextAlign.center),
                _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                _pCell(fmt(e.value.lineTotal), align: pw.TextAlign.right, bold: true, color: corporateBlue),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 240, child: pw.Column(children: [
            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _pTotalRow('SOUS-TOTAL HT', fmt(data.subtotalHT)),
              _pTotalRow('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
            ],
            pw.Divider(color: corporateBlue, thickness: 1.5),
            _pTotalRow('MONTANT TOTAL TTC', fmt(data.totalAmount), isBig: true, color: corporateBlue),
            if (data.shouldShowTax && !data.shouldBeDetailed)
              _pTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
          ])),
        ]),
      ],
    ));
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — MODERN (Bande latérale colorée)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildModern(QuoteData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final modernGreen = PdfColor.fromHex('#00796B');
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(val, currency, removeDecimals: removeDecimals);


    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: _pageFormat, theme: doc.theme,
        margin: pw.EdgeInsets.fromLTRB(data.settings.marginInvoiceLeft, data.settings.marginInvoiceTop, data.settings.marginInvoiceRight, data.settings.marginInvoiceBottom),
        buildBackground: (ctx) => pw.FullPage(ignoreMargins: true, child: pw.Stack(children: [
          pw.Positioned(left: 0, top: 0, bottom: 0, child: pw.Container(width: 8, color: modernGreen)),
        ])),
      ),
      footer: (ctx) => _buildInstitutionnelFooter(data),
      build: (ctx) => [
        pw.Padding(padding: const pw.EdgeInsets.only(left: 16), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _buildAdaptiveLogo(data, maxWidth: 80, maxHeight: 45, margin: const pw.EdgeInsets.only(bottom: 6)),
              pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (data.settings.slogan.isNotEmpty) pw.Text(data.settings.slogan, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
            ]),
            pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 10), color: modernGreen,
              child: pw.Column(children: [
                pw.Text('DEVIS', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Text('N° ${data.quoteNumber}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey200)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 20),
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CLIENT', style: pw.TextStyle(fontSize: 8, color: modernGreen, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
              pw.Text(data.clientName ?? 'Client Potentiel', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (data.clientPhone != null) pw.Text(data.clientPhone!, style: const pw.TextStyle(fontSize: 9)),
            ])),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Date: ${DateFormatter.formatDate(data.date)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Valable jusqu\'au: ${data.validUntil != null ? DateFormatter.formatDate(data.validUntil!) : "30 jours"}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ])),
          ]),
          pw.SizedBox(height: 20),
          pw.Table(
            columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: modernGreen), children: [
                _pCell('ARTICLE', isHeader: true), _pCell('QTÉ', isHeader: true, align: pw.TextAlign.center),
                _pCell('PRIX U.', isHeader: true, align: pw.TextAlign.right), _pCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
              ]),
              ...data.items.asMap().entries.map((e) => pw.TableRow(
                decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#E0F2F1')),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(e.value.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  _pCell(DateFormatter.formatQuantity(e.value.qty), align: pw.TextAlign.center),
                  _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                  _pCell(fmt(e.value.lineTotal), align: pw.TextAlign.right, bold: true, color: modernGreen),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(width: 200, child: pw.Column(children: [
              if (data.shouldShowTax && data.shouldBeDetailed) ...[
                _pTotalRow('TOTAL HT', fmt(data.subtotalHT)),
                _pTotalRow('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
              ],
              pw.Divider(color: modernGreen),
              _pTotalRow('TOTAL DEVIS TTC', fmt(data.totalAmount), isBig: true, color: modernGreen),
              if (data.shouldShowTax && !data.shouldBeDetailed)
                _pTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
            ])),
          ]),
        ])),
      ],
    ));
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — CLEAN (Épuré sans bordures)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildClean(QuoteData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final cleanAccent = PdfColor.fromHex('#546E7A');
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(val, currency, removeDecimals: removeDecimals);
    // validFmt removed and inlined below

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: _pageFormat, theme: doc.theme,
        margin: pw.EdgeInsets.fromLTRB(data.settings.marginInvoiceLeft, data.settings.marginInvoiceTop, data.settings.marginInvoiceRight, data.settings.marginInvoiceBottom),
      ),
      footer: (ctx) => _buildInstitutionnelFooter(data),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _buildAdaptiveLogo(data, maxWidth: 80, maxHeight: 45, margin: const pw.EdgeInsets.only(bottom: 8)),
            pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: cleanAccent)),
            if (data.settings.address.isNotEmpty) pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('DEVIS', style: pw.TextStyle(fontSize: 36, fontWeight: pw.FontWeight.bold, color: cleanAccent, letterSpacing: 3)),
            pw.Text('N° ${data.quoteNumber}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text('Émis le ${DateFormatter.formatDate(data.date)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ]),
        ]),
        pw.SizedBox(height: 8),
        pw.Divider(color: cleanAccent, thickness: 0.5),
        pw.SizedBox(height: 16),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('DESTINATAIRE', style: pw.TextStyle(fontSize: 8, color: cleanAccent, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
            pw.SizedBox(height: 4),
            pw.Text(data.clientName ?? 'Client Potentiel', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (data.clientPhone != null) pw.Text(data.clientPhone!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ])),
          pw.Text('Valable jusqu\'au : ${data.validUntil != null ? DateFormatter.formatDate(data.validUntil!) : "30 jours"}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
        ]),
        pw.SizedBox(height: 24),
        ...data.items.asMap().entries.map((e) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
          child: pw.Row(children: [
            pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e.value.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              if (e.value.description != null) pw.Text(e.value.description!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ])),
            pw.Expanded(flex: 1, child: pw.Text(DateFormatter.formatQuantity(e.value.qty), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(flex: 2, child: pw.Text(fmt(e.value.unitPrice), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
            pw.Expanded(flex: 2, child: pw.Text(fmt(e.value.lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: cleanAccent))),
          ]),
        )),
        pw.SizedBox(height: 24),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 200, child: pw.Column(children: [
            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _pTotalRow('SOUS-TOTAL HT', fmt(data.subtotalHT)),
              _pTotalRow('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
            ],
            pw.Divider(color: cleanAccent, thickness: 0.5),
            _pTotalRow('MONTANT DÛ TTC', fmt(data.totalAmount), isBig: true, color: cleanAccent),
            if (data.shouldShowTax && !data.shouldBeDetailed)
              _pTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
          ])),
        ]),
      ],
    ));
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — PROFESSIONAL (Sombre avec zone signature)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildProfessional(QuoteData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final darkColor = PdfColor.fromHex('#263238');
    final goldAccent = PdfColor.fromHex('#FFA000');
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(val, currency, removeDecimals: removeDecimals);

    String clean(String t) => t.replaceAll('—', '-').replaceAll('📞', 'Tél:');

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: _pageFormat,
        theme: doc.theme,
        margin: pw.EdgeInsets.fromLTRB(data.settings.marginInvoiceLeft, data.settings.marginInvoiceTop, data.settings.marginInvoiceRight, data.settings.marginInvoiceBottom),
      ),
      footer: (ctx) => _buildInstitutionnelFooter(data),
      build: (ctx) => [
        // En-tête Band coloré redimensionnable
        pw.Container(
          decoration: pw.BoxDecoration(
            color: darkColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(4),
              1: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                children: [
                  // Side Accent
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: goldAccent,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(4),
                        bottomLeft: pw.Radius.circular(4),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(20),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text(clean(data.settings.name).toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Text(clean(data.settings.slogan), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey300, fontStyle: pw.FontStyle.italic)),
                        ]),
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          pw.Text('DEVIS', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: goldAccent, letterSpacing: 2)),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(2)),
                            child: pw.Text('N° ${data.quoteNumber.toUpperCase()}', style: pw.TextStyle(fontSize: 10, color: darkColor, fontWeight: pw.FontWeight.bold)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        pw.SizedBox(height: 24),
        
        // Destinataire & Dates
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('PROPOSÉ À', style: pw.TextStyle(fontSize: 8, color: darkColor, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
              pw.SizedBox(height: 4),
              pw.Text(clean(data.clientName ?? 'Client Potentiel'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (data.clientPhone != null) pw.Text(clean(data.clientPhone!), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              if (data.clientAddress != null) pw.Text(clean(data.clientAddress!), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ])),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('MÉTRIQUES DEVIS', style: pw.TextStyle(fontSize: 8, color: darkColor, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
              pw.SizedBox(height: 4),
              pw.Text('DATE : ${DateFormatter.formatLongDate(data.date)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('VALIDITÉ : ${data.validUntil != null ? DateFormatter.formatLongDate(data.validUntil!) : "30 jours"}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ])),
          ],
        ),

        pw.SizedBox(height: 24),
        
        // Items Table
        pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: darkColor),
              children: [
                _pCell('PRESTATION / ARTICLE', isHeader: true),
                _pCell('QTÉ', isHeader: true, align: pw.TextAlign.center),
                _pCell('PRIX UNIT.', isHeader: true, align: pw.TextAlign.right),
                _pCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
              ]
            ),
            ...data.items.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#ECEFF1'), border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(clean(e.value.name), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  if (e.value.description != null) pw.Text(clean(e.value.description!), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ])),
                _pCell(DateFormatter.formatQuantity(e.value.qty), align: pw.TextAlign.center),
                _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                _pCell(fmt(e.value.lineTotal), align: pw.TextAlign.right, bold: true, color: darkColor),
              ],
            )),
          ],
        ),
        
        pw.SizedBox(height: 20),
        
        // Footer Totals
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
               pw.Text('SIGNATURE COMMERCIALE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkColor)),
               pw.SizedBox(height: 40),
               pw.Container(width: 150, height: 1, color: PdfColors.grey400),
            ]),
            pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: darkColor, width: 0.5)),
              child: pw.Column(children: [
                if (data.shouldShowTax && data.shouldBeDetailed) ...[
                  _pTotalRow('SOUS-TOTAL HT', fmt(data.subtotalHT)),
                  _pTotalRow('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
                ],
                pw.Divider(color: darkColor),
                _pTotalRow('NET À PAYER TTC', fmt(data.totalAmount), isBig: true, color: darkColor),
                if (data.shouldShowTax && !data.shouldBeDetailed)
                  _pTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
              ]),
            ),
          ],
        ),
      ],
    ));
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — MINIMALIST (Typographie pure, sans déco)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildMinimalist(QuoteData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(val, currency, removeDecimals: removeDecimals);


    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: _pageFormat, theme: doc.theme,
        margin: pw.EdgeInsets.fromLTRB(data.settings.marginInvoiceLeft, data.settings.marginInvoiceTop, data.settings.marginInvoiceRight, data.settings.marginInvoiceBottom),
      ),
      footer: (ctx) => _buildInstitutionnelFooter(data),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            if (data.settings.address.isNotEmpty) pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            if (data.settings.phone.isNotEmpty) pw.Text('Tél: ${data.settings.phone}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('DEVIS', style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.normal, letterSpacing: 4)),
            pw.Text(data.quoteNumber, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(DateFormatter.formatDate(data.date), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ]),
        ]),
        pw.SizedBox(height: 32),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('À l\'attention de', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text(data.clientName ?? 'Client Potentiel', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (data.clientPhone != null) pw.Text(data.clientPhone!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ])),
          pw.Text('Valable jusqu\'au: ${data.validUntil != null ? DateFormatter.formatDate(data.validUntil!) : "30 jours"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
        pw.SizedBox(height: 28),
        pw.Divider(color: PdfColors.black, thickness: 1),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Row(children: [
          pw.Expanded(flex: 5, child: pw.Text('DÉSIGNATION', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5))),
          pw.Expanded(flex: 1, child: pw.Text('QTÉ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text('PRIX U.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
        ])),
        pw.Divider(color: PdfColors.black, thickness: 0.5),
        ...data.items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          child: pw.Row(children: [
            pw.Expanded(flex: 5, child: pw.Text(item.name, style: const pw.TextStyle(fontSize: 10))),
            pw.Expanded(flex: 1, child: pw.Text(DateFormatter.formatQuantity(item.qty), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
            pw.Expanded(flex: 2, child: pw.Text(fmt(item.unitPrice), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
            pw.Expanded(flex: 2, child: pw.Text(fmt(item.lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          ]),
        )),
        pw.Divider(color: PdfColors.black, thickness: 0.5),
        pw.SizedBox(height: 16),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(width: 180, child: pw.Column(children: [
            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _pTotalRow(data.settings.labelHT, fmt(data.subtotalHT)),
              _pTotalRow('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
            ],
            _pTotalRow('TOTAL TTC', fmt(data.totalAmount), isBig: true),
            if (data.shouldShowTax && !data.shouldBeDetailed)
              _pTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
          ])),
        ]),
      ],
    ));
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 6 — ELITE
  // ══════════════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 7 — PRESTIGE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildPrestige(QuoteData data) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(
      val,
      currency,
      removeDecimals: removeDecimals,
    );
    final validFmt = data.validUntil != null
        ? DateFormatter.formatLongDate(data.validUntil!)
        : "30 jours";

    // Prestige Palette (Matching Invoice but for Devis)
    final primaryColor = PdfColor.fromHex('#455A64'); // Blue Grey sombre
    final accentColor = PdfColor.fromHex('#00897B'); // Sarcelle pro
    final lightGrey = PdfColor.fromHex('#F5F7F9');

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: _pageFormat,
          theme: doc.theme,
          margin: pw.EdgeInsets.fromLTRB(
            data.settings.marginInvoiceLeft,
            data.settings.marginInvoiceTop,
            data.settings.marginInvoiceRight,
            data.settings.marginInvoiceBottom,
          ),
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                pw.Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: pw.Container(width: 220, color: lightGrey),
                ),
              ],
            ),
          ),
        ),
        footer: (ctx) => _buildInstitutionnelFooter(data),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.all(0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildAdaptiveLogo(
                              data,
                              maxWidth: 100,
                              maxHeight: 60,
                              margin: const pw.EdgeInsets.only(bottom: 15),
                            ),
                            pw.Text(
                              data.settings.name.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 2,
                              ),
                            ),
                            pw.Text(
                              data.settings.slogan,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              data.documentTitle,
                              style: pw.TextStyle(
                                fontSize: 45,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: -2,
                              ),
                            ),
                            pw.Container(
                              height: 5,
                              width: 80,
                              color: accentColor,
                              margin: const pw.EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            pw.Text(
                              'N° PROPOSITION: ${data.quoteNumber.toUpperCase()}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 50),

                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'DESTINATAIRE',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              pw.Text(
                                data.clientName ?? 'Client Potentiel',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (data.clientPhone != null)
                                pw.Text(
                                  'Contact: ${data.clientPhone}',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              if (data.clientAddress != null)
                                pw.Text(
                                  data.clientAddress!,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'DÉTAILS DU DEVIS',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              pw.Text(
                                'Émis le: ${DateFormatter.formatLongDate(data.date)}',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              pw.Text(
                                'Valable jusqu\'au: $validFmt',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 40),

                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(6),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: primaryColor),
                          children: [
                            _pCell('DÉSIGNATION', isHeader: true),
                            _pCell(
                              'QTÉ',
                              isHeader: true,
                              align: pw.TextAlign.center,
                            ),
                            _pCell(
                              'P. UNITAIRE',
                              isHeader: true,
                              align: pw.TextAlign.right,
                            ),
                            _pCell(
                              'TOTAL HT',
                              isHeader: true,
                              align: pw.TextAlign.right,
                            ),
                          ],
                        ),
                        ...data.items.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: i % 2 == 0
                                  ? PdfColors.white
                                  : PdfColors.grey50,
                            ),
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                  if (item.description != null)
                                    pw.Text(
                                      item.description!,
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        fontStyle: pw.FontStyle.italic,
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                  if (item.discountAmount > 0)
                                    pw.Text(
                                      'Remise: -${fmt(item.discountAmount)}',
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColors.red700,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              _pCell(
                                "${DateFormatter.formatQuantity(item.qty)}${item.unit != null ? " ${item.unit}" : ""}",
                                align: pw.TextAlign.center,
                              ),
                              _pCell(
                                fmt(item.unitPrice),
                                align: pw.TextAlign.right,
                              ),
                              _pCell(
                                fmt(item.lineTotal),
                                align: pw.TextAlign.right,
                                bold: true,
                                color: primaryColor,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),

                    pw.SizedBox(height: 30),

                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'CONDITIONS DE VENTE',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              pw.Text(
                                '• Devis valable ${data.settings.quoteValidityDays} jours à compter de la date d\'émission.\n• ${data.settings.policyPayments.isNotEmpty ? data.settings.policyPayments : "Paiement selon conditions convenues."}\n• ${data.settings.policyWarranty.isNotEmpty ? data.settings.policyWarranty : "Articles sous réserve de disponibilité des stocks."}',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(15),
                            decoration: pw.BoxDecoration(
                              color: lightGrey,
                              border: pw.Border.all(color: PdfColors.grey300),
                            ),
                            child: pw.Column(
                              children: [
                                if (data.shouldShowTax && data.shouldBeDetailed) ...[
                                  _pTotalRow('TOTAL HT', fmt(data.subtotalHT)),
                                  _pTotalRow(
                                    'TVA (${(data.taxRate * 100).toInt()}%)',
                                    fmt(data.taxAmount),
                                  ),
                                ],
                                pw.Divider(color: PdfColors.grey400),
                                _pTotalRow(
                                  data.settings.labelTTC,
                                  fmt(data.totalAmount),
                                  isBig: true,
                                  color: accentColor,
                                ),
                                if (data.shouldShowTax && !data.shouldBeDetailed)
                                  _pTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _pCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        fontWeight: (isHeader || bold)
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
        fontSize: isHeader ? 9 : 10,
      ),
      textAlign: align,
    ),
  );

  static pw.Widget _pTotalRow(
    String label,
    String value, {
    bool isBig = false,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isBig ? 14 : 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );

  // Helper pour factoriser les designs (basés sur InvoiceService mais spécialisés DEVIS)
  static Future<pw.Document> _baseBuild(QuoteData data, String style) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(
      val,
      currency,
      removeDecimals: removeDecimals,
    );


    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: _pageFormat,
          theme: doc.theme,
          margin: pw.EdgeInsets.fromLTRB(
            data.settings.marginInvoiceLeft,
            data.settings.marginInvoiceTop,
            data.settings.marginInvoiceRight,
            data.settings.marginInvoiceBottom,
          ),
        ),
        footer: (ctx) => _buildInstitutionnelFooter(data),
        build: (ctx) => [
            // HEADER - DYNAMIQUE SELON STYLE
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildAdaptiveLogo(
                      data,
                      maxWidth: 100,
                      maxHeight: 50,
                      margin: const pw.EdgeInsets.only(bottom: 10),
                    ),
                    pw.Text(
                      data.settings.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Row(
                      children: [
                        if (data.settings.legalForm.isNotEmpty)
                          pw.Text('${data.settings.legalForm} ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        if (data.settings.rc.isNotEmpty)
                          pw.Text('| RCCM: ${data.settings.rc}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Text(
                      data.settings.address,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Tél: ${data.settings.phone}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  color: style == "ELITE"
                      ? PdfColors.amber800
                      : (style == "NOIR_BLANC" ? PdfColors.black : _accent),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        data.documentTitle,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'N° ${data.quoteNumber}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),

            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('PROPOSÉ À'),
                      pw.Text(
                        data.clientName ?? 'CLIENT POTENTIEL',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.clientPhone != null)
                        pw.Text('Tél: ${data.clientPhone}'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _sectionTitle('VALIDITÉ'),
                      pw.Text('Date Émission: ${DateFormatter.formatDate(data.date)}'),
                      pw.Text(
                        'Valable jusqu\'au: ${data.validUntil != null ? DateFormatter.formatDate(data.validUntil!) : "30 jours"}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // TABLEAU DES ARTICLES (STYLE DYNAMIQUE)
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey300),
              ),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'DESCRIPTION',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'QTÉ',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'TOTAL',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...data.items.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            if (item.description != null)
                              pw.Text(
                                item.description!,
                                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                              ),
                            if (item.discountAmount > 0)
                              pw.Text(
                                'Remise: -${fmt(item.discountAmount)}',
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.red700),
                              ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          "${item.qty % 1 == 0 ? item.qty.toInt() : item.qty}${item.unit != null ? " ${item.unit}" : ""}",
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          fmt(item.lineTotal),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                       if (data.shouldShowTax && data.shouldBeDetailed) ...[
                         _totalRow(
                          data.settings.labelHT,
                          fmt(data.subtotalHT),
                          bold: false,
                          color: PdfColors.grey700,
                        ),
                        _totalRow(
                          '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                          fmt(data.taxAmount),
                          bold: false,
                          color: PdfColors.grey700,
                        ),
                       ],
                      _totalRow(
                        data.settings.labelTTC,
                        fmt(data.totalAmount),
                        bold: true,
                        color: style == "ELITE" ? PdfColors.amber800 : _accent,
                      ),
                      if (data.shouldShowTax && !data.shouldBeDetailed)
                        _totalRow('Dont ${data.settings.taxName}:', fmt(data.taxAmount), bold: false, color: PdfColors.grey700),
                    ],
                  ),
                ),
              ],
            ),

            // FOOTER & SIGNATURE
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _buildInstitutionnelFooter(QuoteData data) {
    final s = data.settings;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(thickness: 1, color: _accent),
        pw.SizedBox(height: 5),
        pw.Text(
          "${_c(s.name)} | ${_c(s.address)} | Tél: ${_c(s.phone)} ${s.email.isNotEmpty ? '| Email: ${_c(s.email)}' : ''}",
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          textAlign: pw.TextAlign.center,
        ),
        if (s.rc.isNotEmpty || s.nif.isNotEmpty)
          pw.Text(
            "${s.rc.isNotEmpty ? 'RC: ${_c(s.rc)}  ' : ''}${s.nif.isNotEmpty ? 'NIF: ${_c(s.nif)}' : ''}",
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        if (s.bankAccount.isNotEmpty)
          pw.Text(
            "Banque / Compte: ${_c(s.bankAccount)}",
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Ceci est une proposition commerciale valable ${s.quoteValidityDays} jours.',
          style: pw.TextStyle(fontSize: 6, color: PdfColors.grey400, fontStyle: pw.FontStyle.italic),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildAdaptiveLogo(
    QuoteData data, {
    double maxWidth = 120,
    double maxHeight = 60,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    pw.BoxDecoration? decoration,
    pw.EdgeInsets? padding,
    pw.EdgeInsets? margin,
    pw.Widget? fallback,
  }) {
    final logoImage = PdfResourceService.instance.getLogo(data.settings.logoPath);
    if (logoImage != null) {
      return pw.Container(
        constraints: pw.BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        decoration: decoration,
        padding: padding,
        margin: margin,
        child: pw.Image(
          logoImage,
          fit: pw.BoxFit.contain,
          alignment: alignment,
        ),
      );
    }
    return fallback ?? pw.SizedBox();
  }

  static pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey600,
      ),
    ),
  );

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 12 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 14 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — SUPREME DEVIS (The Danaya+ Elite Standard - Ultra Compact)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildSupreme(QuoteData data) async {
    final font = await PdfResourceService.instance.getCustomFont('Inter');
    final fontBold = await PdfResourceService.instance.getCustomFont('Inter', isBold: true);
    final fontItalic = await PdfResourceService.instance.getCustomFont('Inter', isItalic: true);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(val, currency, removeDecimals: removeDecimals);

    // Supreme Palette (Sky & Slate)
    final primaryColor = PdfColor.fromHex('#0F172A'); // Slate 900
    final accentColor = PdfColor.fromHex('#0EA5E9'); // Sky 500
    final surfaceColor = PdfColor.fromHex('#F8FAFC'); // Slate 50
    final borderColor = PdfColor.fromHex('#E2E8F0'); // Slate 200

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        header: (ctx) => pw.Container(
          height: 90,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                   _buildAdaptiveLogo(data, maxWidth: 100, maxHeight: 50, margin: const pw.EdgeInsets.only(bottom: 8)),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
                  ),
                  pw.Text(
                    data.settings.slogan,
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(2)),
                    child: pw.Text(
                      "PROPOSITION COMMERCIALE",
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text("DEVIS N° ${data.quoteNumber}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text("Date : ${DateFormatter.formatDate(data.date)}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  if (data.validUntil != null)
                    pw.Text(
                      "Validité : ${DateFormatter.formatDate(data.validUntil!)}",
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                    ),
                ],
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Column(
          children: [
             pw.Divider(color: borderColor, thickness: 1),
             pw.SizedBox(height: 10),
             pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (data.settings.address.isNotEmpty)
                       pw.Text(_c(data.settings.address), style: const pw.TextStyle(fontSize: 8)),
                    if (data.settings.phone.isNotEmpty)
                       pw.Text("Tél: ${_c(data.settings.phone)}", style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (data.settings.nif.isNotEmpty)
                       pw.Text("NIF: ${_c(data.settings.nif)} | RC: ${_c(data.settings.rc)}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
             ),
          ],
        ),
        build: (ctx) => [
          pw.SizedBox(height: 15),
          
          // CLIENT & INFO ROW
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: surfaceColor,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: borderColor),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("CLIENT", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: accentColor)),
                      pw.SizedBox(height: 4),
                      pw.Text(data.clientName ?? "Client Potentiel", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      if (data.clientPhone != null || data.clientAddress != null)
                         pw.Text("${data.clientPhone ?? ''} ${data.clientAddress ?? ''}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _infoRowSupreme("Statut", "DEVIS EN ATTENTE", color: accentColor),
                    _infoRowSupreme("Ref", data.quoteNumber),
                    _infoRowSupreme("Agent", data.cashierName),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // TABLE SUPREME
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(4), topRight: pw.Radius.circular(4)),
                ),
                children: [
                  _pCellSupreme("DÉSIGNATION / PRESTATION", isHeader: true),
                  _pCellSupreme("QTÉ", isHeader: true, align: pw.TextAlign.center),
                  _pCellSupreme("P. UNITAIRE", isHeader: true, align: pw.TextAlign.right),
                  _pCellSupreme("MONTANT HT", isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              // Items (Zebra)
              ...data.items.asMap().entries.map((e) {
                final item = e.value;
                final index = e.key;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: index % 2 == 0 ? PdfColors.white : surfaceColor,
                    border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.5)),
                  ),
                  children: [
                    _pCellSupreme(item.name, bold: true),
                    _pCellSupreme(DateFormatter.formatQuantity(item.qty), align: pw.TextAlign.center),
                    _pCellSupreme(fmt(item.unitPrice), align: pw.TextAlign.right),
                    _pCellSupreme(fmt(item.lineTotal), align: pw.TextAlign.right, bold: true),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 30),

          // RECAP & TOTALS
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Container(
                      height: 40,
                      width: 40,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: "DANAYA:QUOTE:${data.saleId ?? data.quoteNumber}",
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("VÉRIFICATION FORENSIC", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Scanner pour authentifier", style: const pw.TextStyle(fontSize: 6)),
                    ]),
                  ]),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 200,
                    child: pw.Text(
                      "Conditions : Prix valables 30j. Signature client + 'Bon pour accord'.",
                      style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                    ),
                  ),
                ],
              ),

              pw.Container(
                width: 180,
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      _recapRowSupreme("Sous-Total HT", fmt(data.subtotalHT)),
                      _recapRowSupreme("${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)", fmt(data.taxAmount)),
                    ],
                    
                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(data.settings.labelTTC, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text(fmt(data.totalAmount), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _recapRowSupreme("Dont ${data.settings.taxName}", fmt(data.taxAmount)),
                  ],
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 25),
          
          // Official Signature Zones
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text("BON POUR ACCORD LE CLIENT", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)))),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text("POUR LA SOCIÉTÉ", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)))),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc;
  }

  // UTILS SUPREME QUOTE
  static pw.Widget _infoRowSupreme(String label, String value, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text("$label : ", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _pCellSupreme(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: (isHeader || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _recapRowSupreme(String label, String value, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }


}
