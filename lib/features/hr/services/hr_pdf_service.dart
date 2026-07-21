import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/features/hr/domain/models/payroll.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';

enum PdfTemplateStyle {
  standard,
  premium,
  modern,
  executive,
  heritage,
  elegant,
  tech,
  terracotta,
  royal,
  minimalist
}

class HrPdfService {
  PdfColor _getAccentColor(PdfTemplateStyle style) {
    switch (style) {
      case PdfTemplateStyle.standard:
        return PdfColors.blue900;
      case PdfTemplateStyle.premium:
        return PdfColors.blueGrey900;
      case PdfTemplateStyle.modern:
        return PdfColors.teal900;
      case PdfTemplateStyle.executive:
        return PdfColor.fromHex("#1A2B4C"); // Navy
      case PdfTemplateStyle.heritage:
        return PdfColor.fromHex("#5C1D24"); // Burgundy
      case PdfTemplateStyle.elegant:
        return PdfColor.fromHex("#2D5A27"); // Forest Green
      case PdfTemplateStyle.tech:
        return PdfColor.fromHex("#00B4D8"); // Cyan
      case PdfTemplateStyle.terracotta:
        return PdfColor.fromHex("#D66853"); // Terracotta orange
      case PdfTemplateStyle.royal:
        return PdfColor.fromHex("#6F2DBD"); // Amethyst purple
      case PdfTemplateStyle.minimalist:
        return PdfColors.black;
    }
  }
  String _resolveVariables({
    required String text,
    required User employee,
    required ShopSettings settings,
    EmployeeContract? contract,
    Payroll? payroll,
  }) {
    String result = text;
    
    final birthDateStr = employee.birthDate != null ? DateFormatter.formatDate(employee.birthDate!) : 'N/A';
    
    final position = contract?.position ?? 'N/A';
    final department = contract?.department ?? 'N/A';
    final baseSalary = contract != null ? DateFormatter.formatCurrency(contract.baseSalary, settings.currency) : 'N/A';
    final startDate = contract != null ? DateFormatter.formatDate(contract.startDate) : 'N/A';
    final endDate = contract?.endDate != null ? DateFormatter.formatDate(contract!.endDate!) : 'N/A';
    final duration = contract?.endDate != null 
        ? ((contract!.endDate!.difference(contract.startDate).inDays) / 30.4).round().toString()
        : 'N/A';

    final period = payroll?.periodLabel ?? 'N/A';
    final netSalary = payroll != null ? DateFormatter.formatCurrency(payroll.netSalary, settings.currency) : 'N/A';

    final Map<String, String> variables = {
      'NOM_EMPLOYE': employee.fullName,
      'DATE_NAISSANCE': birthDateStr,
      'POSTE': position,
      'DEPARTEMENT': department,
      'SALAIRE': baseSalary,
      'DEVISE': settings.currency,
      'DATE_DEBUT': startDate,
      'DATE_FIN': endDate,
      'DUREE': duration,
      'BOUTIQUE': settings.name,
      'ADRESSE': settings.address,
      'DATE_JOUR': DateFormatter.formatDate(DateTime.now()),
      'PERIODE': period,
      'NET_A_PAYER': netSalary,
    };

    variables.forEach((key, val) {
      result = result.replaceAll('[$key]', val);
      result = result.replaceAll('{{$key}}', val);
    });

    return result;
  }

  // --- PUBLIC API ---

  Future<Uint8List> generateContractPdfBytes(
    User employee,
    EmployeeContract contract,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final String? notes = contract.notes?.trim();
    if (notes != null &&
        (notes.toLowerCase().startsWith('<!doctype html') ||
            notes.toLowerCase().startsWith('<html') ||
            notes.contains('<p>') ||
            notes.contains('<h1>') ||
            notes.contains('<h2>') ||
            notes.contains('<strong>'))) {
      final resolved = _resolveVariables(
        text: notes,
        employee: employee,
        settings: settings,
        contract: contract,
      );
      String htmlContent = resolved;
      if (!htmlContent.contains('<style>')) {
        htmlContent = '''<!doctype html>
<html>
<head>
  <style>
    body { font-family: sans-serif; font-size: 12px; color: #333; line-height: 1.5; }
    h1 { color: #1a237e; font-size: 20px; text-align: center; }
    h2 { color: #1a237e; font-size: 16px; margin-top: 15px; }
    p { margin-bottom: 10px; }
  </style>
</head>
<body>
  $resolved
</body>
</html>''';
      }
      // ignore: deprecated_member_use
      return Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: htmlContent,
      );
    }

    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          buildBackground: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Transform.rotateBox(
                  angle: 0.785398,
                  child: pw.Text(
                    settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 60,
                      color: PdfColors.grey200,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context context) => _buildHeader(
          employee,
          "CONTRAT DE TRAVAIL",
          style,
          fontBold,
          settings,
        ),
        footer: (pw.Context context) =>
            _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          ..._buildContractContent(
            employee,
            contract,
            style,
            font,
            fontBold,
            settings,
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> generateAndPrintContract(
    User employee,
    EmployeeContract contract,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final bytes = await generateContractPdfBytes(employee, contract, style, settings);
    await PrintingHelper.printBytesWithFallback(
      bytes: bytes,
      targetPrinterName: settings.contractPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: "Contrat_${employee.fullName}_${contract.id.substring(0, 4)}",
    );
  }

  Future<Uint8List> generatePayrollPdfBytes(
    User employee,
    Payroll payroll,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final String? notes = payroll.notes?.trim();
    if (notes != null &&
        (notes.toLowerCase().startsWith('<!doctype html') ||
            notes.toLowerCase().startsWith('<html') ||
            notes.contains('<p>') ||
            notes.contains('<h1>') ||
            notes.contains('<h2>') ||
            notes.contains('<strong>'))) {
      final resolved = _resolveVariables(
        text: notes,
        employee: employee,
        settings: settings,
        payroll: payroll,
      );
      String htmlContent = resolved;
      if (!htmlContent.contains('<style>')) {
        htmlContent = '''<!doctype html>
<html>
<head>
  <style>
    body { font-family: sans-serif; font-size: 12px; color: #333; line-height: 1.5; }
    h1 { color: #1a237e; font-size: 20px; text-align: center; }
    h2 { color: #1a237e; font-size: 16px; margin-top: 15px; }
    p { margin-bottom: 10px; }
  </style>
</head>
<body>
  $resolved
</body>
</html>''';
      }
      // ignore: deprecated_member_use
      return Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: htmlContent,
      );
    }

    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(
          employee,
          "BULLETIN DE PAIE",
          style,
          fontBold,
          settings,
        ),
        footer: (pw.Context context) =>
            _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildPayrollLayout(
            employee,
            payroll,
            style,
            font,
            fontBold,
            settings,
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> generateAndPrintPayroll(
    User employee,
    Payroll payroll,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final bytes = await generatePayrollPdfBytes(employee, payroll, style, settings);
    await PrintingHelper.printBytesWithFallback(
      bytes: bytes,
      targetPrinterName: settings.payrollPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: "Bulletin_${employee.fullName}_${payroll.periodLabel}",
    );
  }

  Future<Uint8List> generateAttestationPdfBytes(
    User employee,
    EmployeeContract? contract,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    String title = "ATTESTATION PROFESSIONNELLE";
    if (contract != null) {
      if (contract.contractType == ContractType.cdi ||
          contract.contractType == ContractType.cdd) {
        title = "ATTESTATION DE TRAVAIL";
      } else if (contract.contractType == ContractType.essai) {
        title = "ATTESTATION DE STAGE";
      } else if (contract.contractType == ContractType.prestataire) {
        title = "ATTESTATION DE PRESTATION";
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) =>
            _buildHeader(employee, title, style, fontBold, settings),
        footer: (pw.Context context) =>
            _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildAttestationContent(
            employee,
            contract,
            style,
            font,
            fontBold,
            settings,
            title,
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> generateAndPrintProfessionalAttestation(
    User employee,
    EmployeeContract? contract,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final bytes = await generateAttestationPdfBytes(employee, contract, style, settings);
    await PrintingHelper.printBytesWithFallback(
      bytes: bytes,
      targetPrinterName: settings.reportPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: "Attestation_${employee.fullName}",
    );
  }



  // --- HELPERS: HEADER & FOOTER ---
  pw.Widget _buildHeader(
    User employee,
    String title,
    PdfTemplateStyle style,
    pw.Font fontBold,
    ShopSettings settings,
  ) {
    pw.MemoryImage? logoImage;
    if (settings.logoPath != null) {
      final file = File(settings.logoPath!);
      if (file.existsSync()) {
        logoImage = pw.MemoryImage(file.readAsBytesSync());
      }
    }

    final accentColor = _getAccentColor(style);
    final font = PdfResourceService.instance.regular;

    pw.Widget headerWidget;

    if (style == PdfTemplateStyle.minimalist) {
      headerWidget = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(width: 35, height: 35, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black)),
                      if (settings.slogan.isNotEmpty) pw.Text(settings.slogan, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
                      pw.Text("${settings.address}${settings.phone.isNotEmpty ? " | Tél: ${settings.phone}" : ""}", style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Text("DOCUMENT RH", style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey400, letterSpacing: 0.5)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 10),
        ],
      );
    } else if (style == PdfTemplateStyle.premium) {
      headerWidget = pw.Column(
        children: [
          if (logoImage != null)
            pw.Center(child: pw.Container(width: 45, height: 45, margin: const pw.EdgeInsets.only(bottom: 6), child: pw.Image(logoImage, fit: pw.BoxFit.contain)))
          else
            pw.Center(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: accentColor, width: 1.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Text("ELITE GRH", style: pw.TextStyle(color: accentColor, fontSize: 8, font: fontBold, letterSpacing: 1)),
              ),
            ),
          pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 15, color: accentColor, letterSpacing: 1.5)),
          if (settings.slogan.isNotEmpty) pw.Text(settings.slogan, style: pw.TextStyle(font: font, fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          pw.Text("${settings.address} | Tél: ${settings.phone}", style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1, color: accentColor),
          pw.SizedBox(height: 1),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
        ],
      );
    } else if (style == PdfTemplateStyle.executive) {
      final goldColor = PdfColor.fromHex("#c5a880");
      headerWidget = pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: goldColor, width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white, letterSpacing: 1)),
                    if (settings.slogan.isNotEmpty) pw.Text(settings.slogan, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey200)),
                    pw.SizedBox(height: 4),
                    pw.Text(settings.address, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey300)),
                    if (settings.phone.isNotEmpty) pw.Text("Tél: ${settings.phone}", style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey300)),
                  ],
                ),
                if (logoImage != null)
                  pw.Container(width: 45, height: 45, padding: const pw.EdgeInsets.all(2), decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Image(logoImage, fit: pw.BoxFit.contain))
                else
                  pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: goldColor, width: 1.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text("ELITE", style: pw.TextStyle(color: goldColor, fontSize: 9, font: fontBold))),
              ],
            ),
          ),
          pw.SizedBox(height: 15),
        ],
      );
    } else if (style == PdfTemplateStyle.modern || style == PdfTemplateStyle.tech) {
      headerWidget = pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) pw.Container(width: 45, height: 45, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              else pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: accentColor, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text("ELITE GRH", style: pw.TextStyle(color: accentColor, fontSize: 8, font: fontBold))),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 14, color: accentColor)),
                  if (settings.slogan.isNotEmpty) pw.Text(settings.slogan, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  pw.Text("${settings.address} | Tél: ${settings.phone}", style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 3, color: accentColor),
          pw.SizedBox(height: 12),
        ],
      );
    } else {
      // Default standard
      headerWidget = pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 16, color: accentColor)),
                  if (settings.slogan.isNotEmpty) pw.Text(settings.slogan, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                  pw.Text("${settings.address} | Tél: ${settings.phone}", style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
              if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              else pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: accentColor, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text("ELITE GRH", style: pw.TextStyle(color: accentColor, fontSize: 8, font: fontBold))),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5, color: accentColor),
          pw.SizedBox(height: 10),
        ],
      );
    }

    return pw.Column(
      children: [
        headerWidget,
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: style == PdfTemplateStyle.minimalist ? PdfColors.black : accentColor,
                  letterSpacing: 1.2,
                ),
              ),
              if (style == PdfTemplateStyle.premium)
                pw.Container(
                  width: 150,
                  height: 1,
                  color: PdfColors.blueGrey200,
                  margin: const pw.EdgeInsets.only(top: 2),
                ),
              if (style == PdfTemplateStyle.executive)
                pw.Container(
                  width: 150,
                  height: 1,
                  color: PdfColor.fromHex("#c5a880"),
                  margin: const pw.EdgeInsets.only(top: 2),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  pw.Widget _buildFooter(
    PdfTemplateStyle style,
    pw.Font font,
    ShopSettings settings,
    pw.Context context,
  ) {
    final curYear = DateTime.now().year;
    final accentColor = _getAccentColor(style);

    if (style == PdfTemplateStyle.minimalist) {
      return pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "${settings.name} | Tél: ${settings.phone} | Email: ${settings.email} | RC: ${settings.rc.isNotEmpty ? settings.rc : 'N/A'} | NIF: ${settings.nif.isNotEmpty ? settings.nif : 'N/A'}", 
                style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600)
              ),
              pw.Text("Page ${context.pageNumber}/${context.pagesCount}", style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        ],
      );
    }

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Paraphes :",
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 7,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  width: 60,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
              ],
            ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    "${settings.name} - ${settings.address}",
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  pw.Text(
                    "Tél: ${settings.phone} | Email: ${settings.email}",
                    style: pw.TextStyle(font: font, fontSize: 7),
                  ),
                  pw.Text(
                    "RC: ${settings.rc.isNotEmpty ? settings.rc : 'En cours'} | NIF: ${settings.nif.isNotEmpty ? settings.nif : 'En cours'}",
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (style == PdfTemplateStyle.premium) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "DOCUMENT CONFIDENTIEL ET STRICTEMENT PRIVÉ",
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "© $curYear ${settings.name} - Généré par Danaya+ Pro Elite",
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 6,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "Page ${context.pageNumber}/${context.pagesCount}",
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- HELPERS: CONTRACTS ---

  List<pw.Widget> _buildContractContent(
    User e,
    EmployeeContract c,
    PdfTemplateStyle style,
    pw.Font f,
    pw.Font fb,
    ShopSettings settings,
  ) {
    final accentColor = _getAccentColor(style);

    // Group articles into logical Titres
    final List<
      ({String title, List<({String title, String body})> subArticles})
    >
    titres = [
      (
        title: "TITRE I : ENGAGEMENT ET ATTRIBUTIONS",
        subArticles: [
          (
            title: "ARTICLE 1 : OBJET DU CONTRAT",
            body:
                "Le présent contrat est conclu sous le régime du ${c.contractTypeLabel} conformément aux dispositions de la Loi n°92-020 portant Code du Travail en République du Mali. L'Employeur engage l'Employé sous réserve des formalités légales.",
          ),
          (
            title: "ARTICLE 2 : FONCTIONS ET LIEU DE TRAVAIL",
            body:
                "L'Employé occupera le poste de « ${c.position ?? 'Collaborateur'} » au sein du département « ${c.department ?? 'Général'} ». Le lieu de travail habituel est fixé à : ${settings.address}.",
          ),
          (
            title: "ARTICLE 3 : PÉRIODE D'ESSAI",
            body:
                "Le présent contrat comporte une période d'essai de ${c.contractType == ContractType.cdi ? 'trois (03) mois' : 'un (01) mois'}, durant laquelle chaque partie peut résilier le contrat librement sans préavis ni indemnité, conformément à la réglementation malienne.",
          ),
        ],
      ),
      (
        title: "TITRE II : RÉMUNÉRATION ET TEMPS DE TRAVAIL",
        subArticles: [
          (
            title: "ARTICLE 4 : RÉMUNÉRATION ET AVANTAGES",
            body:
                "En contrepartie, l'Employé percevra un salaire mensuel net de ${DateFormatter.formatCurrency(c.baseSalary, settings.currency)}, plus indemnité de transport : ${DateFormatter.formatCurrency(c.transportAllowance, settings.currency)} et repas : ${DateFormatter.formatCurrency(c.mealAllowance, settings.currency)}, sous déduction des cotisations sociales obligatoires INPS et AMO.",
          ),
          (
            title: "ARTICLE 5 : HORAIRES DE TRAVAIL",
            body:
                "La durée hebdomadaire de travail est fixée à quarante (40) heures selon la réglementation nationale en vigueur au Mali (Article L.133 du Code du Travail).",
          ),
        ],
      ),
      (
        title: "TITRE III : DEVOIRS ET RUPTURE DU CONTRAT",
        subArticles: [
          (
            title: "ARTICLE 6 : CONFIDENTIALITÉ ET LOYAUTÉ",
            body:
                "L'Employé s'engage à consacrer son activité professionnelle à l'entreprise et à respecter le secret professionnel le plus absolu concernant les données internes.",
          ),
          (
            title: "ARTICLE 7 : RUPTURE ET PRÉAVIS",
            body:
                "La rupture du contrat après la période d'essai s'effectue selon l'article L.38 du Code du Travail malien, sous réserve d'un préavis écrit de ${c.contractType == ContractType.cdi ? 'deux (02) mois' : 'un (01) mois'}, sauf faute lourde.",
          ),
        ],
      ),
    ];

    List<pw.Widget> children = [
      pw.SizedBox(height: 10),
      pw.Text(
        "ENTRE LES SOUSSIGNÉS :",
        style: pw.TextStyle(
          font: fb,
          fontSize: 11,
          color: accentColor,
          letterSpacing: 0.5,
        ),
      ),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bloc Employeur
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentColor, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          color: PdfColors.grey200,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Text(
                            "L'EMPLOYEUR",
                            style: pw.TextStyle(font: fb, fontSize: 9, color: accentColor),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fb, fontSize: 10)),
                              pw.SizedBox(height: 4),
                              pw.Text("Adresse : ${settings.address}", style: pw.TextStyle(font: f, fontSize: 8)),
                              pw.Text("Représenté par la Direction Générale", style: pw.TextStyle(font: f, fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // Bloc Employé
                pw.Expanded(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentColor, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Container(
                          color: PdfColors.grey200,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Text(
                            "L'EMPLOYÉ(E)",
                            style: pw.TextStyle(font: fb, fontSize: 9, color: accentColor),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(e.fullName.toUpperCase(), style: pw.TextStyle(font: fb, fontSize: 10)),
                              pw.SizedBox(height: 4),
                              pw.Text("Adresse : ${e.address ?? 'N/A'}", style: pw.TextStyle(font: f, fontSize: 8)),
                              pw.Text("Né(e) le : ${e.birthDate != null ? DateFormatter.formatDate(e.birthDate!) : 'N/A'}", style: pw.TextStyle(font: f, fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              "Il a été convenu et arrêté ce qui suit :",
              style: pw.TextStyle(font: fb, fontSize: 10, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 12),

            if (c.notes != null && c.notes!.trim().isNotEmpty)
              ..._parseCustomContractBody(
                _resolveVariables(
                  text: c.notes!,
                  employee: e,
                  settings: settings,
                  contract: c,
                ),
                f,
                fb,
                accentColor,
              )
            else
              ...titres.map((titre) => _buildTitreBlock(titre, fb, style, accentColor)),

            pw.SizedBox(height: 30),
            pw.Text(
              "Fait en double exemplaire à ${settings.address}, le ${DateFormatter.formatLongDate(DateTime.now())}",
              style: pw.TextStyle(font: fb, fontSize: 9),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 100,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentColor, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "L'EMPLOYÉ(E)",
                          style: pw.TextStyle(font: fb, fontSize: 9, color: accentColor),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "(Signature précédée de la mention 'Lu et Approuvé')",
                          style: pw.TextStyle(font: f, fontSize: 7, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Container(
                    height: 100,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentColor, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "L'EMPLOYEUR / LA DIRECTION",
                          style: pw.TextStyle(font: fb, fontSize: 9, color: accentColor),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "(Signature et Cachet)",
                          style: pw.TextStyle(font: f, fontSize: 7, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ];

    return children;
  }

  pw.Widget _buildTitreBlock(
    dynamic titre,
    pw.Font fb,
    PdfTemplateStyle style,
    PdfColor accentColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border(left: pw.BorderSide(color: accentColor, width: 3)),
          ),
          child: pw.Text(
            titre.title,
            style: pw.TextStyle(
              font: fb,
              fontSize: 10,
              color: accentColor,
              letterSpacing: 1.1,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...titre.subArticles
            .map<pw.Widget>((art) => _art(fb, art.title, art.body, style, accentColor))
            .toList(),
        pw.SizedBox(height: 12),
      ],
    );
  }

  List<pw.Widget> _parseCustomContractBody(
    String notes,
    pw.Font f,
    pw.Font fb,
    PdfColor accentColor,
  ) {
    final paragraphs = notes.split('\n\n');
    final List<pw.Widget> widgets = [];
    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;

      final isTitle =
          trimmed.startsWith('TITRE') ||
          trimmed.startsWith('ARTICLE') ||
          (trimmed.length < 50 && trimmed == trimmed.toUpperCase());

      if (isTitle) {
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border(left: pw.BorderSide(color: accentColor, width: 2)),
            ),
            child: pw.Text(
              trimmed,
              style: pw.TextStyle(font: fb, fontSize: 9.5, color: accentColor),
            ),
          )
        );
      } else {
        widgets.add(
          pw.Paragraph(
            text: trimmed,
            style: pw.TextStyle(font: f, fontSize: 9, color: PdfColors.black),
            margin: const pw.EdgeInsets.only(bottom: 8),
          ),
        );
      }
    }
    return widgets;
  }

  pw.Widget _art(
    pw.Font fb,
    String title,
    String body,
    PdfTemplateStyle style,
    PdfColor accentColor,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10, left: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fb, fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 3),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 6),
            child: pw.Text(
              body,
              style: pw.TextStyle(font: fb, fontSize: 8.5, color: PdfColors.black, lineSpacing: 1.5),
              textAlign: pw.TextAlign.justify,
            ),
          )
        ],
      ),
    );
  }

  // --- HELPERS: PAYSLIPS ---

  pw.Widget _buildPayrollLayout(
    User e,
    Payroll p,
    PdfTemplateStyle style,
    pw.Font f,
    pw.Font fb,
    ShopSettings settings,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: style == PdfTemplateStyle.premium
                ? PdfColors.blueGrey50
                : PdfColors.grey100,
            border: pw.Border.all(
              color: style == PdfTemplateStyle.premium
                  ? PdfColors.blueGrey200
                  : PdfColors.grey300,
            ),
            borderRadius: style == PdfTemplateStyle.modern
                ? const pw.BorderRadius.all(pw.Radius.circular(8))
                : null,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Salarié(e) : ${e.fullName}",
                    style: pw.TextStyle(font: fb),
                  ),
                  pw.Text(
                    "Position : ${e.role.name.toUpperCase()}",
                    style: pw.TextStyle(font: f, fontSize: 9),
                  ),
                  pw.Text(
                    "Adresse : ${e.address ?? 'N/A'}",
                    style: pw.TextStyle(font: f, fontSize: 9),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Mois : ${p.periodLabel}",
                    style: pw.TextStyle(font: fb, fontSize: 12),
                  ),
                  pw.Text(
                    "ID : ${e.id.substring(0, 8)}",
                    style: pw.TextStyle(font: f, fontSize: 9),
                  ),
                  pw.Text(
                    "Date : ${DateFormatter.formatDate(DateTime.now())}",
                    style: pw.TextStyle(font: f, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _payrollTable(p, f, fb, style, settings),
        pw.SizedBox(height: 20),
        _payrollSummary(p, fb, style, settings),
        if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 15),
          pw.Text(
            "Note / Commentaire :",
            style: pw.TextStyle(font: fb, fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            p.notes!,
            style: pw.TextStyle(font: f, fontSize: 8),
            textAlign: pw.TextAlign.justify,
          ),
        ],
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Text(
                  "Signature Employé",
                  style: pw.TextStyle(font: f, fontSize: 8),
                ),
                pw.SizedBox(height: 30),
              ],
            ),
            pw.Column(
              children: [
                pw.Text(
                  "Le Caissier / Comptable",
                  style: pw.TextStyle(font: f, fontSize: 8),
                ),
                pw.SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _payrollTable(
    Payroll p,
    pw.Font f,
    pw.Font fb,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(
        color: style == PdfTemplateStyle.modern || style == PdfTemplateStyle.tech
            ? PdfColors.teal100
            : (style == PdfTemplateStyle.elegant ? PdfColors.green100 : PdfColors.blueGrey100),
      ),
      headerStyle: pw.TextStyle(font: fb, fontSize: 10),
      cellStyle: pw.TextStyle(font: f, fontSize: 9),
      headers: ['Rubrique', 'Base / Taux', 'Gain (+)', 'Retenue (-)'],
      data: [
        [
          'Salaire de Base',
          DateFormatter.formatCurrency(p.baseSalary, settings.currency),
          DateFormatter.formatCurrency(p.baseSalary, settings.currency),
          '-',
        ],
        ...p.extraLines.map(
          (l) => [
            l.label,
            '-',
            l.isAddition
                ? DateFormatter.formatCurrency(l.amount, settings.currency)
                : '-',
            !l.isAddition
                ? DateFormatter.formatCurrency(l.amount, settings.currency)
                : '-',
          ],
        ),
        [
          'TOTAL BRUT',
          '',
          DateFormatter.formatCurrency(
            p.baseSalary + p.totalAdditions,
            settings.currency,
          ),
          '',
        ],
      ],
    );
  }

  pw.Widget _payrollSummary(
    Payroll p,
    pw.Font fb,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) {
    final bgColor = _getAccentColor(style);
    final txtColor = PdfColors.white;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: bgColor, width: 2),
        borderRadius: style == PdfTemplateStyle.modern
            ? const pw.BorderRadius.all(pw.Radius.circular(4))
            : null,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "NET À PAYER : ",
            style: pw.TextStyle(font: fb, fontSize: 14, color: txtColor),
          ),
          pw.Text(
            DateFormatter.formatCurrency(p.netSalary, settings.currency),
            style: pw.TextStyle(font: fb, fontSize: 16, color: txtColor),
          ),
        ],
      ),
    );
  }

  // --- HELPERS: ATTESTATIONS ---

  pw.Widget _buildAttestationContent(
    User e,
    EmployeeContract? c,
    PdfTemplateStyle style,
    pw.Font f,
    pw.Font fb,
    ShopSettings settings,
    String title,
  ) {
    final accentColor = _getAccentColor(style);
    final isStage = title.contains("STAGE");
    final isPrestation = title.contains("PRESTATION");
    final lightBg = PdfColor.fromHex("#F8FAFC");
    final borderColor = PdfColor.fromHex("#E2E8F0");

    final String refNumber = "ATT-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ─── Référence ───
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              "Réf. : $refNumber",
              style: pw.TextStyle(font: fb, fontSize: 9, color: PdfColors.white),
            ),
          ),
        ),
        pw.SizedBox(height: 30),

        // ─── Titre encadré ───
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: accentColor, width: 3),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(font: fb, fontSize: 20, color: accentColor, letterSpacing: 2),
            ),
          ),
        ),
        pw.SizedBox(height: 35),

        // ─── Corps introductif ───
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: "Nous soussignés, ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: settings.name.toUpperCase(),
                style: pw.TextStyle(font: fb, fontSize: 12, color: accentColor),
              ),
              pw.TextSpan(
                text: ", ${settings.legalForm.isNotEmpty ? settings.legalForm : 'Société'} au capital social de ${settings.capital.isNotEmpty ? settings.capital : '____________'}, ayant son siège social à ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: settings.address,
                style: pw.TextStyle(font: fb, fontSize: 12),
              ),
              pw.TextSpan(
                text: ", immatriculée au Registre du Commerce sous le numéro ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: settings.rc.isNotEmpty ? settings.rc : "________________",
                style: pw.TextStyle(font: fb, fontSize: 12),
              ),
              pw.TextSpan(
                text: ", NIF : ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: settings.nif.isNotEmpty ? settings.nif : "________________",
                style: pw.TextStyle(font: fb, fontSize: 12),
              ),
              pw.TextSpan(
                text: ", représentée par son Directeur Général, ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: "atteste par la présente que :",
                style: pw.TextStyle(font: fb, fontSize: 12),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // ─── Fiche d'identité de l'employé ───
        pw.Container(
          decoration: pw.BoxDecoration(
            color: lightBg,
            border: pw.Border.all(color: borderColor, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              // Header de la fiche
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: accentColor,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(5),
                    topRight: pw.Radius.circular(5),
                  ),
                ),
                child: pw.Text(
                  "IDENTIFICATION DE ${isStage ? "L'INTÉRESSÉ(E)" : isPrestation ? "LE/LA PRESTATAIRE" : "L'EMPLOYÉ(E)"}",
                  style: pw.TextStyle(font: fb, fontSize: 11, color: PdfColors.white, letterSpacing: 1),
                ),
              ),
              // Lignes du tableau
              _attestInfoRow("Nom & Prénom(s)", e.fullName.toUpperCase(), fb, f, accentColor, true),
              _attestInfoRow("Poste occupé", c?.position ?? "Collaborateur", fb, f, accentColor, false),
              if (c?.department != null && c!.department!.isNotEmpty)
                _attestInfoRow("Département / Service", c.department!, fb, f, accentColor, true),
              if (c != null)
                _attestInfoRow("Type de contrat", c.contractTypeLabel, fb, f, accentColor, false),
              if (c != null)
                _attestInfoRow("Date d'embauche", DateFormatter.formatLongDate(c.startDate), fb, f, accentColor, true),
              if (c != null && c.endDate != null)
                _attestInfoRow("Date de fin", DateFormatter.formatLongDate(c.endDate!), fb, f, accentColor, false),
              _attestInfoRow("Situation actuelle",
                isStage ? "Stage terminé / en cours" :
                (c != null && c.endDate != null && c.endDate!.isBefore(DateTime.now()))
                    ? "A quitté l'entreprise le ${DateFormatter.formatLongDate(c.endDate!)}"
                    : "En fonction à ce jour",
                fb, f, accentColor, c?.endDate != null ? true : false),
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // ─── Paragraphe de certification ───
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: accentColor, width: 3),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (isStage) ...[
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: "M./Mme ",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                      pw.TextSpan(
                        text: e.fullName.toUpperCase(),
                        style: pw.TextStyle(font: fb, fontSize: 12, color: accentColor),
                      ),
                      pw.TextSpan(
                        text: " a effectué un stage au sein de notre établissement",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                      if (c != null) ...[
                        pw.TextSpan(
                          text: " du ",
                          style: pw.TextStyle(font: f, fontSize: 12),
                        ),
                        pw.TextSpan(
                          text: DateFormatter.formatLongDate(c.startDate),
                          style: pw.TextStyle(font: fb, fontSize: 12),
                        ),
                        if (c.endDate != null) ...[
                          pw.TextSpan(
                            text: " au ",
                            style: pw.TextStyle(font: f, fontSize: 12),
                          ),
                          pw.TextSpan(
                            text: DateFormatter.formatLongDate(c.endDate!),
                            style: pw.TextStyle(font: fb, fontSize: 12),
                          ),
                        ],
                      ],
                      pw.TextSpan(
                        text: ", en qualité de stagiaire au département ${c?.department ?? 'Général'}. "
                            "Durant cette période, l'intéressé(e) a fait preuve de sérieux, d'assiduité et d'un comportement professionnel exemplaire.",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                    ],
                  ),
                ),
              ] else if (isPrestation) ...[
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: "M./Mme ",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                      pw.TextSpan(
                        text: e.fullName.toUpperCase(),
                        style: pw.TextStyle(font: fb, fontSize: 12, color: accentColor),
                      ),
                      pw.TextSpan(
                        text: " assure des prestations de services au profit de notre société en qualité de « ${c?.position ?? 'Prestataire'} »",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                      if (c != null) ...[
                        pw.TextSpan(
                          text: " depuis le ",
                          style: pw.TextStyle(font: f, fontSize: 12),
                        ),
                        pw.TextSpan(
                          text: DateFormatter.formatLongDate(c.startDate),
                          style: pw.TextStyle(font: fb, fontSize: 12),
                        ),
                      ],
                      pw.TextSpan(
                        text: ". L'intéressé(e) remplit ses obligations contractuelles avec professionnalisme et diligence.",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: "M./Mme ",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                      pw.TextSpan(
                        text: e.fullName.toUpperCase(),
                        style: pw.TextStyle(font: fb, fontSize: 12, color: accentColor),
                      ),
                      pw.TextSpan(
                        text: " est employé(e) au sein de notre ${settings.legalForm.isNotEmpty ? settings.legalForm.toLowerCase() : 'société'} en qualité de « ${c?.position ?? 'Collaborateur'} »",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                      if (c != null) ...[
                        pw.TextSpan(
                          text: " depuis le ",
                          style: pw.TextStyle(font: f, fontSize: 12),
                        ),
                        pw.TextSpan(
                          text: DateFormatter.formatLongDate(c.startDate),
                          style: pw.TextStyle(font: fb, fontSize: 12),
                        ),
                      ],
                      pw.TextSpan(
                        text: (c != null && c.endDate != null && c.endDate!.isBefore(DateTime.now()))
                            ? " et a exercé ses fonctions jusqu'au ${DateFormatter.formatLongDate(c.endDate!)}."
                            : " et est toujours en fonction à la date de délivrance de la présente attestation.",
                        style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Durant l'exercice de ses fonctions, l'intéressé(e) a donné entière satisfaction tant sur le plan professionnel que personnel.",
                  style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // ─── Mention légale ───
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex("#FFFBEB"),
            border: pw.Border.all(color: PdfColor.fromHex("#FCD34D"), width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            "En foi de quoi, la présente attestation est établie et délivrée à l'intéressé(e) pour servir et valoir ce que de droit, conformément aux dispositions du Code du Travail de la République du Mali (Loi n°92-020).",
            style: pw.TextStyle(font: f, fontSize: 11, fontStyle: pw.FontStyle.italic, lineSpacing: 5),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 35),

        // ─── Lieu et date + Signatures ───
        pw.Text(
          "Fait à ${settings.address.isNotEmpty ? settings.address.split(',').first.trim() : '____________'}, le ${DateFormatter.formatLongDate(DateTime.now())}",
          style: pw.TextStyle(font: f, fontSize: 12),
        ),
        pw.SizedBox(height: 30),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Colonne employé
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 1.5)),
                    ),
                    child: pw.Text("L'intéressé(e)", style: pw.TextStyle(font: fb, fontSize: 11, color: accentColor)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text("Lu et approuvé", style: pw.TextStyle(font: f, fontSize: 9, fontStyle: pw.FontStyle.italic)),
                  pw.SizedBox(height: 60),
                  pw.Container(
                    width: 120,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
                    ),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(e.fullName, style: pw.TextStyle(font: f, fontSize: 9), textAlign: pw.TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
            // Colonne direction
            pw.Container(
              width: 220,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 1.5)),
                    ),
                    child: pw.Text("La Direction Générale", style: pw.TextStyle(font: fb, fontSize: 11, color: accentColor)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text("Cachet et Signature", style: pw.TextStyle(font: f, fontSize: 9, fontStyle: pw.FontStyle.italic)),
                  pw.SizedBox(height: 60),
                  pw.Container(
                    width: 120,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
                    ),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(settings.name, style: pw.TextStyle(font: f, fontSize: 9), textAlign: pw.TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper row for attestation info table
  pw.Widget _attestInfoRow(String label, String value, pw.Font fb, pw.Font f, PdfColor accentColor, bool altBg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(
        color: altBg ? PdfColors.white : PdfColor.fromHex("#F1F5F9"),
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex("#E2E8F0"), width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(label, style: pw.TextStyle(font: fb, fontSize: 10, color: PdfColor.fromHex("#64748B"))),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: fb, fontSize: 11, color: accentColor)),
          ),
        ],
      ),
    );
  }

  // --- PUBLIC API: PASSATION ---
  Future<Uint8List> generatePassationPdfBytes(
    User employee,
    EmployeeContract? contract,
    PdfTemplateStyle style,
    ShopSettings settings,
  ) async {
    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          buildBackground: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Transform.rotateBox(
                  angle: 0.785398,
                  child: pw.Text(
                    settings.name.toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 60,
                      color: PdfColors.grey200,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context context) => _buildHeader(
          employee,
          "PASSATION DE SERVICE",
          style,
          fontBold,
          settings,
        ),
        footer: (pw.Context context) =>
            _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildPassationContent(
            employee,
            contract,
            style,
            font,
            fontBold,
            settings,
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _buildPassationContent(
    User e,
    EmployeeContract? c,
    PdfTemplateStyle style,
    pw.Font f,
    pw.Font fb,
    ShopSettings settings,
  ) {
    final accentColor = _getAccentColor(style);
    final borderColor = PdfColor.fromHex("#E2E8F0");

    final String refNumber = "PVPS-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}";

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ─── Référence ───
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              "Réf. : $refNumber",
              style: pw.TextStyle(font: fb, fontSize: 9, color: PdfColors.white),
            ),
          ),
        ),
        pw.SizedBox(height: 30),

        // ─── Titre encadré ───
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: accentColor, width: 3),
              ),
            ),
            child: pw.Text(
              "PROCÈS-VERBAL DE PASSATION DE SERVICE",
              style: pw.TextStyle(font: fb, fontSize: 16, color: accentColor, letterSpacing: 1.5),
            ),
          ),
        ),
        pw.SizedBox(height: 35),

        // ─── Corps introductif ───
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: "Aujourd'hui, le ${DateFormatter.formatLongDate(DateTime.now())}, au siège de ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: settings.name.toUpperCase(),
                style: pw.TextStyle(font: fb, fontSize: 12, color: accentColor),
              ),
              pw.TextSpan(
                text: ", il a été procédé à la passation de service pour le poste de ",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
              pw.TextSpan(
                text: (c?.position?.isNotEmpty ?? false) ? c!.position! : "________________",
                style: pw.TextStyle(font: fb, fontSize: 12),
              ),
              pw.TextSpan(
                text: " entre :",
                style: pw.TextStyle(font: f, fontSize: 12, lineSpacing: 6),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ─── Le Sortant ───
        pw.Text("L'EMPLOYÉ(E) SORTANT(E) / MUTÉ(E) :", style: pw.TextStyle(font: fb, fontSize: 11, color: accentColor, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 10),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("- Nom & Prénom(s) : ${e.fullName}", style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 4)),
              pw.Text("- Contact : ${e.phone ?? 'N/A'}", style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 4)),
              pw.Text("- Date de prise de fonction : ${c != null ? DateFormatter.formatShortDate(c.startDate) : 'N/A'}", style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 4)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        
        // ─── L'Entrant ───
        pw.Text("L'EMPLOYÉ(E) ENTRANT(E) :", style: pw.TextStyle(font: fb, fontSize: 11, color: accentColor, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 10),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("- Nom & Prénom(s) : ___________________________", style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 4)),
              pw.Text("- Contact : ___________________________", style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 4)),
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // ─── Description des documents remis ───
        pw.Text("LISTE DES ÉLÉMENTS ET MATÉRIELS TRANSMIS :", style: pw.TextStyle(font: fb, fontSize: 11, color: accentColor, decoration: pw.TextDecoration.underline)),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          height: 100,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor),
            color: PdfColor.fromHex("#FAFAFA")
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              "- \n- \n- \n- ",
              style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 10)
            )
          )
        ),
        pw.SizedBox(height: 20),

        // ─── Conclusion ───
        pw.Text(
          "Par la signature de ce document, l'employé(e) entrant(e) reconnaît avoir pris possession des dossiers, clés, équipements et informations nécessaires à l'exercice de ses fonctions. L'employé(e) sortant(e) déclare n'avoir dissimulé aucune information relative au bon fonctionnement du service.",
          style: pw.TextStyle(font: f, fontSize: 11, lineSpacing: 5, fontStyle: pw.FontStyle.italic),
          textAlign: pw.TextAlign.justify,
        ),
        pw.SizedBox(height: 35),

        // ─── Signatures ───
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Sortant
            pw.Container(
              width: 140,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("L'Employé(e) Sortant(e)", style: pw.TextStyle(font: fb, fontSize: 10, color: accentColor)),
                  pw.SizedBox(height: 60),
                  pw.Container(
                    width: 100,
                    decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderColor))),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(e.fullName, style: pw.TextStyle(font: f, fontSize: 9), textAlign: pw.TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
            // Entrant
            pw.Container(
              width: 140,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("L'Employé(e) Entrant(e)", style: pw.TextStyle(font: fb, fontSize: 10, color: accentColor)),
                  pw.SizedBox(height: 60),
                  pw.Container(
                    width: 100,
                    decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderColor))),
                  ),
                ],
              ),
            ),
            // Direction
            pw.Container(
              width: 140,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("La Direction", style: pw.TextStyle(font: fb, fontSize: 10, color: accentColor)),
                  pw.SizedBox(height: 60),
                  pw.Container(
                    width: 100,
                    decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderColor))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

