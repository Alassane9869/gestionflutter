import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:danaya_plus/features/reports/domain/models/report_models.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class ExcelExportService {
  static CellValue _buildCellValue(dynamic value) {
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is num) return DoubleCellValue(value.toDouble());
    return TextCellValue(value.toString());
  }

  // ── STYLES ──
  static CellStyle _headerStyle({String? bgHex, String? fgHex, bool bold = true, int fontSize = 10, HorizontalAlign align = HorizontalAlign.Left}) {
    return CellStyle(
      bold: bold,
      horizontalAlign: align,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: fontSize,
      backgroundColorHex: bgHex != null ? ExcelColor.fromHexString(bgHex) : ExcelColor.white,
      fontColorHex: fgHex != null ? ExcelColor.fromHexString(fgHex) : ExcelColor.black,
    );
  }

  static CellStyle _dataStyle({String? bgHex, String? fgHex, bool bold = false, HorizontalAlign align = HorizontalAlign.Left, NumFormat? numberFormat}) {
    return CellStyle(
      bold: bold,
      horizontalAlign: align,
      fontFamily: getFontFamily(FontFamily.Calibri),
      backgroundColorHex: bgHex != null ? ExcelColor.fromHexString(bgHex) : ExcelColor.white,
      fontColorHex: fgHex != null ? ExcelColor.fromHexString(fgHex) : ExcelColor.black,
      numberFormat: numberFormat ?? NumFormat.standard_0,
    );
  }

  static void _setColWidth(Sheet sheet, int col, double width) {
    sheet.setColumnWidth(col, width);
  }

  static void _writeHeader(Sheet sheet, int col, int row, String text, {String bgHex = 'FF1E3A5F', String fgHex = 'FFFFFFFF', HorizontalAlign align = HorizontalAlign.Center}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(text);
    cell.cellStyle = _headerStyle(bgHex: bgHex, fgHex: fgHex, align: align, fontSize: 11);
  }

  static Future<String> exportToExcel({
    required DateTimeRange range,
    required ReportKPIs kpis,
    required List<TopProduct> topProducts,
    required Database db,
    String? currency,
    bool openFile = true, // Nouveau paramètre
  }) async {
    final startStr = range.start.toIso8601String();
    final endStr = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59).toIso8601String();

    // 1. Fetch data on main isolate (cannot pass DB to other isolate)
    final List<Map<String, dynamic>> sales = await db.rawQuery('''
      SELECT s.date, s.id, COALESCE(c.name, 'Client Général') as client_name,
        u.username as seller_name,
        s.total_amount, s.amount_paid, s.payment_method,
        COALESCE(s.refunded_amount, 0) as refunded_amount,
        s.is_credit, COALESCE(s.discount_amount, 0) as discount_amount
      FROM sales s
      LEFT JOIN clients c ON s.client_id = c.id
      JOIN users u ON s.user_id = u.id
      WHERE s.date >= ? AND s.date <= ?
      ORDER BY s.date ASC
    ''', [startStr, endStr]);

    final List<Map<String, dynamic>> expenses = await db.rawQuery('''
      SELECT t.date, t.description, t.category, t.amount, a.name as account_name
      FROM financial_transactions t
      JOIN financial_accounts a ON t.account_id = a.id
      WHERE t.type = 'OUT' AND t.date >= ? AND t.date <= ?
      ORDER BY t.date ASC
    ''', [startStr, endStr]);

    // 2. PRE-FORMAT date strings on main isolate (locale is initialized here)
    // Isolates don't share locale data, so we format before passing.
    final formattedRangeStart = DateFormatter.formatDate(range.start);
    final formattedRangeEnd = DateFormatter.formatDate(range.end);
    final formattedNow = DateFormatter.formatDateTime(DateTime.now());

    // Pre-format sales dates
    final formattedSalesDates = <String>[];
    for (final s in sales) {
      final date = DateTime.parse(s['date'] as String);
      formattedSalesDates.add(DateFormatter.formatDateTime(date));
    }

    // Pre-format expense dates
    final formattedExpenseDates = <String>[];
    for (final e in expenses) {
      final date = DateTime.parse(e['date'] as String);
      formattedExpenseDates.add(DateFormatter.formatDate(date));
    }

    // 3. Offload heavy Excel generation to background isolate
    final excelCurrency = currency ?? 'FCFA';

    final bytes = await compute(_generateExcelBytes, {
      'range_start': range.start,
      'range_end': range.end,
      'formatted_range_start': formattedRangeStart,
      'formatted_range_end': formattedRangeEnd,
      'formatted_now': formattedNow,
      'formatted_sales_dates': formattedSalesDates,
      'formatted_expense_dates': formattedExpenseDates,
      'kpis': kpis,
      'topProducts': topProducts,
      'sales': sales,
      'expenses': expenses,
      'currency': excelCurrency,
    });

    // 4. Unique filename with timestamp (prevents PathAccessException if Excel is open)
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '').replaceAll('-', '').split('.').first;
    final String fileName = 'Rapport_Financier_$timestamp.xlsx';
    
    // If openFile is true (manual export), save to Downloads. 
    // If false (email/test), save to Temp to avoid locking issues in user folders.
    final Directory targetDir = openFile 
        ? (await getDownloadsDirectory() ?? await getTemporaryDirectory()) 
        : await getTemporaryDirectory();
        
    final String fullPath = '${targetDir.path}/$fileName';

    if (bytes != null) {
      await File(fullPath).writeAsBytes(bytes);
      if (openFile) {
        await OpenFilex.open(fullPath);
      }
    }
    return fullPath;
  }

  static List<int>? _generateExcelBytes(Map<String, dynamic> params) {
    final ReportKPIs kpis = params['kpis'];
    final List<TopProduct> topProducts = params['topProducts'];
    final List<Map<String, dynamic>> sales = params['sales'];
    final List<Map<String, dynamic>> expenses = params['expenses'];
    final String currency = params['currency'] ?? 'FCFA';

    // Pre-formatted strings from main isolate (locale-safe)
    final String fmtRangeStart = params['formatted_range_start'];
    final String fmtRangeEnd = params['formatted_range_end'];
    final String fmtNow = params['formatted_now'];
    final List<String> fmtSalesDates = List<String>.from(params['formatted_sales_dates']);
    final List<String> fmtExpenseDates = List<String>.from(params['formatted_expense_dates']);

    final excel = Excel.createExcel();


    // ═══════════════════════════════════════
    // FEUILLE 1 : TABLEAU DE BORD
    // ═══════════════════════════════════════
    final sheet1 = excel['Tableau de Bord'];
    excel.delete('Sheet1');

    // Titre principal
    sheet1.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
    final titleCell = sheet1.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('RAPPORT FINANCIER');
    titleCell.cellStyle = _headerStyle(bgHex: 'FF0F172A', fgHex: 'FFFFFFFF', fontSize: 16, align: HorizontalAlign.Center);
    sheet1.setRowHeight(0, 32);

    // Période
    sheet1.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('F2'));
    final periodCell = sheet1.cell(CellIndex.indexByString('A2'));
    periodCell.value = TextCellValue('Période : $fmtRangeStart au $fmtRangeEnd   |   Généré le : $fmtNow');
    periodCell.cellStyle = _headerStyle(bgHex: 'FF1E3A5F', fgHex: 'FFADD8E6', fontSize: 10, align: HorizontalAlign.Center);
    sheet1.setRowHeight(1, 22);

    // Espace
    sheet1.setRowHeight(2, 10);

    // Sous-titre KPIs
    sheet1.merge(CellIndex.indexByString('A4'), CellIndex.indexByString('F4'));
    final kpiTitle = sheet1.cell(CellIndex.indexByString('A4'));
    kpiTitle.value = TextCellValue('INDICATEURS CLÉS DE PERFORMANCE (KPI)');
    kpiTitle.cellStyle = _headerStyle(bgHex: 'FF2563EB', fgHex: 'FFFFFFFF', fontSize: 12, align: HorizontalAlign.Left);
    sheet1.setRowHeight(3, 24);

    // En-têtes KPI
    final kpiHeaders = ['INDICATEUR', 'VALEUR ($currency)', 'ÉVOLUTION', 'STATUT', 'COMMENTAIRE', ''];
    for (int i = 0; i < kpiHeaders.length; i++) {
      _writeHeader(sheet1, i, 4, kpiHeaders[i], bgHex: 'FF1E40AF', fgHex: 'FFFFFFFF');
    }
    sheet1.setRowHeight(4, 22);

    // Données KPI
    final kpiRows = [
      ['Chiffre d\'Affaires Brut', kpis.totalRevenue, '', 'OK: Bon', kpis.totalRevenue > 0 ? 'Revenus positifs sur la période' : 'Aucun revenu enregistré', ''],
      ['Bénéfice Brut (Marge Produits)', kpis.totalProfit, '', kpis.totalProfit >= 0 ? 'OK: Positif' : 'ERR: Négatif', 'Ventes - Coût d\'achat des produits', ''],
      ['Total Dépenses', kpis.totalExpenses, '', kpis.totalExpenses > kpis.totalProfit ? 'ATT: Élevé' : 'OK: Correct', 'Charges et frais de la période', ''],
      ['Bénéfice Net Final', kpis.netProfit, '', kpis.netProfit >= 0 ? 'OK: Positif' : 'ERR: Déficitaire', 'Marge brute - Dépenses', ''],
      ['Nombre de Transactions', kpis.salesCount, '', kpis.salesCount >= 10 ? 'OK: Actif' : 'ATT: Faible', 'Volume d\'activité commerciale', ''],
      ['Marge Commerciale', kpis.marginPercentage, '', kpis.marginPercentage >= 20 ? 'OK: Bonne' : 'ATT: À améliorer', 'Objectif : > 20%', ''],
      ['Panier Moyen', kpis.salesCount > 0 ? (kpis.totalRevenue / kpis.salesCount).round() : 0, '', 'INFO', 'Valeur moyenne par transaction', ''],
    ];

    for (int i = 0; i < kpiRows.length; i++) {
      final bgColor = i % 2 == 0 ? 'FFF0F7FF' : 'FFFFFFFF';
      for (int j = 0; j < kpiRows[i].length; j++) {
        final cell = sheet1.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 5 + i));
        cell.value = _buildCellValue(kpiRows[i][j]);
        final bold = j == 0 || j == 1;
        final fgColor = j == 1 ? (kpis.netProfit >= 0 ? 'FF16A34A' : 'FFDC2626') : 'FF0F172A';
        NumFormat? numFmtStyle;
        if (j == 1) {
          numFmtStyle = i == 4 ? NumFormat.standard_0 : (i == 5 ? NumFormat.custom(formatCode: '0.00 %') : NumFormat.custom(formatCode: '#,##0 "${currency[0]}"'));
        }
        cell.cellStyle = _dataStyle(bgHex: bgColor, fgHex: j == 1 ? fgColor : null, bold: bold, numberFormat: numFmtStyle);
      }
      sheet1.setRowHeight(4 + i, 20);
    }

    // Espacement TOP PRODUITS
    final tpStartRow = 14;
    sheet1.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tpStartRow), CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: tpStartRow));
    final tpTitle = sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tpStartRow));
    tpTitle.value = TextCellValue('TOP PRODUITS — MEILLEURES VENTES DE LA PÉRIODE');
    tpTitle.cellStyle = _headerStyle(bgHex: 'FF16A34A', fgHex: 'FFFFFFFF', fontSize: 12, align: HorizontalAlign.Left);
    sheet1.setRowHeight(tpStartRow, 24);

    final tpHeaders = ['RANG', 'NOM DU PRODUIT', 'QTÉ VENDUE', 'CHIFFRE D\'AFFAIRES', 'PART DU CA (%)', ''];
    for (int i = 0; i < tpHeaders.length; i++) {
      _writeHeader(sheet1, i, tpStartRow + 1, tpHeaders[i], bgHex: 'FF14532D', fgHex: 'FFFFFFFF');
    }

    for (int i = 0; i < topProducts.length; i++) {
      final p = topProducts[i];
      final bgColor = i == 0 ? 'FFFFF3CD' : i == 1 ? 'FFE8E8E8' : i == 2 ? 'FFFDE8D8' : (i % 2 == 0 ? 'FFF0FFF0' : 'FFFFFFFF');
      final part = kpis.totalRevenue > 0 ? (p.totalRevenue / kpis.totalRevenue * 100).toStringAsFixed(1) : '0';
      final rank = i == 0 ? '1er' : i == 1 ? '2ème' : i == 2 ? '3ème' : '${i + 1}ème';
      final partDouble = double.tryParse(part) ?? 0.0;
      final rowData = [rank, p.name, p.totalQuantity, p.totalRevenue, partDouble / 100, ''];
      for (int j = 0; j < rowData.length; j++) {
        final cell = sheet1.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: tpStartRow + 2 + i));
        cell.value = _buildCellValue(rowData[j]);
        NumFormat? fmt;
        if (j == 2) fmt = NumFormat.standard_0;
        if (j == 3) fmt = NumFormat.custom(formatCode: '#,##0 "${currency[0]}"');
        if (j == 4) fmt = NumFormat.custom(formatCode: '0.00 %');
        cell.cellStyle = _dataStyle(bgHex: bgColor, bold: i < 3, numberFormat: fmt);
      }
      sheet1.setRowHeight(tpStartRow + 1 + i, 20);
    }

    // Largeurs de colonnes
    _setColWidth(sheet1, 0, 16);
    _setColWidth(sheet1, 1, 40);
    _setColWidth(sheet1, 2, 20);
    _setColWidth(sheet1, 3, 22);
    _setColWidth(sheet1, 4, 20);
    _setColWidth(sheet1, 5, 10);

    // ═══════════════════════════════════════
    // FEUILLE 2 : VENTES DÉTAILLÉES
    // ═══════════════════════════════════════
    final sheet2 = excel['Ventes'];

    // Titre
    sheet2.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('I1'));
    final s2Title = sheet2.cell(CellIndex.indexByString('A1'));
    s2Title.value = TextCellValue('DÉTAIL DES VENTES — Du $fmtRangeStart au $fmtRangeEnd');
    s2Title.cellStyle = _headerStyle(bgHex: 'FF0F172A', fgHex: 'FFFFFFFF', fontSize: 13, align: HorizontalAlign.Center);
    sheet2.setRowHeight(0, 28);

    // En-têtes
    final hSales = ['DATE/HEURE', 'RÉFÉRENCE', 'CLIENT', 'VENDEUR', 'TOTAL ($currency)', 'PAYÉ ($currency)', 'RESTE ($currency)', 'REMISE ($currency)', 'MODE PAIEMENT', 'STATUT'];
    for (int i = 0; i < hSales.length; i++) {
      _writeHeader(sheet2, i, 1, hSales[i]);
    }
    sheet2.setRowHeight(1, 22);

    // Données ventes
    double grandTotal = 0, grandPaid = 0, grandDiscount = 0;
    for (int i = 0; i < sales.length; i++) {
      final s = sales[i];
      final total = (s['total_amount'] as num).toDouble();
      final paid = (s['amount_paid'] as num).toDouble();
      final refunded = (s['refunded_amount'] as num).toDouble();
      final discount = (s['discount_amount'] as num).toDouble();
      final isCredit = (s['is_credit'] as int) == 1;
      grandTotal += total;
      grandPaid += paid;
      grandDiscount += discount;

      final bgColor = i % 2 == 0 ? 'FFF8FAFC' : 'FFFFFFFF';
      final statusColor = refunded > 0 ? 'FFDC2626' : isCredit ? 'FFCA8A04' : 'FF16A34A';
      final statusStr = refunded > 0 ? 'Remboursé' : isCredit ? 'Crédit' : 'Réglé';

      final rowVals = [
        fmtSalesDates[i], s['id'].toString(), s['client_name'] as String,
        s['seller_name'] as String,
        total, paid, total - paid,
        discount, s['payment_method']?.toString() ?? '-', statusStr,
      ];
      for (int j = 0; j < rowVals.length; j++) {
        final cell = sheet2.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 2 + i));
        cell.value = _buildCellValue(rowVals[j]);
        final isStatus = j == 9;
        NumFormat? fmt = (j >= 4 && j <= 7) ? NumFormat.custom(formatCode: '#,##0') : null;
        cell.cellStyle = _dataStyle(bgHex: bgColor, fgHex: isStatus ? statusColor : null, bold: isStatus, numberFormat: fmt);
      }
      sheet2.setRowHeight(1 + i, 18);
    }

    // Ligne TOTAL
    final totalRow = 2 + sales.length;
    final totalCells = ['', '', '', 'TOTAL', grandTotal, grandPaid, grandTotal - grandPaid, grandDiscount, '', ''];
    for (int j = 0; j < totalCells.length; j++) {
      final cell = sheet2.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: totalRow));
      cell.value = _buildCellValue(totalCells[j]);
      NumFormat? fmt = (j >= 4 && j <= 7) ? NumFormat.custom(formatCode: '#,##0') : null;
      cell.cellStyle = _headerStyle(bgHex: 'FF1E3A5F', fgHex: 'FFFFFFFF', align: j >= 4 ? HorizontalAlign.Right : HorizontalAlign.Left)..numberFormat = fmt ?? NumFormat.standard_0;
    }

    _setColWidth(sheet2, 0, 18);
    _setColWidth(sheet2, 1, 22);
    _setColWidth(sheet2, 2, 25);
    _setColWidth(sheet2, 3, 20);
    _setColWidth(sheet2, 4, 16);
    _setColWidth(sheet2, 5, 14);
    _setColWidth(sheet2, 6, 14);
    _setColWidth(sheet2, 7, 14);
    _setColWidth(sheet2, 8, 18);
    _setColWidth(sheet2, 9, 16);

    // ═══════════════════════════════════════
    // FEUILLE 3 : DÉPENSES
    // ═══════════════════════════════════════
    final sheet3 = excel['Depenses'];

    sheet3.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    final s3Title = sheet3.cell(CellIndex.indexByString('A1'));
    s3Title.value = TextCellValue('REGISTRE DES DÉPENSES — Du $fmtRangeStart au $fmtRangeEnd');
    s3Title.cellStyle = _headerStyle(bgHex: 'FFDC2626', fgHex: 'FFFFFFFF', fontSize: 13, align: HorizontalAlign.Center);
    sheet3.setRowHeight(0, 28);

    final hExp = ['DATE', 'LIBELLÉ', 'CATÉGORIE', 'MONTANT ($currency)', 'MODE PAIEMENT'];
    for (int i = 0; i < hExp.length; i++) {
      _writeHeader(sheet3, i, 1, hExp[i], bgHex: 'FF7F1D1D', fgHex: 'FFFFFFFF');
    }
    sheet3.setRowHeight(1, 22);

    double grandExpenses = 0;
    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final amount = (e['amount'] as num).toDouble();
      grandExpenses += amount;
      final bgColor = i % 2 == 0 ? 'FFFFF5F5' : 'FFFFFFFF';
      final rowVals = [fmtExpenseDates[i], e['description'] ?? '-', e['category'] ?? 'AUTRE', amount, e['account_name']?.toString() ?? '-'];
      for (int j = 0; j < rowVals.length; j++) {
        final cell = sheet3.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 2 + i));
        cell.value = _buildCellValue(rowVals[j]);
        NumFormat? fmt = (j == 3) ? NumFormat.custom(formatCode: '#,##0') : null;
        cell.cellStyle = _dataStyle(bgHex: bgColor, bold: j == 3, fgHex: j == 3 ? 'FFDC2626' : null, numberFormat: fmt);
      }
      sheet3.setRowHeight(1 + i, 18);
    }

    // Total dépenses
    final expTotalRow = 2 + expenses.length;
    final expTotals = ['', 'TOTAL DÉPENSES', '', grandExpenses, ''];
    for (int j = 0; j < expTotals.length; j++) {
      final cell = sheet3.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: expTotalRow));
      cell.value = _buildCellValue(expTotals[j]);
      NumFormat? fmt = (j == 3) ? NumFormat.custom(formatCode: '#,##0') : null;
      cell.cellStyle = _headerStyle(bgHex: 'FF7F1D1D', fgHex: 'FFFFFFFF')..numberFormat = fmt ?? NumFormat.standard_0;
    }

    _setColWidth(sheet3, 0, 14);
    _setColWidth(sheet3, 1, 35);
    _setColWidth(sheet3, 2, 20);
    _setColWidth(sheet3, 3, 18);
    _setColWidth(sheet3, 4, 18);

    // ═══════════════════════════════════════
    // RETOUR DES BYTES
    // ═══════════════════════════════════════
    return excel.encode();
  }
}
