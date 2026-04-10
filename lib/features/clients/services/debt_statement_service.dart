import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/clients/domain/models/client_payment.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

import 'package:danaya_plus/features/clients/providers/client_payment_provider.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

final debtStatementServiceProvider = Provider<DebtStatementService>((ref) {
  return DebtStatementService(ref);
});

class DebtStatementService {
  final Ref ref;

  DebtStatementService(this.ref);

  /// Génère un PDF "Relevé de Compte" pour un client donné.
  Future<File> generateStatement(Client client) async {
    final dateStr = DateFormatter.formatDate(DateTime.now());
    
    final salesAsync = ref.read(salesHistoryProvider);
    final allSales = salesAsync.maybeWhen(
      data: (sales) => sales.where((s) => s.sale.clientId == client.id).toList(),
      orElse: () => <SaleWithDetails>[],
    );

    final paymentsAsync = ref.read(clientPaymentsProvider(client.id));
    final allPayments = paymentsAsync.maybeWhen(
      data: (payments) => payments,
      orElse: () => <ClientPayment>[],
    );

    final shopName = ref.read(shopSettingsProvider).value?.name ?? "votre système de gestion";
    final currency = ref.read(shopSettingsProvider).value?.currency ?? 'FCFA';

    // Préparer les données pour l'isolat
    final input = _PdfInput(
      client: client,
      allSales: allSales,
      allPayments: allPayments,
      dateStr: dateStr,
      shopName: shopName,
      currency: currency,
    );

    // Exécuter la génération lourde dans un isolat (worker en arrière-plan)
    final pdfBytes = await compute(_generatePdfIsolate, input);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Releve_Compte_${client.name.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(pdfBytes);
    return file;
  }
}

class _PdfInput {
  final Client client;
  final List<SaleWithDetails> allSales;
  final List<ClientPayment> allPayments;
  final String dateStr;
  final String shopName;
  final String currency;

  _PdfInput({
    required this.client,
    required this.allSales,
    required this.allPayments,
    required this.dateStr,
    required this.shopName,
    required this.currency,
  });
}

/// FONCTION TOP-LEVEL POUR L'ISOLAT
Future<Uint8List> _generatePdfIsolate(_PdfInput input) async {
  final pdf = pw.Document();
  
  // Construire le grand livre (Ledger)
  final List<_LedgerEntry> ledger = [];
  for (final s in input.allSales) {
    ledger.add(_LedgerEntry(
      date: s.sale.date,
      description: "Vente #${s.sale.id.substring(s.sale.id.length - 8).toUpperCase()}",
      reference: s.sale.id.substring(s.sale.id.length - 8).toUpperCase(),
      debit: s.sale.totalAmount,
      credit: s.sale.amountPaid,
      dueDate: s.sale.dueDate,
    ));
  }

  for (final p in input.allPayments) {
    ledger.add(_LedgerEntry(
      date: p.date,
      description: p.description ?? "Règlement de dette",
      reference: p.id.substring(p.id.length - 8).toUpperCase(),
      debit: 0,
      credit: p.amount,
    ));
  }

  ledger.sort((a, b) => a.date.compareTo(b.date));

  double runningBalance = 0;
  final List<List<String>> tableData = [];
  for (final entry in ledger) {
    runningBalance += entry.debit - entry.credit;
    tableData.add([
      DateFormatter.formatDate(entry.date),
      entry.description,
      entry.dueDate != null ? DateFormatter.formatDate(entry.dueDate!) : "-",
      entry.debit > 0 ? DateFormatter.formatNumber(entry.debit) : "-",
      entry.credit > 0 ? DateFormatter.formatNumber(entry.credit) : "-",
      DateFormatter.formatNumber(runningBalance),
    ]);
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _buildHeader(input.client, input.dateStr),
        pw.SizedBox(height: 20),
        _buildSummary(input.client, runningBalance, input.currency),
        pw.SizedBox(height: 30),
        _buildLedgerTable(tableData),
        pw.SizedBox(height: 30),
        _buildFooter(input.shopName),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _buildHeader(Client client, String date) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("RELEVÉ DE COMPTE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text("Date d'émission : $date"),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(client.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.Text(client.phone ?? ""),
          pw.Text(client.address ?? ""),
        ],
      ),
    ],
  );
}

pw.Widget _buildSummary(Client client, double balance, String currency) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: const pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text("SOLDE ACTUEL :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        pw.Text("${DateFormatter.formatNumber(balance, decimalDigits: 2)} $currency", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: balance > 0 ? PdfColors.red900 : PdfColors.green900)),
      ],
    ),
  );
}

pw.Widget _buildLedgerTable(List<List<String>> data) {
  const headers = ['Date', 'Libellé', 'Échéance', 'Débit', 'Crédit', 'Solde'];

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    border: pw.TableBorder.all(color: PdfColors.grey300),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
    cellHeight: 30,
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerLeft,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
    },
  );
}

pw.Widget _buildFooter(String shopName) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text("Note :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text("Veuillez régulariser votre situation dans les plus brefs délais."),
      pw.SizedBox(height: 40),
      pw.Divider(color: PdfColors.grey300),
      pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text("Généré par $shopName", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
      ),
    ],
  );
}

class _LedgerEntry {
  final DateTime date;
  final String description;
  final String reference;
  final double debit;
  final double credit;
  final DateTime? dueDate;

  _LedgerEntry({
    required this.date,
    required this.description,
    required this.reference,
    required this.debit,
    required this.credit,
    this.dueDate,
  });
}
