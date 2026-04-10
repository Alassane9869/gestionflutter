import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';
import 'dart:io';

/// Represents a single line in the shopping list, with a user-editable quantity.
class ShoppingListEntry {
  final Product product;
  final double orderQty;

  const ShoppingListEntry({required this.product, required this.orderQty});

  ShoppingListEntry copyWith({double? orderQty}) =>
      ShoppingListEntry(product: product, orderQty: orderQty ?? this.orderQty);
}

class InventoryReportService {
  static Future<void> generateShoppingListPdf({
    required List<ShoppingListEntry> entries,
    required ShopSettings settings,
  }) async {
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final now = DateTime.now();
    final dateStr = DateFormatter.formatDateTime(now);

    final darkBg = PdfColor.fromHex('#1E2235');
    final accentRed = PdfColor.fromHex('#D62828');
    final border = PdfColor.fromHex('#E2E8F0');
    final bgGrey = PdfColor.fromHex('#F8FAFC');
    final textMuted = PdfColor.fromHex('#64748B');

    // --- Logo ---
    pw.ImageProvider? logoImage;
    if (settings.logoPath != null && settings.logoPath!.isNotEmpty) {
      try {
        final logoFile = File(settings.logoPath!);
        if (logoFile.existsSync()) {
          logoImage = pw.MemoryImage(logoFile.readAsBytesSync());
        }
      } catch (_) {}
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
        header: (ctx) => _buildHeader(
          shopName: settings.name,
          address: settings.address,
          phone: settings.phone,
          dateStr: dateStr,
          logoImage: logoImage,
          darkBg: darkBg,
          accentRed: accentRed,
        ),
        footer: (ctx) => _buildFooter(ctx, settings.name, textMuted),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Text(
            "Recommandations de réapprovisionnement — ${entries.length} article(s) critique(s)",
            style: pw.TextStyle(fontSize: 9, color: textMuted, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 10),
          _buildTable(entries, darkBg, accentRed, bgGrey, border),
          pw.SizedBox(height: 16),
          _buildSummary(entries, darkBg, bgGrey, border, textMuted),
        ],
      ),
    );

    await PrintingHelper.printWithFallback(
      doc: pdf,
      targetPrinterName: settings.reportPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: 'Liste_Courses_Stock_${now.millisecondsSinceEpoch}',
    );
  }

  static pw.Widget _buildHeader({
    required String shopName,
    required String address,
    required String phone,
    required String dateStr,
    required pw.ImageProvider? logoImage,
    required PdfColor darkBg,
    required PdfColor accentRed,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(color: darkBg, borderRadius: pw.BorderRadius.circular(8)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 36,
                  height: 36,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shopName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  if (address.isNotEmpty)
                    pw.Text(address, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  if (phone.isNotEmpty)
                    pw.Text(phone, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: accentRed,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text("LISTE DE COURSES", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 4),
              pw.Text("Édité le $dateStr", style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx, String shopName, PdfColor textMuted) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "$shopName — Document de gestion interne",
            style: pw.TextStyle(fontSize: 7, color: textMuted),
          ),
          pw.Text(
            "Page ${ctx.pageNumber} / ${ctx.pagesCount}",
            style: pw.TextStyle(fontSize: 7, color: textMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(
    List<ShoppingListEntry> entries,
    PdfColor darkBg,
    PdfColor accentRed,
    PdfColor bgGrey,
    PdfColor border,
  ) {
    return pw.Table(
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: border),
        horizontalInside: pw.BorderSide(color: border, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FixedColumnWidth(30),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: darkBg),
          children: [
            _th("ARTICLE"),
            _th("RÉFÉRENCE"),
            _th("STOCK", align: pw.Alignment.centerRight),
            _th("SEUIL", align: pw.Alignment.centerRight),
            _th("À COMMANDER", align: pw.Alignment.centerRight),
            _th("✓", align: pw.Alignment.center),
          ],
        ),
        // Rows
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          final isOut = e.product.isOutOfStock;
          final rowColor = i % 2 == 0 ? bgGrey : PdfColors.white;
          final statusColor = isOut ? accentRed : PdfColor.fromHex('#D97706');

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowColor),
            children: [
              _td(e.product.name, bold: true),
              _td(e.product.reference ?? '-', color: PdfColor.fromHex('#64748B')),
              _tdColored(DateFormatter.formatQuantity(e.product.quantity), statusColor),
              _td(DateFormatter.formatQuantity(e.product.alertThreshold), align: pw.Alignment.centerRight),
              _tdColored(
                e.orderQty > 0 ? "+ ${DateFormatter.formatQuantity(e.orderQty)}" : "-",
                e.orderQty > 0 ? PdfColor.fromHex('#16A34A') : PdfColors.grey,
                bold: true,
              ),
              // Checkbox for manual tick
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Container(
                  width: 14, height: 14,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSummary(
    List<ShoppingListEntry> entries,
    PdfColor darkBg,
    PdfColor bgGrey,
    PdfColor border,
    PdfColor textMuted,
  ) {
    final totalItems = entries.length;
    final outOfStock = entries.where((e) => e.product.isOutOfStock).length;
    final totalToOrder = entries.fold(0.0, (sum, e) => sum + e.orderQty);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgGrey,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _kpi("Articles critiques", "$totalItems", textMuted),
          _kpi("En rupture totale", "$outOfStock", PdfColor.fromHex('#D62828')),
          _kpi("Total à commander", DateFormatter.formatQuantity(totalToOrder), PdfColor.fromHex('#16A34A')),
        ],
      ),
    );
  }

  static pw.Widget _kpi(String label, String value, PdfColor valueColor) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: valueColor)),
        pw.SizedBox(height: 3),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _th(String text, {pw.Alignment? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Align(
        alignment: align ?? pw.Alignment.centerLeft,
        child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ),
    );
  }

  static pw.Widget _td(String text, {pw.Alignment? align, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(
        alignment: align ?? pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColor.fromHex('#1E2235'),
          ),
        ),
      ),
    );
  }

  static pw.Widget _tdColored(String text, PdfColor color, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
  }
}
