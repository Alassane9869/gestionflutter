import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/features/reports/domain/models/report_models.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';
import 'package:flutter/material.dart';

class PdfReportService {
  static final _primaryColor = PdfColor.fromHex('#2563EB');
  static final _successColor = PdfColor.fromHex('#16A34A');
  static final _warningColor = PdfColor.fromHex('#D97706');
  static final _dangerColor = PdfColor.fromHex('#DC2626');
  static final _bgGrey = PdfColor.fromHex('#F8FAFC');
  static final _textMuted = PdfColor.fromHex('#64748B');
  static final _border = PdfColor.fromHex('#E2E8F0');
  static final _darkBg = PdfColor.fromHex('#0F172A');

  static Future<void> generateAndSaveReport({
    required DateTimeRange range,
    required ReportKPIs kpis,
    required List<TopProduct> topProducts,
    required List<UserSaleSummary> userSales,
    required String username,
    String shopName = 'Mon Commerce',
    String? shopAddress,
    String? shopPhone,
    String? targetPrinter,
    String currencySymbol = 'F',
    String locale = 'fr-FR',
    bool removeDecimals = true,
  }) async {
    final pdf = await _createPdf(
      range: range,
      kpis: kpis,
      topProducts: topProducts,
      userSales: userSales,
      username: username,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      currencySymbol: currencySymbol,
      locale: locale,
      removeDecimals: removeDecimals,
    );

    try {
      await PrintingHelper.printWithFallback(
        doc: pdf,
        targetPrinterName: targetPrinter,
        directPrint: true,
        jobName: 'Rapport_Financier_${DateFormatter.formatDate(DateTime.now()).replaceAll('/', '')}.pdf',
      );
    } catch (e) {
      debugPrint("❌ PdfReportService: HW Printer Failure: $e");
      // Silently fail as report can be regenerated anytime
    }
  }

  static Future<String> generateReportFile({
    required DateTimeRange range,
    required ReportKPIs kpis,
    required List<TopProduct> topProducts,
    required List<UserSaleSummary> userSales,
    required String username,
    String shopName = 'Mon Commerce',
    String? shopAddress,
    String? shopPhone,
    String currencySymbol = 'F',
    String locale = 'fr-FR',
    bool removeDecimals = true,
  }) async {
    final pdf = await _createPdf(
      range: range,
      kpis: kpis,
      topProducts: topProducts,
      userSales: userSales,
      username: username,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      currencySymbol: currencySymbol,
      locale: locale,
      removeDecimals: removeDecimals,
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('-', '').split('.').first;
    final file = File('${dir.path}/Rapport_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<pw.Document> _createPdf({
    required DateTimeRange range,
    required ReportKPIs kpis,
    required List<TopProduct> topProducts,
    required List<UserSaleSummary> userSales,
    required String username,
    String shopName = 'Mon Commerce',
    String? shopAddress,
    String? shopPhone,
    required String currencySymbol,
    required String locale,
    required bool removeDecimals,
  }) async {
    final pdf = pw.Document();

    // final numFmt = NumberFormat('#,##0', locale); // Retired in favor of DateFormatter

    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;

    pw.ThemeData theme = pw.ThemeData.withFont(base: font, bold: fontBold, italic: fontItalic);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        theme: theme,
        header: (ctx) => _buildHeader(ctx, shopName, shopAddress, shopPhone, username, range),
        footer: (ctx) => _buildFooter(ctx, shopName),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          // ── SECTION KPIs ──
          _sectionTitle('TABLEAU DE BORD FINANCIER'),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _kpiBox('Chiffre d\'Affaires', DateFormatter.formatCurrency(kpis.totalRevenue, currencySymbol, removeDecimals: removeDecimals), _primaryColor, 'Revenus bruts'),
              pw.SizedBox(width: 8),
              _kpiBox('Bénéfice Brut', DateFormatter.formatCurrency(kpis.totalProfit, currencySymbol, removeDecimals: removeDecimals), _successColor, 'Marge produits'),
              pw.SizedBox(width: 8),
              _kpiBox('Dépenses', DateFormatter.formatCurrency(kpis.totalExpenses, currencySymbol, removeDecimals: removeDecimals), _warningColor, 'Charges totales'),
              pw.SizedBox(width: 8),
              _kpiBox('Bénéfice NET', DateFormatter.formatCurrency(kpis.netProfit, currencySymbol, removeDecimals: removeDecimals), kpis.netProfit >= 0 ? _successColor : _dangerColor, 'Résultat final'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _kpiBox('Nb Ventes', DateFormatter.formatNumber(kpis.salesCount), _primaryColor, 'Transactions'),
              _kpiBox('Marge %', '${DateFormatter.formatNumberValue(kpis.marginPercentage, decimalDigits: 1)}%', _successColor, 'Rentabilité'),
              _kpiBox('Panier Moyen', kpis.salesCount > 0 ? DateFormatter.formatCurrency(kpis.totalRevenue / kpis.salesCount, currencySymbol, removeDecimals: removeDecimals) : '0 $currencySymbol', _textMuted, 'Valeur moy / vente'),
              _kpiBox('Taux Charge', kpis.totalRevenue > 0 ? '${DateFormatter.formatNumberValue((kpis.totalExpenses / kpis.totalRevenue * 100), decimalDigits: 1)}%' : '0%', _warningColor, 'Dépenses / CA'),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Divider(color: _border),
          pw.SizedBox(height: 20),

          // ── SECTION PERFORMANCE VENDEURS ──
          _sectionTitle('PERFORMANCE PAR VENDEUR'),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder(bottom: pw.BorderSide(color: _border), horizontalInside: pw.BorderSide(color: _border, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _darkBg),
                children: [
                  _th('VENDEUR / UTILISATEUR'),
                  _th('NB VENTES', align: pw.Alignment.centerRight),
                  _th('CHIFFRE D\'AFFAIRES', align: pw.Alignment.centerRight),
                ],
              ),
              ...userSales.map((u) => pw.TableRow(
                children: [
                  _td(u.username, bold: true),
                  _td(DateFormatter.formatNumber(u.salesCount), align: pw.Alignment.centerRight),
                  _td(DateFormatter.formatCurrency(u.totalRevenue, currencySymbol, removeDecimals: removeDecimals), align: pw.Alignment.centerRight, bold: true, color: _primaryColor),
                ],
              )),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Divider(color: _border),
          pw.SizedBox(height: 20),

          // ── SECTION TOP PRODUITS ──
          _sectionTitle('PALMARÈS DES MEILLEURES VENTES'),
          pw.SizedBox(height: 10),
          topProducts.isEmpty
              ? pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(color: _bgGrey, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text('Aucun produit vendu sur cette période.', style: pw.TextStyle(color: _textMuted)),
                )
              : pw.Table(
                  border: pw.TableBorder(
                    bottom: pw.BorderSide(color: _border),
                    horizontalInside: pw.BorderSide(color: _border, width: 0.5),
                  ),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: _darkBg),
                      children: [
                        _th('#', align: pw.Alignment.center),
                        _th('NOM DU PRODUIT'),
                        _th('QTÉ VENDUE', align: pw.Alignment.centerRight),
                        _th('CHIFFRE D\'AFFAIRES', align: pw.Alignment.centerRight),
                      ],
                    ),
                    // Data rows
                    ...List<pw.TableRow>.generate(topProducts.length > 15 ? 15 : topProducts.length, (i) {
                      final p = topProducts[i];
                      final isEven = i % 2 == 0;
                      final medal = i == 0 ? '1er' : i == 1 ? '2eme' : i == 2 ? '3eme' : '#${i + 1}';
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: isEven ? _bgGrey : PdfColors.white),
                        children: [
                          _td(medal, align: pw.Alignment.center, bold: i < 3, color: i < 3 ? _warningColor : null),
                          _td(p.name, bold: i == 0),
                          _td('${DateFormatter.formatQuantity(p.totalQuantity.toDouble())} u', align: pw.Alignment.centerRight),
                          _td(DateFormatter.formatCurrency(p.totalRevenue, currencySymbol, removeDecimals: removeDecimals), align: pw.Alignment.centerRight, bold: true, color: _successColor),
                        ],
                      );
                    }),
                  ],
                ),

          pw.SizedBox(height: 24),
          pw.Divider(color: _border),
          pw.SizedBox(height: 20),

          // ── SECTION ANALYSE ──
          _sectionTitle('ANALYSE ET RECOMMANDATIONS'),
          pw.SizedBox(height: 10),
          _analysisBlock(kpis, currencySymbol, removeDecimals),
        ],
      ),
    );
    return pdf;
  }

  static pw.Widget _buildHeader(pw.Context _, String shopName, String? shopAddress, String? shopPhone, String username, DateTimeRange range) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _darkBg,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(shopName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text('RAPPORT FINANCIER DÉTAILLÉ', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
              pw.SizedBox(height: 3),
              if (shopAddress != null && shopAddress.isNotEmpty)
                pw.Text(shopAddress, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
              if (shopPhone != null && shopPhone.isNotEmpty)
                pw.Text(shopPhone, style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Du ${DateFormatter.formatLongDate(range.start)} au ${DateFormatter.formatLongDate(range.end)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Généré par : $username', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8'))),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx, String shopName) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$shopName © ${DateTime.now().year} — Document confidentiel', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(width: 4, height: 16, color: _primaryColor),
        pw.SizedBox(width: 8),
        pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _darkBg)),
      ],
    );
  }

  static pw.Widget _kpiBox(String label, String value, PdfColor color, String subtitle) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(8),
          color: PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _textMuted, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 3),
            pw.Text(subtitle, style: pw.TextStyle(fontSize: 7, color: _textMuted)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _th(String text, {pw.Alignment? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Align(
        alignment: align ?? pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  static pw.Widget _td(String text, {pw.Alignment? align, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: align ?? pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? _darkBg,
          ),
        ),
      ),
    );
  }

  static pw.Widget _analysisBlock(ReportKPIs kpis, String currencySymbol, bool removeDecimals) {
    final points = <String>[];

    if (kpis.netProfit < 0) {
      points.add('Attention - Résultat négatif : les dépenses (${DateFormatter.formatCurrency(kpis.totalExpenses, currencySymbol, removeDecimals: removeDecimals)}) dépassent la marge brute. Réduire les charges fixes.');
    } else {
      points.add('Succès - Rentabilité positive. Bénéfice net de ${DateFormatter.formatCurrency(kpis.netProfit, currencySymbol, removeDecimals: removeDecimals)} sur la période.');
    }

    if (kpis.marginPercentage < 20) {
      points.add('Analyse - Marge commerciale de ${DateFormatter.formatNumberValue(kpis.marginPercentage, decimalDigits: 1)}% — En dessous du seuil recommandé de 20%. Réévaluer la politique de prix d\'achat.');
    } else if (kpis.marginPercentage > 40) {
      points.add('Analyse - Excellente marge commerciale : ${DateFormatter.formatNumberValue(kpis.marginPercentage, decimalDigits: 1)}%. La politique tarifaire est bien maîtrisée.');
    }

    if (kpis.salesCount == 0) {
      points.add('Info - Aucune vente enregistrée sur cette période. Vérifier les données ou la plage de dates.');
    } else if (kpis.salesCount < 10) {
      points.add('Volume - Faible volume de ventes (${DateFormatter.formatNumber(kpis.salesCount)} transactions). Envisager des actions commerciales pour augmenter le trafic.');
    } else {
      points.add('Volume - Volume de ventes satisfaisant : ${DateFormatter.formatNumber(kpis.salesCount)} transactions enregistrées.');
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _bgGrey,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: points
            .map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(p, style: pw.TextStyle(fontSize: 9.5, color: _darkBg)),
                ))
            .toList(),
      ),
    );
  }
}
