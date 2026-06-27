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

enum PdfTemplateStyle {
  standard, premium, modern
}

class HrPdfService {
  // Retired _getCurrencyFormat in favor of DateFormatter.formatCurrency

  // --- PUBLIC API ---

  Future<void> generateAndPrintContract(User employee, EmployeeContract contract, PdfTemplateStyle style, ShopSettings settings) async {
    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(employee, "CONTRAT DE TRAVAIL", style, fontBold, settings),
        footer: (pw.Context context) => _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildContractContent(employee, contract, style, font, fontBold, settings),
        ],
      ),
    );
    await _printDoc(doc, "Contrat_${employee.fullName}_${contract.id.substring(0, 4)}", settings, settings.contractPrinterName);
  }

  Future<void> generateAndPrintPayroll(User employee, Payroll payroll, PdfTemplateStyle style, ShopSettings settings) async {
    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(employee, "BULLETIN DE PAIE", style, fontBold, settings),
        footer: (pw.Context context) => _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildPayrollLayout(employee, payroll, style, font, fontBold, settings),
        ],
      ),
    );
    await _printDoc(doc, "Bulletin_${employee.fullName}_${payroll.periodLabel}", settings, settings.payrollPrinterName);
  }

  Future<void> generateAndPrintProfessionalAttestation(User employee, EmployeeContract? contract, PdfTemplateStyle style, ShopSettings settings) async {
    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;

    String title = "ATTESTATION PROFESSIONNELLE";
    if (contract != null) {
      if (contract.contractType == ContractType.cdi || contract.contractType == ContractType.cdd) {
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
        header: (pw.Context context) => _buildHeader(employee, title, style, fontBold, settings),
        footer: (pw.Context context) => _buildFooter(style, font, settings, context),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          _buildAttestationContent(employee, contract, style, font, fontBold, settings, title),
        ],
      ),
    );
    await _printDoc(doc, "Attestation_${employee.fullName}", settings, settings.reportPrinterName);
  }

  Future<void> _printDoc(pw.Document doc, String name, ShopSettings settings, String? targetPrinterName) async {
    await PrintingHelper.printWithFallback(
      doc: doc,
      targetPrinterName: targetPrinterName,
      directPrint: settings.directPhysicalPrinting,
      jobName: name,
    );
  }

  // --- HELPERS: HEADER & FOOTER ---
  pw.Widget _buildHeader(User employee, String title, PdfTemplateStyle style, pw.Font fontBold, ShopSettings settings) {
    pw.MemoryImage? logoImage;
    if (settings.logoPath != null) {
      final file = File(settings.logoPath!);
      if (file.existsSync()) {
        logoImage = pw.MemoryImage(file.readAsBytesSync());
      }
    }

    final accentColor = style == PdfTemplateStyle.premium ? PdfColors.blueGrey900 : (style == PdfTemplateStyle.modern ? PdfColors.teal800 : PdfColors.blue900);

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 16, color: accentColor)),
                if (settings.slogan.isNotEmpty) pw.Text(settings.slogan, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text("${settings.address} | ${settings.phone}", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            if (logoImage != null)
              pw.Container(
                width: 50,
                height: 50,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: accentColor, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text("ELITE GRH", style: pw.TextStyle(color: accentColor, fontSize: 8, font: fontBold)),
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Column(children: [
            pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.black, letterSpacing: 1.2)),
            if (style == PdfTemplateStyle.premium) pw.Container(width: 200, height: 1.5, color: PdfColors.blueGrey200, margin: const pw.EdgeInsets.only(top: 2)),
          ]),
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1.5, color: accentColor),
      ],
    );
  }

  pw.Widget _buildFooter(PdfTemplateStyle style, pw.Font font, ShopSettings settings, pw.Context context) {
    final curYear = DateTime.now().year;
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
                pw.Text("Paraphes :", style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Container(
                  width: 60, height: 20,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
                ),
              ]
            ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text("${settings.name} - ${settings.address}", style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Tél: ${settings.phone} | Email: ${settings.email}", style: pw.TextStyle(font: font, fontSize: 7)),
                  pw.Text("RC: ${settings.rc.isNotEmpty ? settings.rc : 'En cours'} | NIF: ${settings.nif.isNotEmpty ? settings.nif : 'En cours'}", style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text("© $curYear ${settings.name} - Généré par Danaya+ Pro Elite", style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey500)),
                ]
              )
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Page ${context.pageNumber}/${context.pagesCount}", style: pw.TextStyle(font: font, fontSize: 8)),
                if (style == PdfTemplateStyle.premium)
                  pw.Text("CONFIDENTIEL", style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey400, fontWeight: pw.FontWeight.bold)),
              ]
            ),
          ],
        ),
      ],
    );
  }

  // --- HELPERS: CONTRACTS ---

  pw.Widget _buildContractContent(User e, EmployeeContract c, PdfTemplateStyle style, pw.Font f, pw.Font fb, ShopSettings settings) {
    final accentColor = style == PdfTemplateStyle.premium ? PdfColors.blueGrey900 : (style == PdfTemplateStyle.modern ? PdfColors.teal900 : PdfColors.blue900);
    
    // Group articles into logical Titres
    final List<({String title, List<({String title, String body})> subArticles})> titres = [
      (
        title: "TITRE I : ENGAGEMENT ET ATTRIBUTIONS",
        subArticles: [
          (title: "ARTICLE 1 : OBJET DU CONTRAT", body: "Le présent contrat est conclu sous le régime du ${c.contractTypeLabel} conformément aux dispositions de la Loi n°92-020 portant Code du Travail en République du Mali. L'Employeur engage l'Employé sous réserve des formalités légales."),
          (title: "ARTICLE 2 : FONCTIONS ET LIEU DE TRAVAIL", body: "L'Employé occupera le poste de « ${c.position ?? 'Collaborateur'} » au sein du département « ${c.department ?? 'Général'} ». Le lieu de travail habituel est fixé à : ${settings.address}."),
          (title: "ARTICLE 3 : PÉRIODE D'ESSAI", body: "Le présent contrat comporte une période d'essai de ${c.contractType == ContractType.cdi ? 'trois (03) mois' : 'un (01) mois'}, durant laquelle chaque partie peut résilier le contrat librement sans préavis ni indemnité, conformément à la réglementation malienne."),
        ]
      ),
      (
        title: "TITRE II : RÉMUNÉRATION ET TEMPS DE TRAVAIL",
        subArticles: [
          (title: "ARTICLE 4 : RÉMUNÉRATION ET AVANTAGES", body: "En contrepartie, l'Employé percevra un salaire mensuel net de ${DateFormatter.formatCurrency(c.baseSalary, settings.currency)}, plus indemnité de transport : ${DateFormatter.formatCurrency(c.transportAllowance, settings.currency)} et repas : ${DateFormatter.formatCurrency(c.mealAllowance, settings.currency)}, sous déduction des cotisations sociales obligatoires INPS et AMO."),
          (title: "ARTICLE 5 : HORAIRES DE TRAVAIL", body: "La durée hebdomadaire de travail est fixée à quarante (40) heures selon la réglementation nationale en vigueur au Mali (Article L.133 du Code du Travail)."),
        ]
      ),
      (
        title: "TITRE III : DEVOIRS ET RUPTURE DU CONTRAT",
        subArticles: [
          (title: "ARTICLE 6 : CONFIDENTIALITÉ ET LOYAUTÉ", body: "L'Employé s'engage à consacrer son activité professionnelle à l'entreprise et à respecter le secret professionnel le plus absolu concernant les données internes."),
          (title: "ARTICLE 7 : RUPTURE ET PRÉAVIS", body: "La rupture du contrat après la période d'essai s'effectue selon l'article L.38 du Code du Travail malien, sous réserve d'un préavis écrit de ${c.contractType == ContractType.cdi ? 'deux (02) mois' : 'un (01) mois'}, sauf faute lourde."),
        ]
      ),
    ];

    pw.Widget body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Text("ENTRE LES SOUSSIGNÉS :", style: pw.TextStyle(font: fb, fontSize: 10, color: accentColor, letterSpacing: 0.5)),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("L'EMPLOYEUR", style: pw.TextStyle(font: fb, fontSize: 8, color: accentColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(settings.name.toUpperCase(), style: pw.TextStyle(font: fb, fontSize: 9)),
                    pw.Text("Adresse : ${settings.address}", style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text("Représenté par la Direction Générale", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("L'EMPLOYÉ(E)", style: pw.TextStyle(font: fb, fontSize: 8, color: accentColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(e.fullName.toUpperCase(), style: pw.TextStyle(font: fb, fontSize: 9)),
                    pw.Text("Adresse : ${e.address ?? 'N/A'}", style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text("Né(e) le : ${e.birthDate != null ? DateFormatter.formatDate(e.birthDate!) : 'N/A'}", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text("Il a été convenu et arrêté ce qui suit :", style: pw.TextStyle(font: fb, fontSize: 9.5)),
        pw.SizedBox(height: 10),

        ...titres.map((titre) => _buildTitreBlock(titre, fb, style)),

        pw.SizedBox(height: 20),
        pw.Text("Fait à ${settings.address}, le ${DateFormatter.formatLongDate(DateTime.now())}", style: pw.TextStyle(font: f, fontSize: 9)),
        pw.SizedBox(height: 15),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Container(
                height: 80,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("L'EMPLOYÉ(E)", style: pw.TextStyle(font: fb, fontSize: 8, color: accentColor)),
                    pw.Spacer(),
                    pw.Text("Signature (précédée de 'Lu et Approuvé') :", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Container(
                height: 80,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("L'EMPLOYEUR / LA DIRECTION", style: pw.TextStyle(font: fb, fontSize: 8, color: accentColor)),
                    pw.Spacer(),
                    pw.Text("Signature et Cachet :", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (style == PdfTemplateStyle.premium) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.5)),
        child: body,
      );
    }
    return body;
  }

  pw.Widget _buildTitreBlock(dynamic titre, pw.Font fb, PdfTemplateStyle style) {
    final titreColor = style == PdfTemplateStyle.premium ? PdfColors.blueGrey900 : (style == PdfTemplateStyle.modern ? PdfColors.teal900 : PdfColors.blue900);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Text(titre.title, style: pw.TextStyle(font: fb, fontSize: 10, color: titreColor, letterSpacing: 1.1)),
        ),
        pw.SizedBox(height: 5),
        ...titre.subArticles.map((art) => _art(fb, art.title, art.body, style)).toList(),
        pw.SizedBox(height: 10),
      ]
    );
  }

  pw.Widget _art(pw.Font fb, String title, String body, PdfTemplateStyle style) {
    final titleColor = style == PdfTemplateStyle.premium ? PdfColors.blueGrey800 : (style == PdfTemplateStyle.modern ? PdfColors.teal900 : PdfColors.black);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fb, fontSize: 9, color: titleColor)),
          pw.SizedBox(height: 2),
          pw.Text(body, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.justify),
        ]
      )
    );
  }

  // --- HELPERS: PAYSLIPS ---

  pw.Widget _buildPayrollLayout(User e, Payroll p, PdfTemplateStyle style, pw.Font f, pw.Font fb, ShopSettings settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: style == PdfTemplateStyle.premium ? PdfColors.blueGrey50 : PdfColors.grey100,
            border: pw.Border.all(color: style == PdfTemplateStyle.premium ? PdfColors.blueGrey200 : PdfColors.grey300),
            borderRadius: style == PdfTemplateStyle.modern ? const pw.BorderRadius.all(pw.Radius.circular(8)) : null,
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("Salarié(e) : ${e.fullName}", style: pw.TextStyle(font: fb)),
                pw.Text("Position : ${e.role.name.toUpperCase()}", style: const pw.TextStyle(fontSize: 9)),
                pw.Text("Adresse : ${e.address ?? 'N/A'}", style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("Mois : ${p.periodLabel}", style: pw.TextStyle(font: fb, fontSize: 12)),
                pw.Text("ID : ${e.id.substring(0, 8)}", style: const pw.TextStyle(fontSize: 9)),
                pw.Text("Date : ${DateFormatter.formatDate(DateTime.now())}", style: const pw.TextStyle(fontSize: 9)),
              ]),
            ]
          )
        ),
        pw.SizedBox(height: 20),
        _payrollTable(p, f, fb, style, settings),
        pw.SizedBox(height: 20),
        _payrollSummary(p, fb, style, settings),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(children: [pw.Text("Signature Employé", style: const pw.TextStyle(fontSize: 8)), pw.SizedBox(height: 30)]),
            pw.Column(children: [pw.Text("Le Caissier / Comptable", style: const pw.TextStyle(fontSize: 8)), pw.SizedBox(height: 30)]),
          ]
        )
      ]
    );
  }

  pw.Widget _payrollTable(Payroll p, pw.Font f, pw.Font fb, PdfTemplateStyle style, ShopSettings settings) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: style == PdfTemplateStyle.modern ? PdfColors.teal100 : PdfColors.blueGrey100),
      headerStyle: pw.TextStyle(font: fb, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headers: ['Rubrique', 'Base / Taux', 'Gain (+)', 'Retenue (-)'],
      data: [
        ['Salaire de Base', DateFormatter.formatCurrency(p.baseSalary, settings.currency), DateFormatter.formatCurrency(p.baseSalary, settings.currency), '-'],
        ...p.extraLines.map((l) => [l.label, '-', l.isAddition ? DateFormatter.formatCurrency(l.amount, settings.currency) : '-', !l.isAddition ? DateFormatter.formatCurrency(l.amount, settings.currency) : '-']),
        ['TOTAL BRUT', '', DateFormatter.formatCurrency(p.baseSalary + p.totalAdditions, settings.currency), ''],
      ],
    );
  }

  pw.Widget _payrollSummary(Payroll p, pw.Font fb, PdfTemplateStyle style, ShopSettings settings) {
    final bgColor = style == PdfTemplateStyle.premium ? PdfColors.blueGrey900 : (style == PdfTemplateStyle.modern ? PdfColors.teal900 : PdfColors.black);
    final txtColor = PdfColors.white;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: bgColor, width: 2),
        borderRadius: style == PdfTemplateStyle.modern ? const pw.BorderRadius.all(pw.Radius.circular(4)) : null,
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text("NET À PAYER : ", style: pw.TextStyle(font: fb, fontSize: 14, color: txtColor)),
        pw.Text(DateFormatter.formatCurrency(p.netSalary, settings.currency), style: pw.TextStyle(font: fb, fontSize: 16, color: txtColor)),
      ]),
    );
  }

  // --- HELPERS: ATTESTATIONS ---

  pw.Widget _buildAttestationContent(User e, EmployeeContract? c, PdfTemplateStyle style, pw.Font f, pw.Font fb, ShopSettings settings, String title) {
    final accentColor = style == PdfTemplateStyle.premium ? PdfColors.blueGrey900 : (style == PdfTemplateStyle.modern ? PdfColors.teal900 : PdfColors.blue900);
    final isStage = title.contains("STAGE");

    return pw.Container(
      padding: style == PdfTemplateStyle.premium ? const pw.EdgeInsets.all(30) : const pw.EdgeInsets.all(10),
      decoration: style == PdfTemplateStyle.premium ? pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey200, width: 2)) : null,
      child: pw.Column(
       children: [
         pw.SizedBox(height: 20),
         pw.Text(
           "Nous soussignés, ${settings.name.toUpperCase()}, société sise à ${settings.address}, immatriculée au RC sous le n° ${settings.rc.isNotEmpty ? settings.rc : '_________'}, certifions par la présente que :",
           style: pw.TextStyle(font: f, fontSize: 13), textAlign: pw.TextAlign.center,
         ),
         pw.SizedBox(height: 25),
         pw.Text(
           "M/Mme ${e.fullName.toUpperCase()}",
           style: pw.TextStyle(font: fb, fontSize: 18, color: accentColor),
         ),
         pw.SizedBox(height: 25),
         pw.Text(
           isStage 
            ? "A effectué un stage au sein de notre établissement en qualité de « Stagiaire » du département technique/administratif."
            : "Est employé(e) au sein de notre établissement en qualité de « ${c?.position ?? 'Collaborateur'} » depuis le ${c != null ? DateFormatter.formatDate(c.startDate) : '_________'} et est toujours en fonction à ce jour.",
           style: pw.TextStyle(font: f, fontSize: 14, height: 1.6),
           textAlign: pw.TextAlign.center,
         ),
         pw.SizedBox(height: 30),
         pw.Text(
           "En foi de quoi, cette attestation est délivrée à l'intéressé(e) pour servir et valoir ce que de droit.",
           style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
           textAlign: pw.TextAlign.center,
         ),
         pw.SizedBox(height: 60),
         pw.Row(
           mainAxisAlignment: pw.MainAxisAlignment.end,
           children: [
             pw.Column(children: [
               pw.Text("Fait à ${settings.address}, le ${DateFormatter.formatLongDate(DateTime.now())}"),
               pw.Text("La Direction Générale", style: pw.TextStyle(font: fb)),
               pw.SizedBox(height: 80),
               pw.Text("Cachet et Signature"),
             ])
           ]
         )
       ]
      )
    );
  }
}
