import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/features/reports/domain/models/report_models.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';

class ReceiptReportService {
  static Future<void> generateZReport({
    required DateTimeRange range,
    required ReportKPIs kpis,
    required List<TopProduct> topProducts,
    required String username,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? targetPrinter,
    String currencySymbol = 'F',
    String locale = 'fr-FR',
    bool removeDecimals = true,
  }) async {
    final pdf = pw.Document();

    // Load fonts for Unicode support
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final fontItalic = PdfResourceService.instance.italic;

    // Format Ticket 80mm
    const double ticketWidth = 80 * PdfPageFormat.mm;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(ticketWidth, double.infinity).copyWith(
          marginLeft: 8 * PdfPageFormat.mm,
          marginRight: 5 * PdfPageFormat.mm,
          marginTop: 5 * PdfPageFormat.mm,
          marginBottom: 5 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // EN-TÊTE DE LA BOUTIQUE
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(shopName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    if (shopAddress != null && shopAddress.isNotEmpty)
                      pw.Text(shopAddress, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                    if (shopPhone != null && shopPhone.isNotEmpty)
                      pw.Text(shopPhone, style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 8),
                    pw.Text("RAPPORT Z CAISSE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 4),
                    pw.Text("DU : ${DateFormatter.formatDateTime(range.start)}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("AU : ${DateFormatter.formatDateTime(range.end)}", style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 8),
              pw.Text("SYNTHÈSE FINANCIÈRE", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _buildRow("Nbr Transactions :", DateFormatter.formatNumber(kpis.salesCount)),
              _buildRow("Chiffre d'Affaires :", DateFormatter.formatCurrency(kpis.totalRevenue, currencySymbol, removeDecimals: removeDecimals), isBold: true),
              pw.SizedBox(height: 2),
              _buildRow("Coût Marchandises :", "- ${DateFormatter.formatCurrency(kpis.totalRevenue - kpis.totalProfit, currencySymbol, removeDecimals: removeDecimals)}"),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.solid),
              pw.SizedBox(height: 2),
              _buildRow("Marge Brute :", DateFormatter.formatCurrency(kpis.totalProfit, currencySymbol, removeDecimals: removeDecimals), isBold: true),
              _buildRow("Dépenses :", "- ${DateFormatter.formatCurrency(kpis.totalExpenses, currencySymbol, removeDecimals: removeDecimals)}"),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                color: PdfColors.grey200,
                child: _buildRow("RÉSULTAT NET :", DateFormatter.formatCurrency(kpis.netProfit, currencySymbol, removeDecimals: removeDecimals), isBold: true, isLarge: true),
              ),
              pw.SizedBox(height: 4),
              _buildRow("Rentabilité (Marge) :", "${DateFormatter.formatNumberValue(kpis.netMarginPercentage, decimalDigits: 1)} %"),
              
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
              pw.Text("TOP 5 PRODUITS VENDUS", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              ...topProducts.take(5).toList().asMap().entries.map((entry) {
                final int index = entry.key + 1;
                final TopProduct p = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Ligne 1 : Nom complet (sans être écrasé)
                      pw.Text("$index. ${p.name}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      // Ligne 2 : Quantité et Montant Total
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 10),
                            child: pw.Text("Qté : ${DateFormatter.formatQuantity(p.totalQuantity.toDouble())}", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ),
                          pw.Text(DateFormatter.formatCurrency(p.totalRevenue, currencySymbol, removeDecimals: removeDecimals), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text("Généré par : ${username.toUpperCase()}", style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    pw.Text("Edité le : ${DateFormatter.formatDateTime(DateTime.now())}", style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 6),
                    pw.Text("--- FIN DE RAPPORT Z ---", style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await PrintingHelper.printWithFallback(
      doc: pdf,
      targetPrinterName: targetPrinter, 
      directPrint: true, // Impression directe (sans dialog) pour le ticket Z
      jobName: 'Rapport_Z_${DateFormatter.formatDate(DateTime.now()).replaceAll('/', '')}',
    );
  }

  static pw.Row _buildRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: isLarge ? 10 : 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: isLarge ? 11 : 9, fontWeight: isBold || isLarge ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}
