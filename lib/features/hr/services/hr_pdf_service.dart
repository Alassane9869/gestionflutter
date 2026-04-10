import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:printing/printing.dart';
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
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Période : ${payroll.periodLabel}", style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text("Année : ${payroll.year}", style: pw.TextStyle(font: fontBold, fontSize: 14)),
              ]
          ),
          pw.Divider(),
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
    if (settings.directPhysicalPrinting && targetPrinterName != null && targetPrinterName.isNotEmpty) {
      try {
        final printers = await Printing.listPrinters();
        final target = printers.firstWhere(
          (p) => p.name.toLowerCase().trim() == targetPrinterName.toLowerCase().trim(),
          orElse: () => printers.first,
        );

        await Printing.directPrintPdf(
          printer: target,
          onLayout: (format) async => doc.save(),
        );
        return;
      } catch (e) {
        debugPrint("Direct print error: $e");
      }
    }

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: name,
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
    
    // Group articles into logical Titres
    final List<({String title, List<({String title, String body})> subArticles})> titres = [
      (
        title: "TITRE I : DISPOSITIONS GÉNÉRALES",
        subArticles: [
          (title: "ARTICLE 1 : OBJET ET NATURE DU CONTRAT", body: "Le présent contrat est conclu conformément au Code du Travail de la République du Mali (Loi n°92-020). L'Employeur engage l'Employé sous le régime du ${c.contractTypeLabel}."),
          (title: "ARTICLE 2 : QUALIFICATIONS ET FONCTIONS", body: "L'Employé est recruté en qualité de « ${c.position ?? 'Collaborateur'} » au sein du département « ${c.department ?? 'Général'} ». Il exercera ses fonctions sous l'autorité directe de la Direction ou de son représentant."),
          (title: "ARTICLE 3 : LIEU DE TRAVAIL", body: "Le lieu de travail habituel est fixé à ${settings.address}. Toutefois, en raison des nécessités de service, l'Employé pourra être appelé à effectuer des missions ou déplacements sur l'ensemble du territoire national."),
        ]
      ),
      (
        title: "TITRE II : DURÉE ET EXÉCUTION DU CONTRAT",
        subArticles: [
          (title: "ARTICLE 4 : DATE D'EFFET ET DURÉE", body: "Le présent contrat prend effet à compter du ${DateFormatter.formatLongDate(c.startDate)}. ${c.contractType == ContractType.cdi ? 'Le contrat est conclu pour une durée indéterminée.' : 'La durée est fixée jusqu\'au ${c.endDate != null ? DateFormatter.formatLongDate(c.endDate!) : 'la fin du projet'}.'}"),
          (title: "ARTICLE 5 : PERIODE D'ESSAI", body: "Le présent engagement est soumis à une période d'essai de ${c.contractType == ContractType.cdi ? 'trois (03) mois' : 'un (01) mois'}, renouvelable une fois. Durant cette période, chacune des parties pourra rompre le contrat sans préavis ni indemnité."),
          (title: "ARTICLE 6 : CONDITIONS DE TRAVAIL ET HORAIRES", body: "L'horaire de travail est de quarante (40) heures par semaine, conformément à la réglementation en vigueur au Mali. L'Employé s'engage à respecter les horaires fixés par l'entreprise."),
        ]
      ),
      (
        title: "TITRE III : CONDITIONS FINANCIÈRES",
        subArticles: [
          (title: "ARTICLE 7 : RÉMUNÉRATION", body: "En contrepartie de son travail, l'Employé percevra un salaire mensuel net de ${DateFormatter.formatCurrency(c.baseSalary, settings.currency)}. Ce montant sera versé à la fin de chaque mois par virement ou chèque."),
          (title: "ARTICLE 8 : INDEMNITÉS ET AVANTAGES", body: "L'Employé bénéficie des indemnités suivantes : Transport (${DateFormatter.formatCurrency(c.transportAllowance, settings.currency)}), Repas (${DateFormatter.formatCurrency(c.mealAllowance, settings.currency)}). Tout autre avantage est soumis à la discrétion de l'Employeur."),
        ]
      ),
      (
        title: "TITRE IV : OBLIGATIONS ET DISCIPLINE",
        subArticles: [
          (title: "ARTICLE 9 : LIEN DE SUBORDINATION ET DISCIPLINE", body: "L'Employé s'engage à se conformer aux directives de sa hiérarchie et à respecter scrupuleusement le règlement intérieur de l'entreprise."),
          (title: "ARTICLE 10 : OBLIGATION DE LOYAUTÉ", body: "L'Employé s'engage à consacrer l'intégralité de son activité professionnelle à l'entreprise durant les heures de service et à ne pas exercer d'activité concurrente ou nuisible."),
          (title: "ARTICLE 11 : CONFIDENTIALITÉ ET SECRET PROFESSIONNEL", body: "L'Employé est tenu au secret professionnel absolu concernant les données techniques, commerciales ou financières de l'entreprise. Cette obligation survit à la rupture du contrat."),
          (title: "ARTICLE 12 : CLAUSE DE NON-CONCURRENCE", body: "En cas de rupture du contrat, l'Employé s'interdit d'exercer une activité concurrente pour son propre compte ou chez un tiers dans un rayon de 50km pendant une durée de 12 mois."),
        ]
      ),
      (
        title: "TITRE V : PROTECTION SOCIALE ET HYGIÈNE",
        subArticles: [
          (title: "ARTICLE 13 : CONGÉS PAYÉS", body: "L'Employé a droit à un congé payé au taux de deux jours et demi (2,5) par mois de service effectif, conformément au Code du Travail malien."),
          if (c.contractType != ContractType.prestataire)
            (title: "ARTICLE 14 : PROTECTION SOCIALE (INPS / AMO)", body: "L'Employé sera affilié à l'Institut National de Prévoyance Sociale (INPS) et à l'Assurance Maladie Obligatoire (AMO). Les cotisations seront retenues à la source selon les taux légaux."),
          (title: "ARTICLE 15 : SANTÉ, SÉCURITÉ ET HYGIÈNE", body: "L'Employeur s'engage à fournir un environnement de travail sécurisé. L'Employé doit respecter les consignes d'hygiène et de sécurité et utiliser le matériel de protection fourni."),
          (title: "ARTICLE 16 : MATÉRIEL ET OUTILLAGE", body: "Tout matériel confié à l'Employé doit être maintenu en bon état. En cas de perte ou dégradation volontaire, l'Employé pourra être tenu pour responsable financièrement."),
        ]
      ),
      (
        title: "TITRE VI : MODIFICATION ET RUPTURE",
        subArticles: [
          (title: "ARTICLE 17 : MODIFICATION DU CONTRAT", body: "Toute modification substantielle du présent contrat fera l'objet d'un avenant écrit signé par les deux parties."),
          (title: "ARTICLE 18 : RUPTURE DU CONTRAT", body: "En dehors de la période d'essai, la rupture du contrat s'effectue selon les dispositions du Code du Travail (Licenciement, Démission, Accord Parties)."),
          (title: "ARTICLE 19 : PRÉAVIS", body: "En cas de rupture, un préavis de ${c.contractType == ContractType.cdi ? 'deux (02) mois' : 'un (01) mois'} doit être respecté par la partie qui prend l'initiative de la rupture."),
          if (c.contractType == ContractType.cdi)
            (title: "ARTICLE 20 : INDEMNITÉ DE LICENCIEMENT", body: "En cas de licenciement (hors faute lourde), l'indemnité sera calculée selon les barèmes en vigueur dans la Convention Collective de branche au Mali."),
        ]
      ),
      (
        title: "TITRE VII : DISPOSITIONS FINALES",
        subArticles: [
          (title: "ARTICLE 21 : LITIGES ET COMPÉTENCE JURIDICTIONNELLE", body: "Tout litige relatif au présent contrat sera soumis à une tentative de conciliation. À défaut, le Tribunal du Travail de la région de l'Employeur sera seul compétent."),
          (title: "ARTICLE 22 : RÈGLEMENT INTÉRIEUR", body: "L'Employé reconnaît avoir pris connaissance du Règlement Intérieur de ${settings.name.toUpperCase()} et s'engage à en respecter toutes les dispositions."),
        ]
      ),
    ];

    pw.Widget body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Text("ENTRE LES SOUSSIGNES :", style: pw.TextStyle(font: fb, decoration: pw.TextDecoration.underline, fontSize: 11)),
        pw.SizedBox(height: 5),
        pw.Text("L'entreprise ${settings.name.toUpperCase()}, domiciliée à ${settings.address}, représentée par la Direction Générale, ci-après dénommée « l'Employeur ».", textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 5),
        pw.Text("ET"),
        pw.SizedBox(height: 5),
        pw.Text("M/Mme ${e.fullName}, né(e) le ${e.birthDate != null ? DateFormatter.formatDate(e.birthDate!) : 'N/A'}, nationalité ${e.nationality ?? 'N/A'}, résidant à ${e.address ?? 'N/A'}, ci-après dénommé(e) « l'Employé ».", textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 10),
        pw.Text("Il a été convenu et arrêté ce qui suit :", style: pw.TextStyle(font: fb)),
        pw.SizedBox(height: 15),

        ...titres.map((titre) => _buildTitreBlock(titre, fb, style)),

        pw.SizedBox(height: 30),
        pw.Text("Fait à ${settings.address}, le ${DateFormatter.formatLongDate(DateTime.now())}", style: pw.TextStyle(font: f)),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(children: [pw.Text("L'Employé(e)", style: pw.TextStyle(font: fb)), pw.SizedBox(height: 40), pw.Text("(Signature précédée de 'Lu et Approuvé')")]),
            pw.Column(children: [pw.Text("Pour l'Employeur / La Direction", style: pw.TextStyle(font: fb)), pw.SizedBox(height: 40), pw.Text("Cachet et Signature")]),
          ]
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
         pw.SizedBox(height: 30),
         pw.Center(child: pw.Text(title, style: pw.TextStyle(font: fb, fontSize: 24, decoration: pw.TextDecoration.underline, color: accentColor))),
         pw.SizedBox(height: 40),
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
