import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/services/hardware_service.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';

class ReceiptData {
  final String saleId;
  final DateTime date;
  final List<ReceiptItem> items;
  final double totalAmount;
  final double amountPaid;
  final double change;
  final double discountAmount;
  final bool isCredit;
  final String? clientName;
  final String? clientPhone;
  final String cashierName;
  final ShopSettings settings;
  final String? paymentMethod;

  const ReceiptData({
    required this.saleId,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.change,
    this.isCredit = false,
    this.clientName,
    this.clientPhone,
    required this.cashierName,
    required this.settings,
    this.paymentMethod,
    this.discountAmount = 0.0,
    this.loyaltyPointsBalance = 0,
    this.loyaltyPointsGained = 0,
    this.template,
    this.isProforma = false,
  });

  final bool isProforma;
  final int loyaltyPointsGained;
  final int loyaltyPointsBalance;
  final ReceiptTemplate? template;

  double get taxAmount => totalAmount - (totalAmount / (1 + (settings.taxRate / 100)));

  bool get shouldShowTax => settings.useTax && settings.getTemplateShowTax('ticket', template?.name ?? 'classic');
  bool get shouldBeDetailed => settings.useTax && settings.getTemplateDetailed('ticket', template?.name ?? 'classic');

  ReceiptData copyWith({
    String? saleId,
    DateTime? date,
    List<ReceiptItem>? items,
    double? totalAmount,
    double? amountPaid,
    double? change,
    double? discountAmount,
    bool? isCredit,
    String? clientName,
    String? clientPhone,
    String? cashierName,
    ShopSettings? settings,
    String? paymentMethod,
    int? loyaltyPointsBalance,
    int? loyaltyPointsGained,
    ReceiptTemplate? template,
    bool? isProforma,
  }) {
    return ReceiptData(
      saleId: saleId ?? this.saleId,
      date: date ?? this.date,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      change: change ?? this.change,
      discountAmount: discountAmount ?? this.discountAmount,
      isCredit: isCredit ?? this.isCredit,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      cashierName: cashierName ?? this.cashierName,
      settings: settings ?? this.settings,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loyaltyPointsBalance: loyaltyPointsBalance ?? this.loyaltyPointsBalance,
      loyaltyPointsGained: loyaltyPointsGained ?? this.loyaltyPointsGained,
      template: template ?? this.template,
      isProforma: isProforma ?? this.isProforma,
    );
  }
}

class ReceiptItem {
  final String name;
  final double qty;
  final double unitPrice;
  final double discountPercent;

  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.discountPercent = 0.0,
  });

  double get lineTotal => qty * unitPrice * (1 - (discountPercent / 100));
}

// ReceiptTemplate moved to settings_models.dart

class ReceiptService {
  static PdfPageFormat _getFormat(ShopSettings s) {
    double width = s.thermalFormat == ThermalPaperFormat.mm80 ? 226 : 160;
    return PdfPageFormat(width, double.infinity, marginAll: 0);
  }

  static final _error = PdfColors.red700;

  static Future<void> print(ReceiptData data, ReceiptTemplate template) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    final doc = await _build(eliteData, template);
    final settings = data.settings;

    await PrintingHelper.printWithFallback(
      doc: doc,
      targetPrinterName: settings.thermalPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Ticket_${data.saleId.substring(0, 8)}',
    );

    // Ouverture du tiroir si activé ET paiement en espèces uniquement
    final bool isCash = (data.paymentMethod == null || 
        data.paymentMethod!.toLowerCase().contains('espèce') || 
        data.paymentMethod!.toLowerCase().contains('espece') || 
        data.paymentMethod!.toLowerCase().contains('cash'));

    if (settings.openCashDrawer && settings.thermalPrinterName != null && isCash) {
      await HardwareService().kickDrawer(settings.thermalPrinterName!);
    }
  }

  static Future<pw.Document> buildDocument(
    ReceiptData data,
    ReceiptTemplate template,
  ) async {
    final eliteData = data.template == null ? data.copyWith(template: template) : data;
    return _build(eliteData, template);
  }

  static Future<Uint8List> generateSamplePdf(ShopSettings settings) async {
    final data = ReceiptData(
      saleId: "PREVIEW-123456",
      date: DateTime.now(),
      items: [
        const ReceiptItem(name: "Article Démo 1", qty: 2.5, unitPrice: 1500),
        const ReceiptItem(name: "Article Démo 2", qty: 1, unitPrice: 3500),
      ],
      totalAmount: 6500,
      amountPaid: 7000,
      change: 500,
      cashierName: "DÉMO",
      settings: settings,
      template: settings.defaultReceipt,
    );
    final doc = await _build(data, settings.defaultReceipt);
    return doc.save();
  }

  static pw.Widget _buildLoyaltySection(ReceiptData data) {
    if (!data.settings.loyaltyEnabled || (data.loyaltyPointsGained <= 0 && data.loyaltyPointsBalance <= 0)) {
      return pw.SizedBox();
    }

    return pw.Column(
      children: [
        _divider(dashed: true),
        pw.Text(
          "POINTS DE FIDÉLITÉ",
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        if (data.loyaltyPointsGained > 0)
          _totalRow("POINTS GAGNÉS", "+${data.loyaltyPointsGained} pts"),
        _totalRow("NOUVEAU SOLDE", "${data.loyaltyPointsBalance} pts", bold: true),
      ],
    );
  }

  static Future<void> preview(
    ReceiptData data,
    ReceiptTemplate template,
  ) async {
    final doc = await _build(data, template);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Aperçu_Ticket_${DateFormatter.formatFileName(data.date)}',
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

  static ReceiptData _sanitizeData(ReceiptData data) {
    final cleanItems = data.items.map((item) => ReceiptItem(
      name: _c(item.name),
      qty: item.qty,
      unitPrice: item.unitPrice,
      discountPercent: item.discountPercent,
    )).toList();

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
      cashierName: _c(data.cashierName),
      paymentMethod: data.paymentMethod != null ? _c(data.paymentMethod) : null,
      items: cleanItems,
      settings: cleanSettings,
    );
  }

  static Future<pw.Document> _build(
    ReceiptData data,
    ReceiptTemplate template,
  ) async {
    // Fonts are now pre-loaded at startup or lazily loaded synchronously via getters
    final sanitizedData = _sanitizeData(data);
    final format = _getFormat(sanitizedData.settings);
    switch (template) {
      case ReceiptTemplate.classic:
        return _buildClassic(sanitizedData, format);
      case ReceiptTemplate.modern:
        return _buildModern(sanitizedData, format);
      case ReceiptTemplate.minimal:
        return _buildMinimal(sanitizedData, format);
      case ReceiptTemplate.elite:
        return _buildElite(sanitizedData, format);
      case ReceiptTemplate.prestige:
        return _buildPrestige(sanitizedData, format);
    }
  }

  static Future<pw.Document> _buildClassic(
    ReceiptData data,
    PdfPageFormat format,
  ) async {
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
    // ... rest of the method uses 'format' instead of _thermalPageFormat
    final String currency = data.settings.currency;
    final bool removeDecimals = data.settings.removeDecimals;
    String fmt(double val) => DateFormatter.formatCurrency(
      val,
      currency,
      removeDecimals: removeDecimals,
    );
    final dateFmtStr = DateFormatter.formatDateTime(data.date);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginTicketLeft,
          data.settings.marginTicketTop,
          data.settings.marginTicketRight,
          data.settings.marginTicketBottom,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  _buildAdaptiveLogo(
                    data,
                    maxWidth: 45,
                    maxHeight: 35,
                    alignment: pw.Alignment.center,
                    margin: const pw.EdgeInsets.only(bottom: 2),
                  ),
                  pw.Text(
                    data.settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (data.settings.slogan.isNotEmpty)
                    pw.Text(
                      data.settings.slogan,
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        fontStyle: pw.FontStyle.italic,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  pw.SizedBox(height: 1),
                  if (data.settings.address.isNotEmpty)
                    pw.Text(
                      data.settings.address,
                      style: const pw.TextStyle(fontSize: 5.5),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (data.settings.phone.isNotEmpty)
                    pw.Text(
                      'Tél: ${data.settings.phone}',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border.symmetric(
                  horizontal: pw.BorderSide(width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Text(
                (data.isProforma ? data.settings.titleReceiptProforma : data.settings.titleReceipt).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 6.0,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'N° ${data.saleId.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  dateFmtStr,
                  style: const pw.TextStyle(fontSize: 6),
                ),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(flex: 40, child: pw.Text('ARTICLE', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 10, child: pw.Text('QTÉ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 25, child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.SizedBox(height: 1),
            pw.Divider(thickness: 0.3),
            ...data.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 0.1),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 40,
                      child: pw.Text(
                        item.name,
                        style: const pw.TextStyle(fontSize: 5.8),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.Expanded(
                      flex: 10,
                      child: pw.Text(
                        DateFormatter.formatQuantity(item.qty),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 5.8),
                      ),
                    ),
                    pw.Expanded(
                      flex: 25,
                      child: pw.Text(
                        fmt(item.lineTotal),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 5.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _divider(),
            if (data.discountAmount > 0)
              _totalRow('REMISE', '- ${fmt(data.discountAmount)}'),
            
            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _totalRow('TOTAL H.T.', fmt(data.totalAmount - data.taxAmount)),
              _totalRow('${data.settings.taxName} (${data.settings.taxRate}%)', fmt(data.taxAmount)),
            ],
            _totalRow('TOTAL TTC', fmt(data.totalAmount), bold: true, fontSize: 7.0),
            if (data.shouldShowTax && !data.shouldBeDetailed)
              _totalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),

            if (!data.isCredit) ...[
              _totalRow('PAYÉ', fmt(data.amountPaid)),
              _totalRow('RENDU', fmt(data.change), bold: true),
            ] else ...[
              _totalRow('ACOMPTE VERSÉ', fmt(data.amountPaid)),
              _totalRow('RESTE À PAYER', fmt(data.totalAmount - data.amountPaid), bold: true, warn: true),
            ],
            _buildLoyaltySection(data),
            _divider(dashed: true),
            if (data.settings.showQrCode)
              pw.Center(
                child: pw.Container(
                  height: 20,
                  width: 20,
                  margin: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: "verify:sale:${data.saleId}",
                    drawText: false,
                  ),
                ),
              ),
            pw.Center(
              child: pw.Text(
                data.settings.receiptFooter,
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  static Future<pw.Document> _buildModern(
    ReceiptData data,
    PdfPageFormat format,
  ) async {
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
    final dateFmtStr = DateFormatter.formatDateTime(data.date);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginTicketLeft,
          data.settings.marginTicketTop,
          data.settings.marginTicketRight,
          data.settings.marginTicketBottom,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              "*" * 30,
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
            _buildAdaptiveLogo(
              data,
              maxWidth: 45,
              maxHeight: 35,
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(bottom: 2),
            ),
            pw.Text(
              data.settings.name.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              "*" * 30,
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'TICKET DE CAISSE',
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),

            _infoRow('Date:', dateFmtStr),
            _infoRow('Caissier:', data.cashierName),

            _divider(dashed: false),

            ...data.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 0.1),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.name,
                        style: const pw.TextStyle(fontSize: 5.8),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.Text(
                      fmt(item.lineTotal),
                      style: pw.TextStyle(
                        fontSize: 5.8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _divider(dashed: true),
            if (data.discountAmount > 0)
              _totalRow('Remise', '- ${fmt(data.discountAmount)}'),
            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _totalRow('TOTAL H.T.', fmt(data.totalAmount - data.taxAmount)),
              _totalRow('${data.settings.taxName} (${data.settings.taxRate}%)', fmt(data.taxAmount)),
            ],
            _totalRow('TOTAL TTC', fmt(data.totalAmount), bold: true, fontSize: 6.8),
            if (data.shouldShowTax && !data.shouldBeDetailed)
              _totalRow('Dont ${data.settings.taxName} (${data.settings.taxRate}%)', fmt(data.taxAmount)),
            _totalRow('Mode Reglement', data.isCredit ? 'CRÉDIT' : (data.paymentMethod ?? 'Espèces')),
            if (!data.isCredit) ...[
              _totalRow('Montant Reçu', fmt(data.amountPaid)),
              _totalRow('Reliquat', fmt(data.change), bold: true),
            ] else ...[
              _totalRow('Acompte Versé', fmt(data.amountPaid)),
              _totalRow('Reste à payer', fmt(data.totalAmount - data.amountPaid), bold: true, warn: true),
            ],
            _buildLoyaltySection(data),
            _divider(dashed: true),

            pw.SizedBox(height: 2),
            pw.Text(
              'MERCI DE VOTRE VISITE !',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            if (data.settings.showQrCode)
              pw.Center(
                child: pw.Container(
                  height: 20,
                  width: 20,
                  margin: const pw.EdgeInsets.only(top: 2),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: "verify:sale:${data.saleId}",
                    drawText: false,
                  ),
                ),
              ),

            pw.SizedBox(height: 2),
            pw.Text(
              data.settings.address,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 5.5,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              'Tél: ${data.settings.phone}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 5.5,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  static Future<pw.Document> _buildMinimal(
    ReceiptData data,
    PdfPageFormat format,
  ) async {
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
    final dateFmtStr = DateFormatter.formatDate(data.date);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginTicketLeft,
          data.settings.marginTicketTop,
          data.settings.marginTicketRight,
          data.settings.marginTicketBottom,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'REÇU DE CAISSE',
              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              "*" * 15,
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
            _buildAdaptiveLogo(
              data,
              maxWidth: 45,
              maxHeight: 35,
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(bottom: 2),
            ),
            pw.Text(
              data.settings.name.toUpperCase(),
              style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              data.settings.address,
              style: const pw.TextStyle(fontSize: 5.5),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              data.settings.phone,
              style: const pw.TextStyle(fontSize: 5.5),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              "*" * 15,
              style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 1),
            _infoRow('Date:', dateFmtStr),
            _infoRow('Caissier:', data.cashierName),

            pw.SizedBox(height: 2),
            pw.Text(
              '=' * 30,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),

            ...data.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 0.2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '#${item.name}',
                        style: const pw.TextStyle(fontSize: 5.5),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.Text(
                      fmt(item.lineTotal),
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.Text(
              '-' * 30,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),

            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _totalRow('Total H.T.', fmt(data.totalAmount - data.taxAmount)),
              _totalRow('${data.settings.taxName} (${data.settings.taxRate}%)', fmt(data.taxAmount)),
            ],
            _totalRow('Total TTC', fmt(data.totalAmount), bold: true, fontSize: 6.5),
            if (data.shouldShowTax && !data.shouldBeDetailed)
              _totalRow('Dont ${data.settings.taxName}', fmt(data.taxAmount)),

            pw.Text(
              '-' * 30,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),

            _totalRow(
              '${data.paymentMethod ?? "PAIEMENT"}:',
              fmt(data.totalAmount),
            ),
            if (data.discountAmount > 0)
               _totalRow('Remise:', '- ${fmt(data.discountAmount)}', warn: true),
            if (!data.isCredit) ...[
               _totalRow('Versé:', fmt(data.amountPaid)),
               _totalRow('Rendu:', fmt(data.change), bold: true),
            ] else ...[
               _totalRow('Acompte:', fmt(data.amountPaid)),
               _totalRow('Reste à payer:', fmt(data.totalAmount - data.amountPaid), bold: true, warn: true),
            ],
            pw.Text(
              '#Vente ${data.saleId.substring(0, 8).toUpperCase()}',
              style: const pw.TextStyle(fontSize: 5),
            ),

            pw.SizedBox(height: 1),
            pw.Text(
              'MERCI !',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),

            if (data.settings.showQrCode)
              pw.Center(
                child: pw.Container(
                  height: 20,
                  width: 20,
                  margin: const pw.EdgeInsets.only(top: 2),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: "verify:sale:${data.saleId}",
                    drawText: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return doc;
  }

  static Future<pw.Document> _buildElite(
    ReceiptData data,
    PdfPageFormat format,
  ) async {
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
    final dateFmtStr = DateFormatter.formatDateTime(data.date);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginTicketLeft,
          data.settings.marginTicketTop,
          data.settings.marginTicketRight,
          data.settings.marginTicketBottom,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // LOGO
            _buildAdaptiveLogo(
              data,
              maxWidth: 50,
              maxHeight: 35,
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(bottom: 4),
            ),
            
            // TITRE MAGASIN (AMAZON STYLE)
            pw.Text(
              data.settings.name.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (data.settings.address.isNotEmpty)
               pw.Text(
                 data.settings.address,
                 style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                 textAlign: pw.TextAlign.center,
               ),
            
            pw.SizedBox(height: 4),
            
            // CODE BARRE 1D POUR SCAN RETOUR
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: data.saleId.substring(0, 8).toUpperCase(),
                width: 130,
                height: 35,
                drawText: true,
                textStyle: pw.TextStyle(fontSize: 8, letterSpacing: 3, font: font),
              ),
            ),
            
            pw.SizedBox(height: 4),
            
            // INFOS COMMANDE
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border.symmetric(
                  horizontal: pw.BorderSide(width: 1, color: PdfColors.black),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Commande effectuée le:', style: const pw.TextStyle(fontSize: 5)),
                      pw.Text(dateFmtStr, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Caissier:', style: const pw.TextStyle(fontSize: 5)),
                      pw.Text(data.cashierName.toUpperCase(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 4),
            
            // ITEMS
            pw.Text('RÉCAPITULATIF DE COMMANDE', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            
            ...data.items.map((item) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${DateFormatter.formatQuantity(item.qty)}x', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.name.toUpperCase(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        pw.Text('PU: ${fmt(item.unitPrice)}', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Text(fmt(item.lineTotal), style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                ]
              )
            )),
            
            pw.SizedBox(height: 2),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.SizedBox(height: 2),
            
            // TOTALS SECTION
            if (data.shouldShowTax && data.shouldBeDetailed) ...[
              _totalRow('Total H.T.:', fmt(data.totalAmount - data.taxAmount)),
              _totalRow('${data.settings.taxName}:', fmt(data.taxAmount)),
            ],
            if (data.discountAmount > 0)
              _totalRow('Remise appliquée:', '- ${fmt(data.discountAmount)}', warn: true),
            
            pw.SizedBox(height: 1),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL TTC:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(fmt(data.totalAmount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]
            ),
            
            pw.SizedBox(height: 2),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.SizedBox(height: 2),
            
            // PAYMENT INFO
            if (!data.isCredit) ...[
              _totalRow('Payé par ${data.paymentMethod ?? "ESPÈCES"}:', fmt(data.totalAmount)),
              _totalRow('Espèces reçues:', fmt(data.amountPaid)),
              _totalRow('Monnaie rendue:', fmt(data.change), bold: true),
            ] else ...[
              _totalRow('Acompte versé:', fmt(data.amountPaid)),
              _totalRow('Reste à payer (Dette):', fmt(data.totalAmount - data.amountPaid), bold: true, warn: true),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('VENTE À CRÉDIT - NON SOLDÉ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _error), textAlign: pw.TextAlign.center),
              ),
            ],
            
            _buildLoyaltySection(data),
            
            pw.SizedBox(height: 4),
            
            // FOOTER & QR
            if (data.settings.showQrCode)
              pw.Center(
                child: pw.Container(
                  height: 25,
                  width: 25,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: "verify:sale:${data.saleId}",
                    drawText: false,
                  ),
                ),
              ),
            
            pw.SizedBox(height: 3),
            pw.Text(
              data.settings.receiptFooter,
              style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              'Conservez ce reçu pour tout retour ou échange.',
              style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  static Future<pw.Document> _buildPrestige(
    ReceiptData data,
    PdfPageFormat format,
  ) async {
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
    final dateFmtStr = DateFormatter.formatDateTime(data.date);

    const thickBorder = pw.BorderSide(width: 1.5, color: PdfColors.black);
    const thinBorder = pw.BorderSide(width: 0.5, color: PdfColors.black);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.fromLTRB(
          data.settings.marginTicketLeft,
          data.settings.marginTicketTop,
          data.settings.marginTicketRight,
          data.settings.marginTicketBottom,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // HEADER - PROFESSIONAL INVOICE STYLE
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data.settings.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(data.settings.address, style: const pw.TextStyle(fontSize: 6)),
                      pw.Text('Tél: ${data.settings.phone}', style: const pw.TextStyle(fontSize: 6)),
                    ],
                  ),
                ),
                _buildAdaptiveLogo(
                  data,
                  maxWidth: 35,
                  maxHeight: 35,
                  alignment: pw.Alignment.centerRight,
                ),
              ],
            ),
            
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              decoration: const pw.BoxDecoration(border: pw.Border(top: thickBorder, bottom: thickBorder)),
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                'TICKET DE CAISSE OFFICIEL',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
                textAlign: pw.TextAlign.center,
              ),
            ),
            
            pw.SizedBox(height: 4),
            
            // ORDER DETAILS GRID
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date de commande:', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
                        pw.Text(dateFmtStr, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('N° Commande:', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
                        pw.Text(data.saleId.toUpperCase(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                      ]
                    )
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Servi par:', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
                        pw.Text(data.cashierName.toUpperCase(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        if (data.clientName != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Client:', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
                          pw.Text(data.clientName!.toUpperCase(), style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        ]
                      ]
                    )
                  )
                ]
              )
            ),
            
            pw.SizedBox(height: 4),
            
            // BARCODE - 1D (AMAZON STYLE)
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: data.saleId.substring(0, 8).toUpperCase(),
                width: 130,
                height: 35,
                drawText: false,
              ),
            ),
            
            pw.SizedBox(height: 5),
            
            // ITEM TABLE (MODERN CLEAR BORDERS)
            pw.Table(
              border: const pw.TableBorder(
                top: thinBorder,
                bottom: thinBorder,
                horizontalInside: pw.BorderSide(width: 0.2, color: PdfColors.grey300),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                      child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                      child: pw.Text('QTÉ', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                      child: pw.Text('MONTANT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...data.items.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                        child: pw.Text(item.name.toUpperCase(), style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold), maxLines: 2),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                        child: pw.Text(DateFormatter.formatQuantity(item.qty), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                        child: pw.Text(fmt(item.lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 3),
            
            // PAYMENT & TOTAL SUMMARY
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LEFT: QR Code and Payment Method
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Moyen de paiement:', style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700)),
                        pw.Text(data.paymentMethod ?? 'ESPÈCES', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        if (data.settings.showQrCode)
                          pw.Container(
                            height: 25,
                            width: 25,
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: "verify:sale:${data.saleId}",
                              drawText: false,
                            ),
                          ),
                      ]
                    )
                  ),
                  
                  // RIGHT: Totals
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      children: [
                        if (data.shouldShowTax && data.shouldBeDetailed) ...[
                          _totalRow('Sous-total:', fmt(data.totalAmount - data.taxAmount)),
                          _totalRow('Taxes:', fmt(data.taxAmount)),
                        ],
                        if (data.discountAmount > 0)
                          _totalRow('Remises:', '- ${fmt(data.discountAmount)}', warn: true),
                        
                        pw.SizedBox(height: 2),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.black,
                            borderRadius: pw.BorderRadius.circular(1),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TOTAL TTC', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                              pw.Text(fmt(data.totalAmount), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            ]
                          )
                        ),
                        pw.SizedBox(height: 2),
                        
                        if (!data.isCredit) ...[
                          _totalRow('Montant reçu:', fmt(data.amountPaid)),
                          _totalRow('Rendu:', fmt(data.change), bold: true),
                        ] else ...[
                          _totalRow('Acompte versé:', fmt(data.amountPaid)),
                          _totalRow('Reste à payer:', fmt(data.totalAmount - data.amountPaid), bold: true, warn: true),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text('VENTE À CRÉDIT', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: _error), textAlign: pw.TextAlign.right),
                          ),
                        ],
                      ]
                    )
                  ),
                ]
              )
            ),
            
            pw.SizedBox(height: 4),
            
            _buildLoyaltySection(data),
            
            pw.SizedBox(height: 2),
            pw.Divider(thickness: thickBorder.width, color: PdfColors.black),
            pw.SizedBox(height: 2),
            
            pw.Text(
              data.settings.receiptFooter,
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Merci de faire vos achats chez ${data.settings.name}',
              style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
    return doc;
  }
  static pw.Widget _buildAdaptiveLogo(
    ReceiptData data, {
    double maxWidth = 45,
    double maxHeight = 35,
    pw.Alignment alignment = pw.Alignment.center,
    pw.BoxDecoration? decoration,
    pw.EdgeInsets? padding,
    pw.EdgeInsets? margin,
    pw.Widget? fallback,
  }) {
    final logoImage = PdfResourceService.instance.getLogo(data.settings.logoPath);
    if (logoImage != null) {
      return pw.Center(
        child: pw.Container(
          constraints: pw.BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          decoration: decoration,
          padding: padding,
          margin: margin,
          child: pw.Image(
            logoImage,
            fit: pw.BoxFit.contain,
            alignment: alignment,
          ),
        ),
      );
    }
    return fallback ?? pw.SizedBox();
  }

  static pw.Widget _divider({bool dashed = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
    child: dashed
        ? pw.Container(
            height: 1,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 0.4, style: pw.BorderStyle.dashed),
              ),
            ),
          )
        : pw.Divider(thickness: 0.4),
  );

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    bool warn = false,
    double fontSize = 5.8,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.08, horizontal: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 3),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: warn ? _error : null,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 5.5)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 5.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
