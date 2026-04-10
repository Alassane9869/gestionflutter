import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data class for an invoice
// ─────────────────────────────────────────────────────────────────────────────

class InvoiceData {
  final String invoiceNumber;
  final DateTime date;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxRate; // 0.0 to 1.0, e.g. 0.19 for 19%
  final double totalAmount;
  final double amountPaid;
  final double change;
  final double discountAmount;
  final bool isCredit;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final String cashierName;
  final ShopSettings settings;
  final String? saleId;
  final String? paymentMethod;
  final String? clientEmail;
  final int loyaltyPointsGained;
  final int loyaltyPointsBalance;
  final bool isProforma;
  final bool isDeliveryNote;
  final InvoiceTemplate? template;

  const InvoiceData({
    required this.invoiceNumber,
    required this.date,
    required this.items,
    required this.subtotal,
    this.taxRate = 0,
    required this.totalAmount,
    required this.amountPaid,
    required this.change,
    this.isCredit = false,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    required this.cashierName,
    required this.settings,
    this.saleId,
    this.paymentMethod,
    this.clientEmail,
    this.discountAmount = 0.0,
    this.loyaltyPointsGained = 0,
    this.loyaltyPointsBalance = 0,
    this.isProforma = false,
    this.isDeliveryNote = false,
    this.template,
  });

  String get documentTitle {
    if (isDeliveryNote) return settings.titleDeliveryNote;
    if (isProforma) return settings.titleProforma;
    return settings.titleInvoice;
  }

  double get taxAmount => subtotal - (subtotal / (1 + taxRate));
  double get subtotalHT => subtotal - taxAmount;

  bool get shouldShowTax {
    if (!settings.useTax) return false;
    if (template != null) {
      final type = isDeliveryNote ? 'delivery' : (isProforma ? 'quote' : 'invoice');
      return settings.getTemplateShowTax(type, template!.name);
    }
    if (isDeliveryNote) return settings.showTaxOnDeliveryNotes;
    if (isProforma) return settings.showTaxOnQuotes;
    return settings.showTaxOnInvoices;
  }

  bool get shouldBeDetailed {
    if (!settings.useTax) return false;
    if (template != null) {
      final type = isDeliveryNote ? 'delivery' : (isProforma ? 'quote' : 'invoice');
      return settings.getTemplateDetailed(type, template!.name);
    }
    if (isDeliveryNote) return settings.useDetailedTaxOnDeliveryNotes;
    if (isProforma) return settings.useDetailedTaxOnQuotes;
    return settings.useDetailedTaxOnInvoices;
  }

  InvoiceData copyWith({
    String? invoiceNumber,
    DateTime? date,
    List<InvoiceItem>? items,
    double? subtotal,
    double? taxRate,
    double? totalAmount,
    double? amountPaid,
    double? change,
    bool? isCredit,
    String? clientName,
    String? clientPhone,
    String? clientAddress,
    String? cashierName,
    ShopSettings? settings,
    String? saleId,
    String? paymentMethod,
    String? clientEmail,
    double? discountAmount,
    int? loyaltyPointsGained,
    int? loyaltyPointsBalance,
    bool? isProforma,
    bool? isDeliveryNote,
    InvoiceTemplate? template,
  }) {
    return InvoiceData(
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      date: date ?? this.date,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      change: change ?? this.change,
      isCredit: isCredit ?? this.isCredit,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAddress: clientAddress ?? this.clientAddress,
      cashierName: cashierName ?? this.cashierName,
      settings: settings ?? this.settings,
      saleId: saleId ?? this.saleId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      clientEmail: clientEmail ?? this.clientEmail,
      discountAmount: discountAmount ?? this.discountAmount,
      loyaltyPointsGained: loyaltyPointsGained ?? this.loyaltyPointsGained,
      loyaltyPointsBalance: loyaltyPointsBalance ?? this.loyaltyPointsBalance,
      isProforma: isProforma ?? this.isProforma,
      isDeliveryNote: isDeliveryNote ?? this.isDeliveryNote,
      template: template ?? this.template,
    );
  }
}

class InvoiceItem {
  final String name;
  final double qty;
  final double unitPrice;
  final double discountPercent;

  const InvoiceItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.discountPercent = 0.0,
  });

  double get lineTotal => qty * unitPrice * (1 - (discountPercent / 100));
}

// ─────────────────────────────────────────────────────────────────────────────
// Invoice template enum
// ─────────────────────────────────────────────────────────────────────────────

// InvoiceTemplate moved to settings_models.dart

// ─────────────────────────────────────────────────────────────────────────────
// InvoiceService — builds and prints complex A4 invoices
// ─────────────────────────────────────────────────────────────────────────────

class InvoiceService {
  static const _pageFormat = PdfPageFormat.a4;

  static Future<Uint8List> generateSamplePdf(ShopSettings settings) async {
    final data = InvoiceData(
      invoiceNumber: "FACT-2024-0001",
      date: DateTime.now(),
      items: [
        const InvoiceItem(name: "PC Portable Haute Performance", qty: 1, unitPrice: 450000),
        const InvoiceItem(name: "Câble Réseau (m)", qty: 15.5, unitPrice: 500),
      ],
      subtotal: 480000,
      totalAmount: 480000,
      amountPaid: 480000,
      change: 0,
      cashierName: "DÉMO",
      settings: settings,
      clientName: "Client de Démonstration",
      clientPhone: "+223 00 00 00 00",
      clientAddress: "Bamako, Mali",
      template: settings.defaultInvoice,
    );
    final doc = await _build(data, settings.defaultInvoice);
    return doc.save();
  }

  // Theme colors
  static final _corporateBlue = PdfColor.fromHex('#0D47A1');
  static final _elegantDark = PdfColor.fromHex('#212121');

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<void> print(InvoiceData data, InvoiceTemplate template) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    final doc = await _build(eliteData, template);
    final settings = data.settings;
    String? targetPrinterName;
    
    if (data.isDeliveryNote) {
      targetPrinterName = settings.deliveryPrinterName;
    } else if (data.isProforma) {
      targetPrinterName = settings.proformaPrinterName;
    } else {
      targetPrinterName = settings.invoicePrinterName;
    }

    await PrintingHelper.printWithFallback(
      doc: doc,
      targetPrinterName: targetPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Facture_${data.invoiceNumber}',
    );
  }

  static Future<pw.Document> buildDocument(
    InvoiceData data,
    InvoiceTemplate template,
  ) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    return _build(eliteData, template);
  }

  static Future<void> preview(
    InvoiceData data,
    InvoiceTemplate template,
  ) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    final doc = await _build(eliteData, template);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Aperçu_Facture_${data.invoiceNumber}',
    );
  }

  static pw.Widget _buildLoyaltySection(InvoiceData data) {
    if (!data.settings.loyaltyEnabled || (data.loyaltyPointsGained <= 0 && data.loyaltyPointsBalance <= 0)) {
       return pw.SizedBox();
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("RÉCAPITULATIF FIDÉLITÉ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Row(
            children: [
              if (data.loyaltyPointsGained > 0) ...[
                pw.Text("Points Gagnés: ", style: const pw.TextStyle(fontSize: 9)),
                pw.Text("+${data.loyaltyPointsGained}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.orange)),
                pw.SizedBox(width: 15),
              ],
              pw.Text("Nouveau Solde: ", style: const pw.TextStyle(fontSize: 9)),
              pw.Text("${data.loyaltyPointsBalance} pts", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static Future<pw.Document> _build(
    InvoiceData data,
    InvoiceTemplate template,
  ) async {
    // Fonts are now pre-loaded at startup or lazily loaded synchronously via getters
    
    switch (template) {
      case InvoiceTemplate.corporate:
        return _buildCorporate(data);
      case InvoiceTemplate.elegant:
        return _buildElegant(data);
      case InvoiceTemplate.clean:
        return _buildClean(data);
      case InvoiceTemplate.noirEtBlanc:
        return _buildNoirEtBlanc(data);
      case InvoiceTemplate.minimaliste:
        return _buildMinimaliste(data);
      case InvoiceTemplate.epure:
        return _buildEpure(data);
      case InvoiceTemplate.style:
        return _buildStyle(data);
      case InvoiceTemplate.prestige:
        return _buildPrestige(data);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 1 — CORPORATE
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildCorporate(InvoiceData data) async {
    // Load fonts for Unicode support
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
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        build: (ctx) => [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _corporateBlue, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                   pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      _buildAdaptiveLogo(
                        data,
                        maxWidth: 100,
                        maxHeight: 60,
                        margin: const pw.EdgeInsets.only(right: 20),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            data.settings.name.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 32, // MASSIVE visible name
                              fontWeight: pw.FontWeight.bold,
                              color: _corporateBlue,
                              letterSpacing: 2.0,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              if (data.settings.legalForm.isNotEmpty)
                                pw.Text(
                                  data.settings.legalForm,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey800,
                                  ),
                                ),
                              if (data.settings.capital.isNotEmpty)
                                pw.Text(
                                  ' (Cap: ${data.settings.capital})',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                            ],
                          ),
                          if (data.settings.slogan.isNotEmpty)
                            pw.Text(
                              data.settings.slogan,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        data.documentTitle.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: data.isProforma ? 24 : 36,
                          fontWeight: pw.FontWeight.bold,
                          color: _corporateBlue,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(color: _corporateBlue),
                        child: pw.Text(
                          'N° ${data.invoiceNumber}',
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
            pw.SizedBox(height: 30),

            pw.Padding(
              padding: const pw.EdgeInsets.all(0),
              child: pw.Column(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('ÉMETTEUR'),
                            pw.Text(
                              data.settings.name,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            pw.Text(
                              data.settings.address,
                              style: pw.TextStyle(fontSize: 9),
                            ),
                            if (data.settings.phone.isNotEmpty)
                              pw.Text(
                                'Tél: ${data.settings.phone}',
                                style: pw.TextStyle(fontSize: 9),
                              ),
                            if (data.settings.nif.isNotEmpty)
                              pw.Text(
                                'NIF: ${data.settings.nif} | RC: ${data.settings.rc}',
                                style: pw.TextStyle(fontSize: 9),
                              ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('FACTURÉ À'),
                            pw.Text(
                              data.clientName ?? 'Client Occasionnel',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (data.clientPhone != null)
                              pw.Text(
                                'Tél: ${data.clientPhone}',
                                style: pw.TextStyle(fontSize: 9),
                              ),
                            if (data.clientAddress != null)
                              pw.Text(
                                data.clientAddress!,
                                style: pw.TextStyle(fontSize: 9),
                              ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            _sectionTitle('DÉTAILS'),
                            _infoRow(
                              'Date:',
                              DateFormatter.formatLongDate(data.date),
                              align: pw.TextAlign.right,
                            ),
                            _infoRow(
                              'Mode:',
                              data.paymentMethod ?? 'ESPÈCES',
                              align: pw.TextAlign.right,
                            ),
                            _infoRow(
                              'État:',
                              data.isCredit ? 'IMPAYÉ' : 'PAYÉ',
                              align: pw.TextAlign.right,
                              color: data.isCredit
                                  ? PdfColors.red700
                                  : PdfColors.green700,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),

                  _corporateTableHeader(),
                  ...data.items.map(
                    (item) => pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.grey200,
                            width: 0.5,
                          ),
                        ),
                      ),
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text(
                              item.name,
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          _tableCell(
                            DateFormatter.formatQuantity(item.qty),
                            flex: 1,
                            align: pw.TextAlign.center,
                          ),
                          _tableCell(
                            fmt(item.unitPrice),
                            flex: 2,
                            align: pw.TextAlign.right,
                          ),
                          _tableCell(
                            fmt(item.lineTotal),
                            flex: 2,
                            align: pw.TextAlign.right,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (data.settings.bankAccount.isNotEmpty) ...[
                              _sectionTitle('COORDONNÉES BANCAIRES'),
                              pw.Text(
                                data.settings.bankAccount,
                                style: pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          children: [
                            if (data.shouldShowTax && data.shouldBeDetailed) ...[
                              _invoiceTotalRow(data.settings.labelHT, fmt(data.subtotalHT)),
                              _invoiceTotalRow(
                                '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                                fmt(data.taxAmount),
                              ),
                            ],
                            if (data.discountAmount > 0)
                              _invoiceTotalRow(
                                'REMISE',
                                '- ${fmt(data.discountAmount)}',
                              ),
                            pw.Divider(color: _corporateBlue, thickness: 1.5),
                            _invoiceTotalRow(
                              data.settings.labelTTC,
                              fmt(data.totalAmount),
                              bold: true,
                              accentColor: _corporateBlue,
                            ),
                            if (data.shouldShowTax && !data.shouldBeDetailed)
                              _invoiceTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                            if (!data.isCredit) ...[
                              _invoiceTotalRow('VERSÉ', fmt(data.amountPaid)),
                              _invoiceTotalRow(
                                'RENDU',
                                fmt(data.change),
                                bold: true,
                              ),
                            ] else
                              _invoiceTotalRow(
                                'À REGLER',
                                fmt(data.totalAmount),
                                bold: true,
                                warn: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.Padding(
              padding: const pw.EdgeInsets.all(0),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildStampZone("Cachet & Signature"),
                  _buildQRVerification(data.saleId ?? 'N/A'),
                ],
              ),
            ),

            pw.Spacer(),
            _buildLoyaltySection(data),
            _buildInstitutionnelFooter(data),
          ],
        
      ),
    );
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 2 — ELEGANT
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildElegant(InvoiceData data) async {
    // Load fonts for Unicode support
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
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        build: (ctx) => [
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
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: _elegantDark,
                      ),
                    ),
                  pw.Row(
                      children: [
                        if (data.settings.legalForm.isNotEmpty)
                          pw.Text(
                            '${data.settings.legalForm} ',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _elegantDark),
                          ),
                        if (data.settings.capital.isNotEmpty)
                          pw.Text(
                            '| Cap: ${data.settings.capital}',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                      ],
                    ),
                    pw.Text(
                      data.settings.address,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    if (data.settings.slogan.isNotEmpty)
                      pw.Text(
                        data.settings.slogan,
                        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey500),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      data.documentTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: _elegantDark,
                      ),
                    ),
                    pw.Text(
                      'Réf: ${data.invoiceNumber}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Date: ${DateFormatter.formatDate(data.date)}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('CLIENT'),
                      pw.Text(
                        data.clientName ?? 'Client Occasionnel',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.clientPhone != null)
                        pw.Text(
                          'Contact: ${data.clientPhone}',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _elegantDark),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        data.isCredit ? 'IMPAYÉE' : 'PAYÉE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: data.isCredit
                              ? PdfColors.red
                              : PdfColors.green,
                        ),
                      ),
                      pw.Text(
                        'Mode: ${data.paymentMethod ?? "Standard"}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            _elegantTableHeader(),
            ...data.items.map(
              (item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text(
                        item.name,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        DateFormatter.formatQuantity(item.qty),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        fmt(item.unitPrice),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        fmt(item.lineTotal),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
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
                        _invoiceTotalRow(data.settings.labelHT, fmt(data.subtotalHT)),
                        _invoiceTotalRow(
                          '${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)',
                          fmt(data.taxAmount),
                        ),
                      ],
                      if (data.discountAmount > 0)
                        _invoiceTotalRow(
                          'REMISE',
                          '- ${fmt(data.discountAmount)}',
                        ),
                      pw.Divider(),
                      _invoiceTotalRow(
                        data.settings.labelTTC,
                        fmt(data.totalAmount),
                        bold: true,
                      ),
                      if (data.shouldShowTax && !data.shouldBeDetailed)
                        _invoiceTotalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                      if (!data.isCredit) ...[
                        _invoiceTotalRow('VERSÉ', fmt(data.amountPaid)),
                        _invoiceTotalRow('RENDU', fmt(data.change), bold: true),
                      ] else
                        _invoiceTotalRow(data.settings.labelTTC, fmt(data.totalAmount), bold: true, warn: true),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            _buildLoyaltySection(data),
            _buildInstitutionnelFooter(data),
          ],
        
      ),
    );
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 4 — NOIR & BLANC (Minimalist Pro)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildNoirEtBlanc(InvoiceData data) async {
    // Load fonts for Unicode support
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
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        build: (ctx) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildAdaptiveLogo(
                      data,
                      maxWidth: 90,
                      maxHeight: 55,
                      margin: const pw.EdgeInsets.only(right: 12),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Row(
                          children: [
                            if (data.settings.legalForm.isNotEmpty)
                              pw.Text('${data.settings.legalForm} ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            if (data.settings.capital.isNotEmpty)
                              pw.Text('| Cap: ${data.settings.capital}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          ],
                        ),
                        if (data.settings.slogan.isNotEmpty)
                           pw.Text(data.settings.slogan, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                        pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Tél : ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
                        if (data.settings.rc.isNotEmpty) 
                          pw.Text('RCCM : ${data.settings.rc} | NIF : ${data.settings.nif}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.Text(
                  data.documentTitle.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // Info rows
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FACTURÉ À :',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      data.clientName ?? 'Client Occasionnel',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (data.clientAddress != null)
                      pw.Text(
                        data.clientAddress!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _infoRowNoir('Date :', DateFormatter.formatDate(data.date)),
                    _infoRowNoir('${data.documentTitle} n° :', data.invoiceNumber),
                    _infoRowNoir('Échéance :', 'Au comptant'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cellNoir('Description', bold: true, flex: 5),
                    _cellNoir(
                      'Quantité',
                      bold: true,
                      align: pw.TextAlign.center,
                    ),
                    _cellNoir('Unité', bold: true, align: pw.TextAlign.center),
                    _cellNoir(
                      'Prix unitaire',
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                    _cellNoir('Total', bold: true, align: pw.TextAlign.right),
                  ],
                ),
                ...data.items.map(
                  (item) => pw.TableRow(
                    children: [
                      _cellNoir(item.name, flex: 5),
                      _cellNoir(
                        DateFormatter.formatQuantity(item.qty),
                        align: pw.TextAlign.center,
                      ),
                      _cellNoir('pcs', align: pw.TextAlign.center),
                      _cellNoir(fmt(item.unitPrice), align: pw.TextAlign.right),
                      _cellNoir(
                        fmt(item.lineTotal),
                        align: pw.TextAlign.right,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      if (data.shouldShowTax && data.shouldBeDetailed) ...[
                        _totalRowNoir(data.settings.labelHT, fmt(data.subtotalHT)),
                        _totalRowNoir('Total ${data.settings.taxName}', fmt(data.taxAmount)),
                      ],
                      if (data.discountAmount > 0)
                        _totalRowNoir('Remise', '- ${fmt(data.discountAmount)}'),
                      pw.Divider(thickness: 1),
                      _totalRowNoir(
                        data.settings.labelTTC,
                        fmt(data.totalAmount),
                        bold: true,
                        fontSize: 12,
                      ),
                      if (data.shouldShowTax && !data.shouldBeDetailed)
                        _totalRowNoir('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                      if (!data.isCredit) ...[
                        _totalRowNoir('Versé', fmt(data.amountPaid)),
                        _totalRowNoir('Rendu', fmt(data.change), bold: true),
                      ] else
                        _totalRowNoir('À RÉGLER', fmt(data.totalAmount), bold: true),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            _buildLoyaltySection(data),
            _buildInstitutionnelFooter(data),
          ],
        
      ),
    );
    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 5 — MINIMALISTE (Blue Institutional)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildMinimaliste(InvoiceData data) async {
    // ── CHARGEMENT DES POLICES (Unicode & Premium) ──
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

    // ── CONFIGURATION & FORMATTAGE ──
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(
          val,
          currency,
          removeDecimals: removeDecimals,
        );


    // Palette Premium (Slate & Cobalt)
    final slateBlue = PdfColor.fromHex('#1E293B');
    final secondaryGrey = PdfColors.grey700;
    final lightStroke = PdfColors.grey300;

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        build: (ctx) => [
            // ── EN-TÊTE PREMIUM ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // INFOS SOCIÉTÉ + LOGO
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildAdaptiveLogo(
                        data,
                        maxWidth: 100,
                        maxHeight: 55,
                        margin: const pw.EdgeInsets.only(right: 15),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            data.settings.name.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: slateBlue,
                            ),
                          ),
                          if (data.settings.slogan.isNotEmpty)
                            pw.Text(
                              data.settings.slogan,
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontStyle: pw.FontStyle.italic,
                                color: secondaryGrey,
                              ),
                            ),
                          pw.SizedBox(height: 4),
                          pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Tél: ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
                          if (data.settings.email.isNotEmpty)
                            pw.Text('Email: ${data.settings.email.toLowerCase()}', style: const pw.TextStyle(fontSize: 9)),
                          // Infos fiscales dynamiques
                          pw.SizedBox(height: 5),
                          if (data.settings.rc.isNotEmpty || data.settings.nif.isNotEmpty)
                            pw.Row(
                              children: [
                                if (data.settings.legalForm.isNotEmpty)
                                  pw.Text('${data.settings.legalForm} ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: slateBlue)),
                                if (data.settings.rc.isNotEmpty)
                                  pw.Text('RCCM: ${data.settings.rc}   ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                if (data.settings.nif.isNotEmpty)
                                  pw.Text('NIF: ${data.settings.nif}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          if (data.settings.capital.isNotEmpty)
                            pw.Text('Capital : ${data.settings.capital}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
                // BLOC FACTURE (Indicateur visuel fort)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: slateBlue, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        data.documentTitle.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: slateBlue,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('N° ${data.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Date: ${DateFormatter.formatDate(data.date)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // ── SECTION CLIENT (Facturé à) ──
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FACTURÉ À :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: slateBlue)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          data.clientName?.toUpperCase() ?? 'CLIENT OCCASIONNEL',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                        if (data.clientAddress != null)
                          pw.Text(data.clientAddress!, style: const pw.TextStyle(fontSize: 9)),
                        if (data.clientPhone != null)
                          pw.Text('Tél: ${data.clientPhone!}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                _buildLoyaltySection(data),
            pw.Spacer(),
              ],
            ),
            pw.SizedBox(height: 30),

            // ── TABLEAU DES ARTICLES (Ultra Structure) ──
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: lightStroke, width: 0.5),
                verticalInside: pw.BorderSide(color: lightStroke, width: 0.5),
                bottom: pw.BorderSide(color: slateBlue, width: 1),
                top: pw.BorderSide(color: slateBlue, width: 1),
                left: pw.BorderSide(color: slateBlue, width: 1),
                right: pw.BorderSide(color: slateBlue, width: 1),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(5), // Désignation
                1: const pw.FlexColumnWidth(1), // Qté
                2: const pw.FlexColumnWidth(1.8), // P.U
                3: const pw.FlexColumnWidth(2), // Montant
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: slateBlue),
                  children: [
                    _cellHeader('DÉSIGNATION DES ARTICLES'),
                    _cellHeader('QTÉ'),
                    _cellHeader('P. UNITAIRE'),
                    _cellHeader('MONTANT'),
                  ],
                ),
                // Items
                ...data.items.map((item) => pw.TableRow(
                      children: [
                        _cellBody(item.name.toUpperCase()),
                        _cellBody(DateFormatter.formatQuantity(item.qty), align: pw.TextAlign.center),
                        _cellBody(fmt(item.unitPrice), align: pw.TextAlign.right),
                        _cellBody(fmt(item.lineTotal), align: pw.TextAlign.right, bold: true),
                      ],
                    )),
                // Filler rows (look "Pro")
                ...List.generate(
                  (12 - data.items.length).clamp(3, 12),
                  (_) => pw.TableRow(
                    children: [
                      _cellBody('', height: 22),
                      _cellBody(''),
                      _cellBody(''),
                      _cellBody(''),
                    ],
                  ),
                ),
              ],
            ),

            // ── RÉSUMÉ FINANCIER ──
            pw.SizedBox(height: 15),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Info Paiement & RIB (Dynamique)
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.settings.bankAccount.isNotEmpty) ...[
                        pw.Text('COORDONNÉES BANCAIRES (RIB) :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        pw.Text(data.settings.bankAccount, style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(height: 10),
                      ],
                      pw.Text('Mode de paiement : ${data.paymentMethod ?? "Comptant"}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 20),
                      // Espace Signature
                      pw.Container(
                        width: 150,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: lightStroke, width: 0.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('SIGNATURE / CACHET', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: secondaryGrey)),
                            pw.SizedBox(height: 35),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Totaux
                pw.Expanded(
                  flex: 2,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: slateBlue, width: 0.5),
                    children: [
                      if (data.shouldShowTax && data.shouldBeDetailed) ...[
                        _summaryRowPremium(data.settings.labelHT, fmt(data.subtotalHT)),
                        _summaryRowPremium('${data.settings.taxName.toUpperCase()} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
                      ],
                      if (data.discountAmount > 0)
                        _summaryRowPremium('REMISE DÉDUITE', '- ${fmt(data.discountAmount)}'),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: slateBlue),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(data.settings.labelTTC, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(fmt(data.totalAmount),
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      if (data.shouldShowTax && !data.shouldBeDetailed)
                        _summaryRowPremium('DONT ${data.settings.taxName.toUpperCase()}', fmt(data.taxAmount)),
                      if (!data.isCredit) ...[
                        _summaryRowPremium('MONTANT VERSÉ', fmt(data.amountPaid)),
                        _summaryRowPremium('RENDU / RELIQUAT', fmt(data.change)),
                      ] else
                        _summaryRowPremium('À RÉGLER', fmt(data.totalAmount)),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            _buildLoyaltySection(data),
            _buildInstitutionnelFooter(data),
          ],
        
      ),
    );
    return doc;
  }

  // ── HELPERS PREMIUM ──

  static pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
      ),
    );
  }

  static pw.Widget _cellBody(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false, double? height}) {
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromHex('#334155'), // Slate-700
        ),
      ),
    );
  }

  static pw.TableRow _summaryRowPremium(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 6 — EPURÉ (Purple Structured)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildEpure(InvoiceData data) async {
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


    final midnightNavy = PdfColor.fromHex('#0F172A');
    final accentGold = PdfColor.fromHex('#F59E0B');
    final softSlate = PdfColor.fromHex('#64748B');
    final ultraLightGrey = PdfColor.fromHex('#F8FAFC');

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        build: (ctx) => [
            pw.Container(
              color: midnightNavy,
              padding: const pw.EdgeInsets.all(0),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildAdaptiveLogo(
                        data,
                        maxWidth: 120,
                        maxHeight: 60,
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        fallback: pw.Text(
                          data.settings.name.toUpperCase(),
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 2),
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        data.documentTitle.toUpperCase(),
                        style: pw.TextStyle(color: accentGold, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 3),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'N° ${data.invoiceNumber}',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('DATE : ${DateFormatter.formatLongDate(data.date).toUpperCase()}', style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
                      if (data.settings.legalForm.isNotEmpty || data.settings.rc.isNotEmpty)
                        pw.Text(
                          '${data.settings.legalForm} ${data.settings.rc.isNotEmpty ? "| RCCM: ${data.settings.rc}" : ""}',
                          style: pw.TextStyle(color: PdfColors.grey400, fontSize: 8),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(0),
              child: pw.Column(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ÉMETTEUR', style: pw.TextStyle(color: softSlate, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.SizedBox(height: 8),
                            pw.Text(data.settings.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('Tél : ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
                            if (data.settings.nif.isNotEmpty)
                              pw.Text('NIF : ${data.settings.nif}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('FACTURÉ À', style: pw.TextStyle(color: softSlate, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.SizedBox(height: 8),
                            pw.Text(data.clientName?.toUpperCase() ?? 'CLIENT OCCASIONNEL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: midnightNavy)),
                            if (data.clientAddress != null)
                              pw.Text(data.clientAddress!, style: const pw.TextStyle(fontSize: 9)),
                            if (data.clientPhone != null)
                              pw.Text('Tél : ${data.clientPhone!}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4.5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: midnightNavy, width: 2))),
                        children: [
                          _cellDesigner('DÉSIGNATION', bold: true, align: pw.TextAlign.left),
                          _cellDesigner('QTÉ', bold: true),
                          _cellDesigner('P. UNITAIRE', bold: true, align: pw.TextAlign.right),
                          _cellDesigner('MONTANT', bold: true, align: pw.TextAlign.right),
                        ],
                      ),
                      ...data.items.asMap().entries.map((entry) {
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : ultraLightGrey),
                          children: [
                            _cellDesigner(entry.value.name.toUpperCase(), align: pw.TextAlign.left),
                            _cellDesigner(DateFormatter.formatQuantity(entry.value.qty)),
                            _cellDesigner(fmt(entry.value.unitPrice), align: pw.TextAlign.right),
                            _cellDesigner(fmt(entry.value.lineTotal), align: pw.TextAlign.right, bold: true),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (data.settings.bankAccount.isNotEmpty) ...[
                              pw.Text('COORDONNÉES BANCAIRES (RIB)', style: pw.TextStyle(color: softSlate, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              pw.SizedBox(height: 5),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                color: ultraLightGrey,
                                child: pw.Text(data.settings.bankAccount, style: pw.TextStyle(fontSize: 8, color: midnightNavy)),
                              ),
                            ],
                            pw.SizedBox(height: 15),
                            pw.Text('Mode de paiement : ${data.paymentMethod ?? "Non spécifié"}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 40),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          children: [
                            if (data.shouldShowTax && data.shouldBeDetailed) ...[
                              _summaryRowDesigner(data.settings.labelHT, fmt(data.subtotalHT)),
                              _summaryRowDesigner('${data.settings.taxName.toUpperCase()} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
                            ],
                            if (data.discountAmount > 0)
                              _summaryRowDesigner('REMISE DÉDUITE', '- ${fmt(data.discountAmount)}', isNegative: true),
                            pw.SizedBox(height: 10),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              color: midnightNavy,
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(data.settings.labelTTC, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                                  pw.Text(fmt(data.totalAmount), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (data.shouldShowTax && !data.shouldBeDetailed)
                              _summaryRowDesigner('DONT ${data.settings.taxName.toUpperCase()}', fmt(data.taxAmount)),
                            if (!data.isCredit) ...[
                              _summaryRowDesigner('MONTANT VERSÉ', fmt(data.amountPaid)),
                              _summaryRowDesigner('RENDU / RELIQUAT', fmt(data.change)),
                            ] else
                              _summaryRowDesigner('À RÉGLER', fmt(data.totalAmount)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            _buildLoyaltySection(data),
            _buildInstitutionnelFooter(data),
          ],
        
      ),
    );
    return doc;
  }

  static pw.Widget _cellDesigner(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _summaryRowDesigner(String label, String value, {bool isNegative = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isNegative ? PdfColors.red700 : PdfColors.black)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 7 — STYLE (MODERNE AGÉNCE)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildStyle(InvoiceData data) async {
    // ── CHARGEMENT DES POLICES ──
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

    // ── CONFIGURATION & FORMATTAGE ──
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(
          val,
          currency,
          removeDecimals: removeDecimals,
        );


    // Palette "Executive Sharp"
    final darkSlate = PdfColor.fromHex('#1E293B');
    final accentBlue = PdfColor.fromHex('#3B82F6');
    final lightStroke = PdfColor.fromHex('#E2E8F0');
    final backgroundWash = PdfColor.fromHex('#F8FAFC');

    doc.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginInvoiceLeft,
          data.settings.marginInvoiceTop,
          data.settings.marginInvoiceRight,
          data.settings.marginInvoiceBottom,
        ),
        build: (ctx) => [
            // ── EN-TÊTE CHIRURGICAL ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bloc Identité
                pw.Column(
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
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: darkSlate, letterSpacing: 1),
                    ),
                    if (data.settings.slogan.isNotEmpty)
                      pw.Text(data.settings.slogan, style: pw.TextStyle(fontSize: 9, color: accentBlue, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 5),
                    pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Tél : ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
                    if (data.settings.rc.isNotEmpty || data.settings.nif.isNotEmpty)
                      pw.Text(
                        '${data.settings.rc.isNotEmpty ? "RCCM: ${data.settings.rc}" : ""} ${data.settings.nif.isNotEmpty ? "| NIF: ${data.settings.nif}" : ""}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                  ],
                ),
                // Bloc Titre & Numéro
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      data.documentTitle.toUpperCase(),
                      style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold, color: darkSlate, letterSpacing: -1),
                    ),
                    pw.Container(height: 3, width: 80, color: accentBlue, margin: const pw.EdgeInsets.symmetric(vertical: 8)),
                    pw.Text('N° : ${data.invoiceNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('DATE : ${DateFormatter.formatDate(data.date)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 50),

            // ── DESTINATAIRE (Style Linéaire) ──
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: accentBlue, width: 4)),
                color: backgroundWash,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FACTURÉ À', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        data.clientName?.toUpperCase() ?? 'CLIENT OCCASIONNEL',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: darkSlate),
                      ),
                      if (data.clientAddress != null) pw.Text(data.clientAddress!, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  if (data.clientPhone != null)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('TÉLÉPHONE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 5),
                        pw.Text(data.clientPhone!, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                ],
              ),
            ),

            pw.SizedBox(height: 40),

            // ── TABLEAU EXECUTIVE ──
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(4), // Désignation
                1: const pw.FlexColumnWidth(1), // Qté
                2: const pw.FlexColumnWidth(2), // P.U
                3: const pw.FlexColumnWidth(2), // Total
              },
              children: [
                // En-tête
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: darkSlate),
                  children: [
                    _cellExecutive('DÉSIGNATION', bold: true, color: PdfColors.white, align: pw.TextAlign.left),
                    _cellExecutive('QTÉ', bold: true, color: PdfColors.white),
                    _cellExecutive('P. UNITAIRE', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _cellExecutive('MONTANT', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                // Lignes
                ...data.items.asMap().entries.map((entry) {
                  final item = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: lightStroke, width: 0.5))),
                    children: [
                      _cellExecutive(item.name.toUpperCase(), align: pw.TextAlign.left),
                      _cellExecutive(DateFormatter.formatQuantity(item.qty)),
                      _cellExecutive(fmt(item.unitPrice), align: pw.TextAlign.right),
                      _cellExecutive(fmt(item.lineTotal), align: pw.TextAlign.right, bold: true),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 30),

            // ── RÉSUMÉ FINANCIER ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      if (data.shouldShowTax && data.shouldBeDetailed) ...[
                        _summaryRowExecutive(data.settings.labelHT, fmt(data.subtotalHT)),
                        _summaryRowExecutive('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
                      ],
                      if (data.discountAmount > 0)
                        _summaryRowExecutive('Remise', '- ${fmt(data.discountAmount)}', isRed: true),
                      pw.Divider(color: darkSlate),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(data.settings.labelTTC, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkSlate)),
                            pw.Text(fmt(data.totalAmount), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accentBlue)),
                          ],
                        ),
                      ),
                      if (data.shouldShowTax && !data.shouldBeDetailed)
                        _summaryRowExecutive('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                      if (!data.isCredit) ...[
                        _summaryRowExecutive('Montant Versé', fmt(data.amountPaid)),
                        _summaryRowExecutive('Rendu', fmt(data.change)),
                      ] else
                        _summaryRowExecutive('À RÉGLER', fmt(data.totalAmount)),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // ── PIED DE PAGE & RIB ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.settings.bankAccount.isNotEmpty) ...[
                        pw.Text('COORDONNÉES BANCAIRES (RIB)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 5),
                        pw.Text(data.settings.bankAccount, style: pw.TextStyle(fontSize: 8, color: darkSlate)),
                        pw.SizedBox(height: 15),
                      ],
                      pw.Text('Mode de paiement : ${data.paymentMethod ?? "Comptant"}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        data.settings.receiptFooter.isNotEmpty ? data.settings.receiptFooter : 'Nous vous remercions de votre confiance.',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            _buildLoyaltySection(data),
            _buildInstitutionnelFooter(data),
          ],
        
      ),
    );
    return doc;
  }

  // ── HELPERS EXECUTIVE ──

  static pw.Widget _cellExecutive(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _summaryRowExecutive(String label, String value, {bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isRed ? PdfColors.red : PdfColors.black)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 3 — CLEAN (Orange Artisan)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildClean(InvoiceData data) async {
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


    // Palette "Amber Precision"
    final amberIntense = PdfColor.fromHex('#D97706');
    final carbonDark = PdfColor.fromHex('#111827');
    final slateGrey = PdfColor.fromHex('#4B5563');
    final ivoryBg = PdfColor.fromHex('#FDFCFB');

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
          buildBackground: (ctx) => pw.Stack(
            children: [
              // Fond subtil
              pw.Container(color: ivoryBg),

              // Bandeau latéral décoratif (Asymétrique)
              pw.Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: pw.Container(width: 5, color: amberIntense),
              ),
            ],
          ),
        ),
        footer: (ctx) => _buildInstitutionnelFooter(data),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.all(0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                  // --- EN-TÊTE ASYMÉTRIQUE ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Bloc Logo flottant
                      _buildAdaptiveLogo(
                        data,
                        maxWidth: 120,
                        maxHeight: 65,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: amberIntense, width: 1.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        ),
                        padding: const pw.EdgeInsets.all(4),
                        fallback: pw.Container(
                          width: 80,
                          height: 65,
                          color: amberIntense,
                          child: pw.Center(
                            child: pw.Text(
                              data.settings.name.substring(0, 1).toUpperCase(),
                              style: pw.TextStyle(fontSize: 40, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 25),
                      // Infos Société
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(data.settings.name.toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: carbonDark, letterSpacing: 1.5)),
                            pw.Row(
                              children: [
                                if (data.settings.legalForm.isNotEmpty)
                                  pw.Text(data.settings.legalForm, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: amberIntense)),
                                if (data.settings.capital.isNotEmpty)
                                  pw.Text(' au capital de ${data.settings.capital}', style: pw.TextStyle(fontSize: 10, color: slateGrey)),
                              ],
                            ),
                            if (data.settings.slogan.isNotEmpty)
                              pw.Text(data.settings.slogan, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: slateGrey)),
                            pw.SizedBox(height: 10),
                            pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('Tél : ${data.settings.phone}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                      // Bloc Facture (Contraste Fort)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        color: carbonDark,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(data.documentTitle.toUpperCase(), style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: amberIntense, letterSpacing: 2)),
                            pw.SizedBox(height: 5),
                            pw.Text('N° ${data.invoiceNumber}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            pw.Text(DateFormatter.formatLongDate(data.date).toUpperCase(), style: pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 50),

                  // --- SECTION CLIENT ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('DESTINATAIRE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: amberIntense, letterSpacing: 1.2)),
                            pw.SizedBox(height: 8),
                            pw.Text(data.clientName?.toUpperCase() ?? 'CLIENT OCCASIONNEL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: carbonDark)),
                            if (data.clientAddress != null) pw.Text(data.clientAddress!, style: const pw.TextStyle(fontSize: 10)),
                            if (data.clientPhone != null) pw.Text('Tél : ${data.clientPhone!}', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 1,
                        height: 60,
                        color: PdfColor(0.85, 0.46, 0.02, 0.3), // Amber with 0.3 opacity
                        margin: const pw.EdgeInsets.symmetric(horizontal: 30),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('PAIEMENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: amberIntense, letterSpacing: 1.2)),
                          pw.SizedBox(height: 8),
                          pw.Text(data.paymentMethod ?? 'Standard', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          if (data.settings.invoiceLegalNote.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(top: 5),
                              child: pw.Text(data.settings.invoiceLegalNote, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: slateGrey)),
                            ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 40),

                  // --- TABLEAU AMBER PRECISION ---
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(5),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2.5),
                    },
                    children: [
                      // Header
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: carbonDark),
                        children: [
                          _cellAmber('DÉSIGNATION', bold: true, color: PdfColors.white, align: pw.TextAlign.left),
                          _cellAmber('QTÉ', bold: true, color: PdfColors.white),
                          _cellAmber('P. UNITAIRE', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
                          _cellAmber(data.settings.labelHT.toUpperCase(), bold: true, color: amberIntense, align: pw.TextAlign.right),
                        ],
                      ),
                      // Lignes
                      ...data.items.asMap().entries.map((entry) {
                        final item = entry.value;
                        final mercuryGrey = PdfColor.fromHex('#F3F4F6');
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: entry.key % 2 == 0 ? PdfColors.white : mercuryGrey,
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                          ),
                          children: [
                            _cellAmber(item.name.toUpperCase(), align: pw.TextAlign.left, fontSize: 9),
                            _cellAmber(DateFormatter.formatQuantity(item.qty)),
                            _cellAmber(fmt(item.unitPrice), align: pw.TextAlign.right),
                            _cellAmber(fmt(item.lineTotal), align: pw.TextAlign.right, bold: true, color: carbonDark),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 30),

                  // --- RÉSUMÉ FINANCIER ---
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Container(
                        width: 220,
                        child: pw.Column(
                          children: [
                            if (data.shouldShowTax && data.shouldBeDetailed) ...[
                              _summaryRowAmber(data.settings.labelHT, fmt(data.subtotalHT)),
                              _summaryRowAmber('${data.settings.taxName} (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
                            ],
                            if (data.discountAmount > 0)
                              _summaryRowAmber('REMISE DÉDUITE', '- ${fmt(data.discountAmount)}', isRed: true),
                            pw.Container(
                              margin: const pw.EdgeInsets.only(top: 10),
                              padding: const pw.EdgeInsets.all(12),
                              color: carbonDark,
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(data.settings.labelTTC, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                  pw.Text(fmt(data.totalAmount), style: pw.TextStyle(color: amberIntense, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (data.shouldShowTax && !data.shouldBeDetailed)
                              _summaryRowAmber('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                            if (!data.isCredit) ...[
                               _summaryRowAmber('MONTANT VERSÉ', fmt(data.amountPaid)),
                               _summaryRowAmber('RENDU / RELIQUAT', fmt(data.change)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // --- FOOTER INSTITUTIONNEL ---
                  _buildLoyaltySection(data),
                ],
              ),
            ),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _infoRowNoir(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(width: 5),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  static pw.Widget _cellNoir(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    int flex = 2,
  }) => pw.Expanded(
    flex: flex,
    child: pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    ),
  );

  static pw.Widget _totalRowNoir(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 9,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _summaryRowAmber(String label, String value, {bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isRed ? PdfColors.red : PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _cellAmber(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false, PdfColor? color, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _buildInstitutionnelFooter(InvoiceData data) {
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
                  pw.Text('COORDONNÉES & LÉGAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: slateBlue)),
                  pw.SizedBox(height: 5),
                  pw.Text(_c(s.address), style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('Tél : ${_c(s.phone)} ${s.whatsapp.isNotEmpty ? "| WhatsApp : ${_c(s.whatsapp)}" : ""}', style: const pw.TextStyle(fontSize: 7)),
                  if (s.email.isNotEmpty) pw.Text('Email : ${_c(s.email).toLowerCase()}', style: const pw.TextStyle(fontSize: 7)),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      if (s.rc.isNotEmpty) pw.Text('RCCM : ${_c(s.rc)}  ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      if (s.nif.isNotEmpty) pw.Text('NIF : ${_c(s.nif)}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            // Bloc Politiques (Garantie / Retours)
            pw.Expanded(
              flex: 3,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (s.policyWarranty.isNotEmpty)
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 15),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('GARANTIE', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: accentColor)),
                            pw.SizedBox(height: 3),
                            pw.Text(s.policyWarranty, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700), textAlign: pw.TextAlign.justify),
                          ],
                        ),
                      ),
                    ),
                  if (s.policyReturns.isNotEmpty)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RETOURS', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: accentColor)),
                          pw.SizedBox(height: 3),
                          pw.Text(s.policyReturns, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700), textAlign: pw.TextAlign.justify),
                        ],
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
                  pw.Text('SIGNATURE & CACHET', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
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

  static String _c(String? t) {
    if (t == null) return "";
    return t.replaceAll('—', '-').replaceAll('📞', 'Tél: ').replaceAll('™', '').replaceAll('®', '').replaceAll('—', '-');
  }

  static Future<pw.Document> _buildPrestige(InvoiceData data) async {
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

    // ── CONFIGURATION & FORMATTAGE ──
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(
          val,
          currency,
          removeDecimals: removeDecimals,
        );


    // Palette "Grand Palace"
    final royalGold = PdfColor.fromHex('#B2925A'); // Or Royal
    final deepCharcoal = PdfColor.fromHex('#1A1A1A'); // Charbon profond
    final ivoryWash = PdfColor.fromHex('#FCFBF7'); // Fond Ivoire subtil
    final goldSoft = PdfColor.fromHex('#F4EFE6'); // Fond Or très clair

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
                // ── FOND IVOIRE ──
                pw.Container(color: ivoryWash),

                // ── BORDURE DÉCORATIVE OR ──
                pw.Positioned(
                  left: 15,
                  top: 15,
                  right: 15,
                  bottom: 15,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: royalGold, width: 0.5),
                    ),
                  ),
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
                    // --- HEADER ROYAL ---
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Logo & Identité
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildAdaptiveLogo(
                                data,
                                maxWidth: 140,
                                maxHeight: 75,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: royalGold, width: 1),
                                ),
                                padding: const pw.EdgeInsets.all(5),
                                margin: const pw.EdgeInsets.only(bottom: 15),
                                alignment: pw.Alignment.center,
                              ),
                              pw.Text(
                                data.settings.name.toUpperCase(),
                                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: royalGold, letterSpacing: 2),
                              ),
                              if (data.settings.slogan.isNotEmpty)
                                pw.Text(data.settings.slogan, style: pw.TextStyle(fontSize: 10, color: deepCharcoal, fontStyle: pw.FontStyle.italic)),
                              pw.SizedBox(height: 8),
                              pw.Text(_c(data.settings.address), style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Tél : ${_c(data.settings.phone)}', style: const pw.TextStyle(fontSize: 9)),
                              if (data.settings.rc.isNotEmpty || data.settings.nif.isNotEmpty)
                                pw.Text(
                                  '${data.settings.legalForm} | RCCM: ${data.settings.rc} | NIF: ${data.settings.nif}',
                                  style: pw.TextStyle(fontSize: 8, color: royalGold),
                                ),
                            ],
                          ),
                        ),
                        // Titre & Détails
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              data.documentTitle,
                              style: pw.TextStyle(fontSize: 45, fontWeight: pw.FontWeight.bold, color: deepCharcoal, letterSpacing: -2),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text('N° ${data.invoiceNumber}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text(DateFormatter.formatLongDate(data.date).toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
                            if (data.settings.rc.isNotEmpty || data.settings.nif.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 8),
                                child: pw.Text(
                                  '${data.settings.rc.isNotEmpty ? "RCCM: ${data.settings.rc}" : ""} ${data.settings.nif.isNotEmpty ? "\nNIF: ${data.settings.nif}" : ""}',
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 50),

                    // --- SECTION CLIENT ---
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(20),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('DESTINATAIRE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: royalGold, letterSpacing: 1.5)),
                                pw.SizedBox(height: 10),
                                pw.Text(
                                  data.clientName?.toUpperCase() ?? 'CLIENT OCCASIONNEL',
                                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: deepCharcoal),
                                ),
                                if (data.clientAddress != null) pw.Text(_c(data.clientAddress!), style: const pw.TextStyle(fontSize: 10)),
                                if (data.clientPhone != null) pw.Text('Tél : ${_c(data.clientPhone!)}', style: const pw.TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 30),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('STATUT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: royalGold)),
                            pw.SizedBox(height: 5),
                            _statusBadgePrestige(data.isCredit ? 'À RÉGLER' : 'CONFIRMÉ', data.isCredit ? PdfColors.red900 : royalGold),
                            pw.SizedBox(height: 15),
                            pw.Text('RÈGLEMENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: royalGold)),
                            pw.Text(data.paymentMethod ?? 'Standard', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 40),

                    // --- TABLEAU LUXURY ---
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
                          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: royalGold, width: 2))),
                          children: [
                            _cellPrestige('DÉSIGNATION DES ARTICLES', bold: true, align: pw.TextAlign.left),
                            _cellPrestige('QTÉ', bold: true),
                            _cellPrestige('UNITAIRE', bold: true, align: pw.TextAlign.right),
                            _cellPrestige('TOTAL HT', bold: true, align: pw.TextAlign.right),
                          ],
                        ),
                        // Lignes
                        ...data.items.asMap().entries.map((entry) {
                          final item = entry.value;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100, width: 0.5))),
                            children: [
                              _cellPrestige(item.name.toUpperCase(), align: pw.TextAlign.left, fontSize: 10),
                              _cellPrestige(DateFormatter.formatQuantity(item.qty)),
                              _cellPrestige(fmt(item.unitPrice), align: pw.TextAlign.right),
                              _cellPrestige(fmt(item.lineTotal), align: pw.TextAlign.right, bold: true),
                            ],
                          );
                        }),
                      ],
                    ),

                    pw.SizedBox(height: 30),

                    // --- RÉSUMÉ & RIB ---
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // RIB / Banque
                        pw.Expanded(
                          flex: 2,
                          child: data.settings.bankAccount.isNotEmpty 
                            ? pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('COORDONNÉES BANCAIRES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: royalGold)),
                                  pw.SizedBox(height: 5),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(10),
                                    decoration: pw.BoxDecoration(color: goldSoft, borderRadius: pw.BorderRadius.circular(4)),
                                    child: pw.Text(_c(data.settings.bankAccount), style: pw.TextStyle(fontSize: 8, color: deepCharcoal)),
                                  ),
                                ],
                              )
                            : pw.SizedBox(),
                        ),
                        pw.SizedBox(width: 40),
                        // Totaux
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            children: [
                              if (data.shouldShowTax && data.shouldBeDetailed) ...[
                                _summaryRowPrestige('Montant HT', fmt(data.subtotalHT)),
                                _summaryRowPrestige('TVA (${(data.taxRate * 100).toInt()}%)', fmt(data.taxAmount)),
                              ],
                              if (data.discountAmount > 0)
                                _summaryRowPrestige('Remise', '- ${fmt(data.discountAmount)}', isGold: true),
                              pw.Divider(color: royalGold, thickness: 1),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                decoration: pw.BoxDecoration(color: deepCharcoal),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('TOTAL NET', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                                    pw.Text(fmt(data.totalAmount), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: royalGold)),
                                  ],
                                ),
                              ),
                              if (data.shouldShowTax && !data.shouldBeDetailed)
                                _summaryRowPrestige('Dont ${data.settings.taxName}', fmt(data.taxAmount)),
                              if (!data.isCredit) ...[
                                _summaryRowPrestige('Montant Versé', fmt(data.amountPaid)),
                                _summaryRowPrestige('Rendu / Reliquat', fmt(data.change), isGold: true),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // --- FOOTER ROYAL ---
                    _buildLoyaltySection(data),
                  ],
                ),
              ),
        ],
      ),
    );
    return doc;
  }

  // --- HELPERS PRESTIGE ---

  static pw.Widget _statusBadgePrestige(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  static pw.Widget _cellPrestige(String text, {pw.TextAlign align = pw.TextAlign.center, bool bold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromHex('#1A1A1A'),
        ),
      ),
    );
  }

  static pw.Widget _summaryRowPrestige(String label, String value, {bool isGold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: isGold ? PdfColor.fromHex('#B2925A') : PdfColors.black)),
        ],
      ),
    );
  }


  // ── Helpers ─────────────────────────────────────────────────────────────────
  
  static pw.Widget _buildAdaptiveLogo(
    InvoiceData data, {
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
        letterSpacing: 1.2,
      ),
    ),
  );

  static pw.Widget _infoRow(
    String label,
    String value, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisAlignment: align == pw.TextAlign.right
          ? pw.MainAxisAlignment.end
          : pw.MainAxisAlignment.start,
      children: [
        pw.Text(
          '$label ',
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

  static pw.Widget _corporateTableHeader() => pw.Container(
    decoration: pw.BoxDecoration(color: _corporateBlue),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 5, child: _colHeader('DESCRIPTION')),
        _colHeader('QTÉ', flex: 1, align: pw.TextAlign.center),
        _colHeader('PRIX UNIT.', flex: 2, align: pw.TextAlign.right),
        _colHeader('TOTAL', flex: 2, align: pw.TextAlign.right),
      ],
    ),
  );

  static pw.Widget _elegantTableHeader() => pw.Container(
    decoration: pw.BoxDecoration(color: _elegantDark),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 5, child: _colHeader('ARTICLE')),
        _colHeader('QTÉ', flex: 1, align: pw.TextAlign.center),
        _colHeader('UNITÉ', flex: 2, align: pw.TextAlign.right),
        _colHeader('SOUS-TOTAL', flex: 2, align: pw.TextAlign.right),
      ],
    ),
  );

  static pw.Widget _colHeader(
    String text, {
    int flex = 2,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Expanded(
    flex: flex,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        letterSpacing: 0.5,
      ),
      textAlign: align,
    ),
  );

  static pw.Widget _tableCell(
    String text, {
    int flex = 2,
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) => pw.Expanded(
    flex: flex,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: align,
    ),
  );

  static pw.Widget _invoiceTotalRow(
    String label,
    String value, {
    bool bold = false,
    bool warn = false,
    PdfColor? accentColor,
  }) {
    final color = warn ? PdfColors.red700 : (accentColor ?? PdfColors.black);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: bold ? color : PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: bold ? color : PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStampZone(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 150,
          height: 70,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Center(
            child: pw.Text(
              'CACHET ET SIGNATURE',
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey300),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildQRVerification(String saleId) {
    return pw.Column(
      children: [
        pw.Container(
          width: 48,
          height: 48,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: 'verify:sale:$saleId',
            drawText: false,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Scanner pour vérifier',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
