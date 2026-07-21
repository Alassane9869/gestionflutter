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
    if (template != null) {
      return settings.getTemplateShowTax('quote', template!.name);
    }
    return settings.showTaxOnQuotes;
  }

  bool get shouldBeDetailed {
    if (!settings.useTax) return false;
    if (template != null) {
      return settings.getTemplateDetailed('quote', template!.name);
    }
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

  static Future<pw.Document> buildDocument(
    QuoteData data,
    QuoteTemplate template,
  ) async {
    final eliteData = data.template == null
        ? data.copyWith(template: template)
        : data;
    return _build(eliteData, template);
  }

  static Future<Uint8List> generateSamplePdf(ShopSettings settings) async {
    final data = QuoteData(
      quoteNumber: "DEV-2024-0042",
      date: DateTime.now(),
      validUntil: DateTime.now().add(const Duration(days: 15)),
      items: [
        const QuoteItem(
          name: "Prestation Audit Informatique",
          qty: 1,
          unitPrice: 150000,
        ),
        const QuoteItem(
          name: "Installation Serveur Danaya",
          qty: 2,
          unitPrice: 75000,
        ),
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
    final eliteData = data.template == null
        ? data.copyWith(template: template)
        : data;
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
    return t
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('📞', 'Tel: ')
        .replaceAll('™', '')
        .replaceAll('®', '')
        .replaceAll('©', '')
        .replaceAll('•', '*')
        .replaceAll('…', '...');
  }

  static QuoteData _sanitizeData(QuoteData data) {
    final cleanItems = data.items
        .map(
          (item) => QuoteItem(
            name: _c(item.name),
            qty: item.qty,
            unitPrice: item.unitPrice,
            unit: item.unit != null ? _c(item.unit) : null,
            description: item.description != null ? _c(item.description) : null,
            discountAmount: item.discountAmount,
          ),
        )
        .toList();

    final cleanSettings = data.settings.copyWith(
      name: _c(data.settings.name),
      slogan: _c(data.settings.slogan),
      address: _c(data.settings.address),
      phone: _c(data.settings.phone),
      receiptFooter: _c(data.settings.receiptFooter),
      titleInvoice: _c(data.settings.titleInvoice),
      titleReceipt: _c(data.settings.titleReceipt),
      titleReceiptProforma: _c(data.settings.titleReceiptProforma),
      titleQuote: _c(data.settings.titleQuote),
      titleDeliveryNote: _c(data.settings.titleDeliveryNote),
      titleProforma: _c(data.settings.titleProforma),
    );

    return data.copyWith(
      clientName: data.clientName != null ? _c(data.clientName) : null,
      clientPhone: data.clientPhone != null ? _c(data.clientPhone) : null,
      clientAddress: data.clientAddress != null ? _c(data.clientAddress) : null,
      clientEmail: data.clientEmail != null ? _c(data.clientEmail) : null,
      cashierName: _c(data.cashierName),
      items: cleanItems,
      settings: cleanSettings,
    );
  }

  static Future<pw.Document> _build(
    QuoteData data,
    QuoteTemplate template,
  ) async {
    // Fonts are now pre-loaded at startup or lazily loaded synchronously via getters
    final sanitizedData = _sanitizeData(data);
    switch (template) {
      case QuoteTemplate.minimaliste:
        return _buildMinimaliste(sanitizedData);
      case QuoteTemplate.style:
        return _buildStyle(sanitizedData);
      case QuoteTemplate.prestige:
        return _buildPrestige(sanitizedData);
      case QuoteTemplate.modern:
        return _buildModern(sanitizedData);
      case QuoteTemplate.professional:
        return _buildProfessional(sanitizedData);
      case QuoteTemplate.clean:
        return _buildClean(sanitizedData);
      case QuoteTemplate.minimalist:
        return _buildMinimalist(sanitizedData);
      case QuoteTemplate.corporate:
        return _buildCorporate(sanitizedData);
      case QuoteTemplate.supreme:
        return _buildSupreme(sanitizedData);
    }
  }

  // NOTE: Les signatures des méthodes de build sont similaires aux factures
  // mais adaptées pour afficher "DEVIS" et les dates de validité.

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 2 — MINIMALISTE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildMinimaliste(QuoteData data) async {
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
    final accentDark = PdfColor.fromHex('#111827');
    final accentLight = PdfColor.fromHex('#6B7280');
    final borderLine = PdfColor.fromHex('#E5E7EB');
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
          // En-tête ultra-moderne
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildAdaptiveLogo(
                      data,
                      maxWidth: 100,
                      maxHeight: 60,
                      margin: const pw.EdgeInsets.only(bottom: 12),
                    ),
                    pw.Text(
                      data.settings.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (data.settings.address.isNotEmpty)
                      pw.Text(
                        data.settings.address,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: accentLight,
                          lineSpacing: 1.5,
                        ),
                      ),
                    if (data.settings.phone.isNotEmpty)
                      pw.Text(
                        'Tél: ${data.settings.phone}',
                        style: pw.TextStyle(fontSize: 8, color: accentLight),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      data.documentTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 4,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderLine, width: 1),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Text(
                        'N° ${data.quoteNumber}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: accentDark,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Date : ${DateFormatter.formatDate(data.date)}',
                      style: pw.TextStyle(fontSize: 9, color: accentLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 35),

          // Informations Client (Style Block Modern)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Destinataire
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.only(left: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: accentDark, width: 2),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'POUR',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: accentLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      data.clientName ?? 'Client Potentiel',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    if (data.clientAddress != null)
                      pw.Text(
                        data.clientAddress!,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: accentLight,
                          lineSpacing: 1.2,
                        ),
                      ),
                    if (data.clientPhone != null)
                      pw.Text(
                        'Tél : ${data.clientPhone}',
                        style: pw.TextStyle(fontSize: 9, color: accentLight),
                      ),
                  ],
                ),
              ),
              // Validité
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFB'),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderLine),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'VALIDITÉ DU DEVIS',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: accentLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '${data.settings.quoteValidityDays} jours',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Expiration : ${data.validUntil != null ? DateFormatter.formatDate(data.validUntil!) : "-"}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.red700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 40),

          // Lignes du devis avec style minimaliste épuré
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2.5),
            },
            children: [
              // Header table
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: accentDark, width: 1.5),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      'DÉSIGNATION',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      'QTÉ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      'PRIX UNIT.',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      'TOTAL HT',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              ...data.items.map((item) {
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: borderLine, width: 0.5),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 2,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.name,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: accentDark,
                            ),
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              item.description!,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: accentLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 12),
                      child: pw.Text(
                        "${DateFormatter.formatQuantity(item.qty)}${item.unit != null ? " ${item.unit}" : ""}",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 10, color: accentDark),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 12),
                      child: pw.Text(
                        fmt(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10, color: accentDark),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 12),
                      child: pw.Text(
                        fmt(item.lineTotal),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: accentDark,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // Bloc Totaux
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 260,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFB'),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'SOUS-TOTAL HT',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: accentLight,
                            ),
                          ),
                          pw.Text(
                            fmt(data.subtotalHT),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: accentDark,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: accentLight,
                            ),
                          ),
                          pw.Text(
                            fmt(data.taxAmount),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: accentDark,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
                      pw.Divider(color: borderLine, thickness: 1),
                      pw.SizedBox(height: 12),
                    ],
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL TTC',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: accentDark,
                            letterSpacing: 1,
                          ),
                        ),
                        pw.Text(
                          fmt(data.totalAmount),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: accentDark,
                          ),
                        ),
                      ],
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed) ...[
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Dont ${data.settings.taxName}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: accentLight,
                            ),
                          ),
                          pw.Text(
                            fmt(data.taxAmount),
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: accentLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 40),

          // Zone de signatures (Élégante)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.only(top: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: accentDark, width: 1.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "ACCEPTATION DU DEVIS",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Date et signature du client",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: accentLight,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.Text(
                      "précédée de la mention « Bon pour accord »",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: accentLight,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: 160,
                padding: const pw.EdgeInsets.only(top: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: borderLine, width: 1.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "LA DIRECTION",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: accentDark,
                        letterSpacing: 1,
                      ),
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

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 4 — STYLE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildStyle(QuoteData data) async {
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
    final amethystColor = PdfColor.fromHex('#6D28D9'); // Violet améthyste
    final goldAccent = PdfColor.fromHex('#B45309'); // Doré cuivre
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
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                pw.Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: pw.Container(height: 5, color: amethystColor),
                ),
                pw.Positioned(
                  left: 0,
                  bottom: 0,
                  right: 0,
                  child: pw.Container(height: 5, color: goldAccent),
                ),
              ],
            ),
          ),
        ),
        footer: (ctx) => _buildInstitutionnelFooter(data),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          // En-tête stylé
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAdaptiveLogo(
                    data,
                    maxWidth: 90,
                    maxHeight: 50,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                  ),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: amethystColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (data.settings.slogan.isNotEmpty)
                    pw.Text(
                      data.settings.slogan,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: goldAccent,
                      ),
                    ),
                  if (data.settings.address.isNotEmpty)
                    pw.Text(
                      data.settings.address,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: goldAccent, width: 1),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      data.documentTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: amethystColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'N° ${data.quoteNumber}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: amethystColor,
                    ),
                  ),
                  pw.Text(
                    'Date : ${DateFormatter.formatDate(data.date)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          // Destinataire et détails validité
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FAF5FF'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#EDE9FE')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PROPOSITION PRÉPARÉE POUR',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: amethystColor,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        data.clientName ?? 'Client Potentiel',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: amethystColor,
                        ),
                      ),
                      if (data.clientPhone != null)
                        pw.Text(
                          'Contact : ${data.clientPhone}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (data.clientAddress != null)
                        pw.Text(
                          data.clientAddress!,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 15),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FFFBEB'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#FEF3C7')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PÉRIODE DE VALIDITÉ',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: goldAccent,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Valable jusqu\'au : ${data.validUntil != null ? DateFormatter.formatLongDate(data.validUntil!) : "${data.settings.quoteValidityDays} jours"}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: goldAccent,
                        ),
                      ),
                      pw.Text(
                        'Validité standard : ${data.settings.quoteValidityDays} jours',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          // Tableau d'articles
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: amethystColor),
                children: [
                  _pCell('DÉSIGNATION / PRESTATION', isHeader: true),
                  _pCell('QTÉ', isHeader: true, align: pw.TextAlign.center),
                  _pCell(
                    'P. UNITAIRE',
                    isHeader: true,
                    align: pw.TextAlign.right,
                  ),
                  _pCell(
                    'MONTANT HT',
                    isHeader: true,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
              ...data.items.asMap().entries.map(
                (e) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: e.key % 2 == 0
                        ? PdfColors.white
                        : PdfColor.fromHex('#F5F3FF'),
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColor.fromHex('#EDE9FE'),
                        width: 0.5,
                      ),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            e.value.name,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                          if (e.value.description != null)
                            pw.Text(
                              e.value.description!,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.grey600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _pCell(
                      "${DateFormatter.formatQuantity(e.value.qty)}${e.value.unit != null ? " ${e.value.unit}" : ""}",
                      align: pw.TextAlign.center,
                    ),
                    _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                    _pCell(
                      fmt(e.value.lineTotal),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: amethystColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Totaux stylés
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 210,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: amethystColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      _pTotalRow('TOTAL HT', fmt(data.subtotalHT)),
                      _pTotalRow(
                        '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                        fmt(data.taxAmount),
                      ),
                    ],
                    pw.Divider(color: goldAccent, thickness: 1),
                    _pTotalRow(
                      data.settings.labelTTC,
                      fmt(data.totalAmount),
                      isBig: true,
                      color: amethystColor,
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _pTotalRow(
                        'Dont ${data.settings.taxName}',
                        fmt(data.taxAmount),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          // Double signature stylée
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "ACCORD CLIENT",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: amethystColor,
                    ),
                  ),
                  pw.Text(
                    "Date, signature et mention manuscrite",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Container(width: 140, height: 0.5, color: amethystColor),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "POUR LA SOCIÉTÉ",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: goldAccent,
                    ),
                  ),
                  pw.SizedBox(height: 42),
                  pw.Container(width: 140, height: 0.5, color: goldAccent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return doc;
  }

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
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: corporateBlue, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildAdaptiveLogo(
                      data,
                      maxWidth: 90,
                      maxHeight: 55,
                      margin: const pw.EdgeInsets.only(bottom: 8),
                    ),
                    pw.Text(
                      data.settings.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: corporateBlue,
                        letterSpacing: 2,
                      ),
                    ),
                    if (data.settings.address.isNotEmpty)
                      pw.Text(
                        data.settings.address,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (data.settings.phone.isNotEmpty)
                      pw.Text(
                        'Tél: ${data.settings.phone}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      data.documentTitle,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: corporateBlue,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(color: corporateBlue),
                      child: pw.Text(
                        'N° ${data.quoteNumber}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('PROPOSÉ À'),
                    pw.Text(
                      data.clientName ?? 'Client Potentiel',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (data.clientPhone != null)
                      pw.Text(
                        'Tél: ${data.clientPhone}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    if (data.clientAddress != null)
                      pw.Text(
                        data.clientAddress!,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _sectionTitle('VALIDITÉ'),
                    pw.Text(
                      'Émis le: ${DateFormatter.formatLongDate(data.date)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Valable jusqu\'au: ${data.validUntil != null ? DateFormatter.formatLongDate(data.validUntil!) : "${data.settings.quoteValidityDays} jours"}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: corporateBlue),
                children: [
                  _pCell('DÉSIGNATION', isHeader: true),
                  _pCell('QTÉ', isHeader: true, align: pw.TextAlign.center),
                  _pCell(
                    'P. UNITAIRE',
                    isHeader: true,
                    align: pw.TextAlign.right,
                  ),
                  _pCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              ...data.items.asMap().entries.map(
                (e) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: e.key % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            e.value.name,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          if (e.value.description != null)
                            pw.Text(
                              e.value.description!,
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _pCell(
                      "${DateFormatter.formatQuantity(e.value.qty)}${e.value.unit != null ? " ${e.value.unit}" : ""}",
                      align: pw.TextAlign.center,
                    ),
                    _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                    _pCell(
                      fmt(e.value.lineTotal),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: corporateBlue,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "BON POUR ACCORD LE CLIENT",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: corporateBlue,
                      ),
                    ),
                    pw.Text(
                      "Signature + mention manuscrite",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.SizedBox(height: 35),
                    pw.Container(
                      width: 140,
                      height: 0.5,
                      color: PdfColors.grey400,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 30),
              pw.Container(
                width: 240,
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      _pTotalRow('SOUS-TOTAL HT', fmt(data.subtotalHT)),
                      _pTotalRow(
                        '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                        fmt(data.taxAmount),
                      ),
                    ],
                    pw.Divider(color: corporateBlue, thickness: 1.5),
                    _pTotalRow(
                      'MONTANT TOTAL TTC',
                      fmt(data.totalAmount),
                      isBig: true,
                      color: corporateBlue,
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _pTotalRow(
                        'Dont ${data.settings.taxName}',
                        fmt(data.taxAmount),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "POUR LA SOCIÉTÉ",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: corporateBlue,
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Container(
                    width: 140,
                    height: 0.5,
                    color: PdfColors.grey400,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                pw.Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: pw.Container(width: 8, color: modernGreen),
                ),
              ],
            ),
          ),
        ),
        footer: (ctx) => _buildInstitutionnelFooter(data),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16),
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
                          maxWidth: 80,
                          maxHeight: 45,
                          margin: const pw.EdgeInsets.only(bottom: 6),
                        ),
                        pw.Text(
                          data.settings.name.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (data.settings.slogan.isNotEmpty)
                          pw.Text(
                            data.settings.slogan,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      color: modernGreen,
                      child: pw.Column(
                        children: [
                          pw.Text(
                            data.documentTitle.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'N° ${data.quoteNumber}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey200,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CLIENT',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: modernGreen,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.Text(
                            data.clientName ?? 'Client Potentiel',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (data.clientPhone != null)
                            pw.Text(
                              data.clientPhone!,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date: ${DateFormatter.formatDate(data.date)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Valable jusqu\'au: ${data.validUntil != null ? DateFormatter.formatDate(data.validUntil!) : "30 jours"}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: modernGreen),
                      children: [
                        _pCell('ARTICLE', isHeader: true),
                        _pCell(
                          'QTÉ',
                          isHeader: true,
                          align: pw.TextAlign.center,
                        ),
                        _pCell(
                          'PRIX U.',
                          isHeader: true,
                          align: pw.TextAlign.right,
                        ),
                        _pCell(
                          'TOTAL',
                          isHeader: true,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                    ...data.items.asMap().entries.map(
                      (e) => pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: e.key % 2 == 0
                              ? PdfColors.white
                              : PdfColor.fromHex('#E0F2F1'),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  e.value.name,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                if (e.value.description != null)
                                  pw.Text(
                                    e.value.description!,
                                    style: const pw.TextStyle(
                                      fontSize: 7.5,
                                      color: PdfColors.grey600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _pCell(
                            "${DateFormatter.formatQuantity(e.value.qty)}${e.value.unit != null ? " ${e.value.unit}" : ""}",
                            align: pw.TextAlign.center,
                          ),
                          _pCell(
                            fmt(e.value.unitPrice),
                            align: pw.TextAlign.right,
                          ),
                          _pCell(
                            fmt(e.value.lineTotal),
                            align: pw.TextAlign.right,
                            bold: true,
                            color: modernGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "ACCORD DU CLIENT",
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: modernGreen,
                            ),
                          ),
                          pw.Text(
                            "Signature + mention manuscrite",
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey500,
                            ),
                          ),
                          pw.SizedBox(height: 35),
                          pw.Container(
                            width: 140,
                            height: 0.5,
                            color: PdfColors.grey400,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 30),
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        children: [
                          if (data.shouldShowTax && data.shouldBeDetailed) ...[
                            _pTotalRow('TOTAL HT', fmt(data.subtotalHT)),
                            _pTotalRow(
                              '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                              fmt(data.taxAmount),
                            ),
                          ],
                          pw.Divider(color: modernGreen),
                          _pTotalRow(
                            'TOTAL DEVIS TTC',
                            fmt(data.totalAmount),
                            isBig: true,
                            color: modernGreen,
                          ),
                          if (data.shouldShowTax && !data.shouldBeDetailed)
                            _pTotalRow(
                              'Dont ${data.settings.taxName}',
                              fmt(data.taxAmount),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "POUR LA SOCIÉTÉ",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: modernGreen,
                          ),
                        ),
                        pw.SizedBox(height: 35),
                        pw.Container(
                          width: 140,
                          height: 0.5,
                          color: PdfColors.grey400,
                        ),
                      ],
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
          // Clean Header (no colored bands)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAdaptiveLogo(
                    data,
                    maxWidth: 90,
                    maxHeight: 50,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                  ),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: cleanAccent,
                    ),
                  ),
                  if (data.settings.slogan.isNotEmpty)
                    pw.Text(
                      data.settings.slogan,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                  if (data.settings.address.isNotEmpty)
                    pw.Text(
                      data.settings.address,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  if (data.settings.phone.isNotEmpty)
                    pw.Text(
                      'Tél: ${data.settings.phone}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    data.documentTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: cleanAccent,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'N° ${data.quoteNumber}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    'Date : ${DateFormatter.formatDate(data.date)}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  if (data.validUntil != null)
                    pw.Text(
                      'Valide jusqu\'au : ${DateFormatter.formatDate(data.validUntil!)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(height: 1, color: cleanAccent),
          pw.SizedBox(height: 15),
          // Client details
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PROPOSITION DESTINÉE À :',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: cleanAccent,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.clientName ?? 'Client Potentiel',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (data.clientPhone != null)
                      pw.Text(
                        'Tél : ${data.clientPhone}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    if (data.clientAddress != null)
                      pw.Text(
                        data.clientAddress!,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    if (data.clientEmail != null)
                      pw.Text(
                        'Email : ${data.clientEmail}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INFORMATIONS :',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: cleanAccent,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Validité : ${data.settings.quoteValidityDays} jours',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Agent commercial : ${data.cashierName}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Clean items table with simple borders
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: cleanAccent, width: 1),
                  ),
                ),
                children: [
                  _pCell(
                    'DÉSIGNATION / PRESTATION',
                    isHeader: false,
                    bold: true,
                    color: cleanAccent,
                  ),
                  _pCell(
                    'QTÉ',
                    isHeader: false,
                    align: pw.TextAlign.center,
                    bold: true,
                    color: cleanAccent,
                  ),
                  _pCell(
                    'P. UNITAIRE',
                    isHeader: false,
                    align: pw.TextAlign.right,
                    bold: true,
                    color: cleanAccent,
                  ),
                  _pCell(
                    'TOTAL HT',
                    isHeader: false,
                    align: pw.TextAlign.right,
                    bold: true,
                    color: cleanAccent,
                  ),
                ],
              ),
              ...data.items.asMap().entries.map(
                (e) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey200,
                        width: 0.5,
                      ),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            e.value.name,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          if (e.value.description != null)
                            pw.Text(
                              e.value.description!,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.grey600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _pCell(
                      "${DateFormatter.formatQuantity(e.value.qty)}${e.value.unit != null ? " ${e.value.unit}" : ""}",
                      align: pw.TextAlign.center,
                    ),
                    _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                    _pCell(
                      fmt(e.value.lineTotal),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: cleanAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          // Clean Totals
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      _pTotalRow('SOUS-TOTAL HT', fmt(data.subtotalHT)),
                      _pTotalRow(
                        '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                        fmt(data.taxAmount),
                      ),
                    ],
                    pw.Divider(color: cleanAccent, thickness: 0.5),
                    _pTotalRow(
                      'MONTANT NET TTC',
                      fmt(data.totalAmount),
                      isBig: true,
                      color: cleanAccent,
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _pTotalRow(
                        'Dont ${data.settings.taxName}',
                        fmt(data.taxAmount),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          // Signatures block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "BON POUR ACCORD LE CLIENT",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: cleanAccent,
                    ),
                  ),
                  pw.Text(
                    "Mention manuscrite 'Bon pour accord' + signature",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Container(
                    width: 140,
                    height: 0.5,
                    color: PdfColors.grey400,
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "POUR LA SOCIÉTÉ",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: cleanAccent,
                    ),
                  ),
                  pw.SizedBox(height: 42),
                  pw.Container(
                    width: 140,
                    height: 0.5,
                    color: PdfColors.grey400,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return doc;
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
    final logoImage = PdfResourceService.instance.getLogo(
      data.settings.logoPath,
    );
    if (logoImage != null) {
      return pw.Container(
        constraints: pw.BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
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
    final darkCharcoal = PdfColor.fromHex('#0F172A');
    final goldAccent = PdfColor.fromHex('#B7791F'); // Elegant gold/bronze
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
          margin: const pw.EdgeInsets.all(
            40,
          ), // Generous margins for prestige look
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: goldAccent, thickness: 0.5),
            pw.SizedBox(height: 8),
            _buildInstitutionnelFooter(data),
          ],
        ),
        build: (ctx) => [
          // En-tête Prestige
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildAdaptiveLogo(
                      data,
                      maxWidth: 110,
                      maxHeight: 60,
                      margin: const pw.EdgeInsets.only(bottom: 15),
                    ),
                    pw.Text(
                      data.settings.name.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (data.settings.address.isNotEmpty)
                      pw.Text(
                        data.settings.address,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    if (data.settings.phone.isNotEmpty)
                      pw.Text(
                        'Tél: ${data.settings.phone}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    if (data.settings.email.isNotEmpty)
                      pw.Text(
                        'Email: ${data.settings.email}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "DEVIS",
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 6,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      data.documentTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: goldAccent,
                        letterSpacing: 3,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      decoration: pw.BoxDecoration(color: darkCharcoal),
                      child: pw.Text(
                        'N° ${data.quoteNumber}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Date d\'émission : ${DateFormatter.formatDate(data.date)}',
                      style: pw.TextStyle(fontSize: 9, color: darkCharcoal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Ligne de séparation élégante
          pw.Container(height: 1.5, color: goldAccent),
          pw.Container(
            height: 0.5,
            color: darkCharcoal,
            margin: const pw.EdgeInsets.only(top: 2),
          ),
          pw.SizedBox(height: 30),

          // Infos Destinataire et Validité
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PROPOSITION COMMERCIALE POUR',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: goldAccent,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    data.clientName ?? 'Client Potentiel',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: darkCharcoal,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (data.clientAddress != null)
                    pw.Text(
                      data.clientAddress!,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  if (data.clientPhone != null)
                    pw.Text(
                      'Tél : ${data.clientPhone}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                  if (data.clientEmail != null)
                    pw.Text(
                      'Email : ${data.clientEmail}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                ],
              ),
              pw.Container(
                width: 180,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: goldAccent, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CONDITIONS',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Validité:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${data.settings.quoteValidityDays} jours',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Échéance:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          data.validUntil != null
                              ? DateFormatter.formatDate(data.validUntil!)
                              : "-",
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 40),

          // Table des articles (Design Prestige : Bordures horizontales fortes, espacé)
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(4.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: darkCharcoal, width: 1.5),
                    bottom: pw.BorderSide(color: darkCharcoal, width: 1.5),
                  ),
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: pw.Text(
                      'DESCRIPTION',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: pw.Text(
                      'QUANTITÉ',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: pw.Text(
                      'PRIX UNIT.',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: pw.Text(
                      'MONTANT HT',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              ...data.items.map((item) {
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.name,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: darkCharcoal,
                            ),
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              item.description!,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey600,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: pw.Text(
                        "${DateFormatter.formatQuantity(item.qty)}${item.unit != null ? " ${item.unit}" : ""}",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 10, color: darkCharcoal),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: pw.Text(
                        fmt(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 10, color: darkCharcoal),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: pw.Text(
                        fmt(item.lineTotal),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: darkCharcoal,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 30),

          // Bloc Totaux & Signatures
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Signatures à gauche pour Prestige
              pw.Container(
                width: 220,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ACCORD ET SIGNATURE',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: goldAccent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Bon pour accord, date et signature précédés de la mention manuscrite :',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 50),
                    pw.Container(
                      width: 200,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: darkCharcoal,
                            width: 0.5,
                            style: pw.BorderStyle.dashed,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Le Client',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: darkCharcoal,
                      ),
                    ),
                  ],
                ),
              ),

              // Totaux à droite
              pw.Container(
                width: 240,
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'SOUS-TOTAL HT',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            fmt(data.subtotalHT),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            fmt(data.taxAmount),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: darkCharcoal,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 15),
                    ],
                    // Grand total box
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: pw.BoxDecoration(color: darkCharcoal),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'TOTAL TTC',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: goldAccent,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.Text(
                            fmt(data.totalAmount),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed) ...[
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Dont ${data.settings.taxName} : ${fmt(data.taxAmount)}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ],
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
          // Professional Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAdaptiveLogo(
                    data,
                    maxWidth: 100,
                    maxHeight: 50,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                  ),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: darkColor,
                    ),
                  ),
                  if (data.settings.slogan.isNotEmpty)
                    pw.Text(
                      data.settings.slogan,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600,
                      ),
                    ),
                  pw.Text(
                    data.settings.address,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Tél : ${data.settings.phone}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    color: darkColor,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    child: pw.Text(
                      data.documentTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: goldAccent,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'DEVIS REFERENCE : ${data.quoteNumber}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Émis le : ${DateFormatter.formatDate(data.date)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  if (data.validUntil != null)
                    pw.Text(
                      'Valide jusqu\'au : ${DateFormatter.formatDate(data.validUntil!)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          // Horizontal bar
          pw.Container(height: 3, color: goldAccent),
          pw.SizedBox(height: 15),
          // Client details block
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INFORMATIONS CLIENT',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        data.clientName ?? 'Client Potentiel',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.clientPhone != null)
                        pw.Text(
                          'Contact Tél : ${data.clientPhone}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (data.clientAddress != null)
                        pw.Text(
                          'Adresse : ${data.clientAddress!}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (data.clientEmail != null)
                        pw.Text(
                          'Email : ${data.clientEmail}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CADRE COMMERCIAL',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Durée de validité : ${data.settings.quoteValidityDays} jours',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Agent en charge : ${data.cashierName}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        'Statut : Proposition commerciale officielle',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          // Table of items
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: darkColor),
                children: [
                  _pCell(
                    'DÉSIGNATION / PRESTATION',
                    isHeader: true,
                    color: PdfColors.white,
                  ),
                  _pCell(
                    'QTÉ',
                    isHeader: true,
                    align: pw.TextAlign.center,
                    color: PdfColors.white,
                  ),
                  _pCell(
                    'P. UNITAIRE',
                    isHeader: true,
                    align: pw.TextAlign.right,
                    color: PdfColors.white,
                  ),
                  _pCell(
                    'MONTANT HT',
                    isHeader: true,
                    align: pw.TextAlign.right,
                    color: PdfColors.white,
                  ),
                ],
              ),
              ...data.items.asMap().entries.map(
                (e) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: e.key % 2 == 0
                        ? PdfColors.white
                        : PdfColor.fromHex('#F7F9FA'),
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey200,
                        width: 0.5,
                      ),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            e.value.name,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                          if (e.value.description != null)
                            pw.Text(
                              e.value.description!,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.grey600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _pCell(
                      "${DateFormatter.formatQuantity(e.value.qty)}${e.value.unit != null ? " ${e.value.unit}" : ""}",
                      align: pw.TextAlign.center,
                    ),
                    _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                    _pCell(
                      fmt(e.value.lineTotal),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: darkColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Recap & Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "BON POUR ACCORD LE CLIENT",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: darkColor,
                    ),
                  ),
                  pw.Text(
                    "Signature précédée de la mention manuscrite 'Bon pour accord'",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 150, height: 0.5, color: darkColor),
                ],
              ),
              pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      _pTotalRow('Sous-Total HT', fmt(data.subtotalHT)),
                      _pTotalRow(
                        '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                        fmt(data.taxAmount),
                      ),
                    ],
                    pw.Divider(color: darkColor, thickness: 1.5),
                    _pTotalRow(
                      'TOTAL NET A PAYER TTC',
                      fmt(data.totalAmount),
                      isBig: true,
                      color: goldAccent,
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _pTotalRow(
                        'Dont ${data.settings.taxName}',
                        fmt(data.taxAmount),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "POUR LA SOCIÉTÉ (SIGNATURE & CACHET)",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: darkColor,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 150, height: 0.5, color: darkColor),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return doc;
  }

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
          // Minimalist Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAdaptiveLogo(
                    data,
                    maxWidth: 90,
                    maxHeight: 50,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                  ),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (data.settings.slogan.isNotEmpty)
                    pw.Text(
                      data.settings.slogan,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  pw.Text(
                    data.settings.address,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Tél : ${data.settings.phone}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    data.documentTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Devis N° : ${data.quoteNumber}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date : ${DateFormatter.formatDate(data.date)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  if (data.validUntil != null)
                    pw.Text(
                      'Date limite : ${DateFormatter.formatDate(data.validUntil!)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(height: 2, color: PdfColors.black),
          pw.SizedBox(height: 15),
          // Destinataire
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CLIENT :',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.clientName ?? 'Client Potentiel',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (data.clientPhone != null)
                      pw.Text(
                        'Contact : ${data.clientPhone}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (data.clientAddress != null)
                      pw.Text(
                        'Adresse : ${data.clientAddress!}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INFORMATIONS SUPPLÉMENTAIRES :',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Période de validité : ${data.settings.quoteValidityDays} jours',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Conseiller : ${data.cashierName}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 25),
          // Table
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                  ),
                ),
                children: [
                  _pCell(
                    'DÉSIGNATION / PRESTATION',
                    isHeader: false,
                    bold: true,
                    color: PdfColors.black,
                  ),
                  _pCell(
                    'QTÉ',
                    isHeader: false,
                    align: pw.TextAlign.center,
                    bold: true,
                    color: PdfColors.black,
                  ),
                  _pCell(
                    'P. UNITAIRE',
                    isHeader: false,
                    align: pw.TextAlign.right,
                    bold: true,
                    color: PdfColors.black,
                  ),
                  _pCell(
                    'TOTAL HT',
                    isHeader: false,
                    align: pw.TextAlign.right,
                    bold: true,
                    color: PdfColors.black,
                  ),
                ],
              ),
              ...data.items.asMap().entries.map(
                (e) => pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            e.value.name,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                          if (e.value.description != null)
                            pw.Text(
                              e.value.description!,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.grey600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _pCell(
                      "${DateFormatter.formatQuantity(e.value.qty)}${e.value.unit != null ? " ${e.value.unit}" : ""}",
                      align: pw.TextAlign.center,
                    ),
                    _pCell(fmt(e.value.unitPrice), align: pw.TextAlign.right),
                    _pCell(
                      fmt(e.value.lineTotal),
                      align: pw.TextAlign.right,
                      bold: true,
                      color: PdfColors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          // Totals & Double validation
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "COMMANDE / ACCORD CLIENT",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Mention manuscrite 'Bon pour accord' + signature",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Container(width: 140, height: 0.5, color: PdfColors.black),
                ],
              ),
              pw.Container(
                width: 180,
                child: pw.Column(
                  children: [
                    if (data.shouldShowTax && data.shouldBeDetailed) ...[
                      _pTotalRow('Sous-Total HT', fmt(data.subtotalHT)),
                      _pTotalRow(
                        '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                        fmt(data.taxAmount),
                      ),
                    ],
                    pw.Divider(color: PdfColors.black, thickness: 1.5),
                    _pTotalRow('TOTAL TTC', fmt(data.totalAmount), isBig: true),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _pTotalRow(
                        'Dont ${data.settings.taxName}',
                        fmt(data.taxAmount),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "SIGNATURE POUR LA SOCIÉTÉ",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Container(width: 140, height: 0.5, color: PdfColors.black),
                ],
              ),
            ],
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
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9.5 : 8.5,
          fontWeight: (isHeader || bold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.white : PdfColors.black),
        ),
      ),
    );
  }

  static pw.Widget _pTotalRow(
    String label,
    String value, {
    bool isBig = false,
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
              fontSize: isBig ? 11 : 9,
              fontWeight: isBig ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBig ? 12 : 9,
              fontWeight: pw.FontWeight.bold,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInstitutionnelFooter(QuoteData data) {
    final s = data.settings;
    final slateBlue = PdfColor.fromHex('#1E293B');
    final accentColor = PdfColor.fromHex('#D97706'); // Amber par défaut
    return pw.Column(
      children: [
        pw.Divider(color: slateBlue, thickness: 1),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Bloc Juridique & Contact
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'COORDONNÉES & LÉGAL',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: slateBlue,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    _c(s.address),
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    'Tél : ${_c(s.phone)} ${s.whatsapp.isNotEmpty ? "| WhatsApp : ${_c(s.whatsapp)}" : ""}',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  if (s.email.isNotEmpty)
                    pw.Text(
                      'Email : ${_c(s.email).toLowerCase()}',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      if (s.rc.isNotEmpty)
                        pw.Text(
                          'RCCM : ${_c(s.rc)}  ',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (s.nif.isNotEmpty)
                        pw.Text(
                          'NIF : ${_c(s.nif)}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Bloc validité
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VALIDITÉ DU DEVIS',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Ce devis est une proposition commerciale valable ${s.quoteValidityDays} jours à compter de sa date d\'émission.',
                    style: const pw.TextStyle(
                      fontSize: 6.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Les prix indiqués sont fermes et non révisables durant cette période.',
                    style: const pw.TextStyle(
                      fontSize: 6.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            // Bloc Signature / Cachet
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                children: [
                  pw.Text(
                    'CACHE-T & SIGNATURE',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.SizedBox(height: 35),
                  pw.Container(width: 100, height: 0.5, color: slateBlue),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE — SUPREME DEVIS (The Danaya+ Elite Standard - Ultra Compact)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> _buildSupreme(QuoteData data) async {
    final font = await PdfResourceService.instance.getCustomFont('Inter');
    final fontBold = await PdfResourceService.instance.getCustomFont(
      'Inter',
      isBold: true,
    );
    final fontItalic = await PdfResourceService.instance.getCustomFont(
      'Inter',
      isItalic: true,
    );
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
    // Ultra Professional Palette (Navy & Gold)
    final primaryColor = PdfColor.fromHex('#111827'); // Very dark grey/navy
    final accentColor = PdfColor.fromHex('#D4AF37'); // Luxurious Gold
    final surfaceColor = PdfColor.fromHex('#F9FAFB'); // Elegant Off-white
    final borderColor = PdfColor.fromHex('#E5E7EB'); // Subtle Silver
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: _pageFormat,
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
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: pw.Container(width: 8, color: primaryColor),
                ),
                pw.Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: pw.Container(width: 2, color: accentColor),
                ),
              ],
            ),
          ),
        ),
        header: (ctx) => pw.Container(
          height: 90,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildAdaptiveLogo(
                    data,
                    maxWidth: 100,
                    maxHeight: 50,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                  ),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.Text(
                    data.settings.slogan,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      "PROPOSITION COMMERCIALE",
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "DEVIS N° ${data.quoteNumber}",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.Text(
                    "Date : ${DateFormatter.formatDate(data.date)}",
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  if (data.validUntil != null)
                    pw.Text(
                      "Validité : ${DateFormatter.formatDate(data.validUntil!)}",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
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
                      pw.Text(
                        _c(data.settings.address),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (data.settings.phone.isNotEmpty)
                      pw.Text(
                        "Tél: ${_c(data.settings.phone)}",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (data.settings.nif.isNotEmpty)
                      pw.Text(
                        "NIF: ${_c(data.settings.nif)} | RC: ${_c(data.settings.rc)}",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
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
                      pw.Text(
                        "CLIENT",
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        data.clientName ?? "Client Potentiel",
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      if (data.clientPhone != null ||
                          data.clientAddress != null)
                        pw.Text(
                          "${data.clientPhone ?? ''} ${data.clientAddress ?? ''}",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
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
                    _infoRowSupreme(
                      "Statut",
                      "DEVIS EN ATTENTE",
                      color: accentColor,
                    ),
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
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    topRight: pw.Radius.circular(4),
                  ),
                ),
                children: [
                  _pCellSupreme("DÉSIGNATION / PRESTATION", isHeader: true),
                  _pCellSupreme(
                    "QTÉ",
                    isHeader: true,
                    align: pw.TextAlign.center,
                  ),
                  _pCellSupreme(
                    "P. UNITAIRE",
                    isHeader: true,
                    align: pw.TextAlign.right,
                  ),
                  _pCellSupreme(
                    "MONTANT HT",
                    isHeader: true,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
              // Items (Zebra)
              ...data.items.asMap().entries.map((e) {
                final item = e.value;
                final index = e.key;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: index % 2 == 0 ? PdfColors.white : surfaceColor,
                    border: pw.Border(
                      bottom: pw.BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  children: [
                    _pCellSupreme(item.name, bold: true),
                    _pCellSupreme(
                      "${DateFormatter.formatQuantity(item.qty)}${item.unit != null ? " ${item.unit}" : ""}",
                      align: pw.TextAlign.center,
                    ),
                    _pCellSupreme(
                      fmt(item.unitPrice),
                      align: pw.TextAlign.right,
                    ),
                    _pCellSupreme(
                      fmt(item.lineTotal),
                      align: pw.TextAlign.right,
                      bold: true,
                    ),
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
                  pw.Row(
                    children: [
                      pw.Container(
                        height: 40,
                        width: 40,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data:
                              "DANAYA:QUOTE:${data.saleId ?? data.quoteNumber}",
                          drawText: false,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "VÉRIFICATION FORENSIC",
                            style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            "Scanner pour authentifier",
                            style: const pw.TextStyle(fontSize: 6),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 200,
                    child: pw.Text(
                      "Conditions : Prix valables ${data.settings.quoteValidityDays} jours. Signature client + 'Bon pour accord'.",
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700,
                      ),
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
                      _recapRowSupreme(
                        "${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)",
                        fmt(data.taxAmount),
                      ),
                    ],

                    pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 4),
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            data.settings.labelTTC,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.Text(
                            fmt(data.totalAmount),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.shouldShowTax && !data.shouldBeDetailed)
                      _recapRowSupreme(
                        "Dont ${data.settings.taxName}",
                        fmt(data.taxAmount),
                      ),
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
                  pw.Text(
                    "BON POUR ACCORD LE CLIENT",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    width: 140,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          color: PdfColors.grey400,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    "POUR LA SOCIÉTÉ",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    width: 140,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(
                          color: PdfColors.grey400,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
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
  static pw.Widget _infoRowSupreme(
    String label,
    String value, {
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            "$label : ",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pCellSupreme(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: (isHeader || bold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _recapRowSupreme(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
