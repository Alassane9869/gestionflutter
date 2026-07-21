import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/utils/quill_delta_to_pdf.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'package:danaya_plus/features/hr/services/hr_pdf_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/hr/providers/templates_provider.dart';

class TemplatesManagerScreen extends ConsumerStatefulWidget {
  const TemplatesManagerScreen({super.key});

  @override
  ConsumerState<TemplatesManagerScreen> createState() => _TemplatesManagerScreenState();
}

class _TemplatesManagerScreenState extends ConsumerState<TemplatesManagerScreen> {
  String? _selectedTemplateKey;
  late TextEditingController _nameCtrl;
  late quill.QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  final _sidebarSearchCtrl = TextEditingController();
  bool _isEditingMode = true;
  PdfTemplateStyle _selectedStyle = PdfTemplateStyle.standard;
  final Map<String, TextEditingController> _sampleControllers = {};
  
  bool _showLogo = true;
  bool _showSlogan = true;
  bool _showAddress = true;
  bool _showContact = true;
  bool _showLegal = true;

  final Map<String, String> _sampleData = {
    'NOM_EMPLOYE': 'Moussa DIARRA',
    'DATE_NAISSANCE': '12/04/1990',
    'POSTE': 'Ingénieur Logiciel Senior',
    'DEPARTEMENT': 'Technologie & R&D',
    'SALAIRE': '1 500 000',
    'DEVISE': 'FCFA',
    'DATE_DEBUT': '01/07/2026',
    'DATE_FIN': '31/12/2026',
    'DUREE': '6',
    'BOUTIQUE': 'DANAYA PLUS SARL',
    'ADRESSE': 'ACI 2000, Bamako, Mali',
    'DATE_JOUR': '29/06/2026',
  };

  final List<Map<String, String>> _variables = [
    {'code': '[NOM_EMPLOYE]', 'label': 'Nom du collaborateur'},
    {'code': '[DATE_NAISSANCE]', 'label': 'Date de naissance'},
    {'code': '[POSTE]', 'label': 'Intitulé du poste'},
    {'code': '[DEPARTEMENT]', 'label': 'Département/Service'},
    {'code': '[SALAIRE]', 'label': 'Salaire de base'},
    {'code': '[DEVISE]', 'label': 'Devise monétaire (ex: FCFA)'},
    {'code': '[DATE_DEBUT]', 'label': "Date d'embauche / début"},
    {'code': '[DATE_FIN]', 'label': 'Date de fin (si CDD)'},
    {'code': '[DUREE]', 'label': 'Durée du contrat (en mois)'},
    {'code': '[BOUTIQUE]', 'label': "Nom de l'entreprise"},
    {'code': '[ADRESSE]', 'label': "Adresse de l'entreprise"},
    {'code': '[DATE_JOUR]', 'label': "Date de signature (Aujourd'hui)"},
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _quillController = quill.QuillController.basic();
    _quillController.document.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  TextEditingController _getSampleController(String key) {
    if (!_sampleControllers.containsKey(key)) {
      _sampleControllers[key] = TextEditingController(text: _sampleData[key])
        ..addListener(() {
          _sampleData[key] = _sampleControllers[key]!.text;
        });
    }
    return _sampleControllers[key]!;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _sidebarSearchCtrl.dispose();
    for (final ctrl in _sampleControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _replaceQuillController(quill.QuillController newController) {
    _editorFocusNode.unfocus(); // Unfocus but keep the node
    final oldController = _quillController;
    
    _quillController = newController;
    _quillController.document.changes.listen((_) {
      if (mounted) setState(() {});
    });

    // Delay disposal of the old controller to avoid unmounted exceptions from active listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
    });
  }

  void _selectTemplate(String id, List<Map<String, dynamic>> templates) {
    final template = templates.firstWhere((t) => t['id'] == id, orElse: () => {});
    if (template.isEmpty) return;

    final htmlContent = template['content'] as String;

    // Clean HTML: remove excessive <br> but keep single ones to preserve paragraphs.
    // Also insert <br> between paragraphs if not present to prevent Quill merging.
    String sanitizedHtml = htmlContent
        .replaceAll(RegExp(r'(?<=</(?:p|div)>)\s*(?!<br\s*/?>)'), '<br>')
        .replaceAll(RegExp(r'<br\s*/?>(\s*<br\s*/?>)+'), '<br>');

    final delta = HtmlToDelta().convert(sanitizedHtml);
    final newCtrl = quill.QuillController(
      document: quill.Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );

    setState(() {
      _selectedTemplateKey = id;
      _nameCtrl.text = template['title'] as String;
      _replaceQuillController(newCtrl);
    });
  }

  void _createNewTemplate() {
    final delta = HtmlToDelta().convert(
      "<p>Rédigez le texte de votre modèle ici. Vous pouvez utiliser le volet de droite pour insérer des variables dynamiques.</p>",
    );
    final newCtrl = quill.QuillController(
      document: quill.Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    setState(() {
      _selectedTemplateKey = null;
      _nameCtrl.text = "Nouveau modèle";
      _replaceQuillController(newCtrl);
    });
  }

  void _duplicateTemplate() {
    if (_selectedTemplateKey == null) return;
    setState(() {
      final oldName = _nameCtrl.text;
      _selectedTemplateKey = null;
      _nameCtrl.text = "Copie de $oldName";
    });
  }

  void _saveTemplate() async {
    final name = _nameCtrl.text.trim();
    final text = _quillController.document.toPlainText().trim();
    if (name.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom et le contenu ne peuvent pas être vides"), backgroundColor: Colors.orange),
      );
      return;
    }

    final delta = _quillController.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(delta);
    final htmlContent = converter.convert();

    final newId = await ref.read(templatesProvider.notifier).saveTemplate(_selectedTemplateKey, name, htmlContent);
    setState(() {
      _selectedTemplateKey = newId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Modèle '\$name' enregistré !")));
    }
  }

  void _deleteTemplate() async {
    if (_selectedTemplateKey == null || !_selectedTemplateKey!.startsWith("P:")) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le modèle"),
        content: const Text("Voulez-vous vraiment supprimer définitivement ce modèle ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ref.read(templatesProvider.notifier).deleteTemplate(_selectedTemplateKey!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modèle supprimé.")));
      setState(() => _selectedTemplateKey = null);
    }
  }

  void _insertVariable(String variable) {
    final isPerso = _selectedTemplateKey == null || _selectedTemplateKey!.startsWith("P:");
    if (!isPerso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez dupliquer ou créer un modèle personnalisé pour pouvoir l'éditer."), backgroundColor: Colors.orange),
      );
      return;
    }

    final index = _quillController.selection.baseOffset;
    final length = _quillController.selection.extentOffset - index;
    if (index >= 0) {
      _quillController.replaceText(index, length, variable, null);
      _quillController.updateSelection(TextSelection.collapsed(offset: index + variable.length), quill.ChangeSource.local);
    } else {
      final end = _quillController.document.length - 1;
      _quillController.replaceText(end, 0, variable, null);
    }
    _editorFocusNode.requestFocus();
  }

  PdfColor _getPreviewAccentColor(PdfTemplateStyle style) {
    switch (style) {
      case PdfTemplateStyle.standard: return PdfColors.blue900;
      case PdfTemplateStyle.premium: return PdfColors.blueGrey900;
      case PdfTemplateStyle.modern: return PdfColors.teal900;
      case PdfTemplateStyle.executive: return PdfColor.fromHex("#1A2B4C");
      case PdfTemplateStyle.heritage: return PdfColor.fromHex("#5C1D24");
      case PdfTemplateStyle.elegant: return PdfColor.fromHex("#2D5A27");
      case PdfTemplateStyle.tech: return PdfColor.fromHex("#00B4D8");
      case PdfTemplateStyle.terracotta: return PdfColor.fromHex("#D66853");
      case PdfTemplateStyle.royal: return PdfColor.fromHex("#6F2DBD");
      case PdfTemplateStyle.minimalist: return PdfColors.black;
    }
  }

  Future<Uint8List> _generatePdfPreview(PdfPageFormat format, ShopSettings? settings) async {
    final doc = pw.Document();
    final font = PdfResourceService.instance.regular;
    final fontBold = PdfResourceService.instance.bold;
    final deltaJson = _quillController.document.toDelta().toJson();

    final shopName = (settings?.name != null && settings!.name.trim().isNotEmpty) ? settings.name.trim() : "DANAYA PLUS";
    final shopAddress = (settings?.address != null && settings!.address.trim().isNotEmpty) ? settings.address.trim() : "ACI 2000, Bamako, Mali";
    final shopPhone = (settings?.phone != null && settings!.phone.trim().isNotEmpty) ? settings.phone.trim() : "";
    final shopSlogan = (settings?.slogan != null && settings!.slogan.trim().isNotEmpty) ? settings.slogan.trim() : "";
    final shopEmail = (settings?.email != null && settings!.email.trim().isNotEmpty) ? settings.email.trim() : "";
    final shopRc = (settings?.rc != null && settings!.rc.trim().isNotEmpty) ? settings.rc.trim() : "";
    final shopNif = (settings?.nif != null && settings!.nif.trim().isNotEmpty) ? settings.nif.trim() : "";
    final accentColor = _getPreviewAccentColor(_selectedStyle);

    pw.MemoryImage? logoImage;
    if (settings?.logoPath != null) {
      final file = File(settings!.logoPath!);
      if (file.existsSync()) logoImage = pw.MemoryImage(file.readAsBytesSync());
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 60),
        header: (pw.Context context) => _buildPdfHeader(font, fontBold, accentColor, shopName, shopSlogan, shopAddress, shopPhone, logoImage),
        footer: (pw.Context context) => _buildPdfFooter(font, fontBold, accentColor, shopName, shopAddress, shopPhone, shopEmail, shopRc, shopNif, context),
        build: (pw.Context context) {
          final resolvedDelta = deltaJson.map((op) {
            if (op['insert'] is String) {
              String text = op['insert'];
              _sampleData.forEach((key, val) {
                text = text.replaceAll('[$key]', val).replaceAll('{{$key}}', val);
              });
              final newOp = Map<String, dynamic>.from(op);
              newOp['insert'] = text;
              return newOp;
            }
            return op;
          }).toList();

          final contentWidgets = QuillDeltaToPdf.convert(resolvedDelta, font, fontBold, variables: _sampleData, accentColor: accentColor);
          final wrappedWidgets = _selectedStyle == PdfTemplateStyle.premium
              ? [pw.Container(padding: const pw.EdgeInsets.all(20), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: contentWidgets))]
              : contentWidgets;

          final sigBorderColor = _selectedStyle == PdfTemplateStyle.premium ? PdfColors.blueGrey400 : (_selectedStyle == PdfTemplateStyle.modern ? PdfColors.teal400 : PdfColors.grey300);

          return [
            ...wrappedWidgets,
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfSignatureBox("SIGNATURE DU SALARIÉ", "Mention 'Lu et Approuvé' :", fontBold, font, accentColor, sigBorderColor),
                pw.SizedBox(width: 20),
                _buildPdfSignatureBox("POUR L'EMPLOYEUR / LA DIRECTION", "Signature et Cachet :", fontBold, font, accentColor, sigBorderColor),
              ],
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  pw.Widget _buildPdfHeader(pw.Font font, pw.Font fontBold, PdfColor accentColor, String shopName, String shopSlogan, String shopAddress, String shopPhone, pw.MemoryImage? logoImage) {
    if (_selectedStyle == PdfTemplateStyle.minimalist) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (_showLogo && logoImage != null)
                    pw.Container(width: 35, height: 35, margin: const pw.EdgeInsets.only(right: 8), child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black)),
                      if (_showSlogan && shopSlogan.isNotEmpty) pw.Text(shopSlogan, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
                      if (_showAddress || _showContact)
                        pw.Text(
                          "${_showAddress ? shopAddress : ''}${(_showAddress && _showContact && shopPhone.isNotEmpty) ? ' | ' : ''}${(_showContact && shopPhone.isNotEmpty) ? 'Tél: $shopPhone' : ''}",
                          style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)
                        ),
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
    }

    if (_selectedStyle == PdfTemplateStyle.premium) {
      return pw.Column(
        children: [
          if (_showLogo) ...[
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
          ],
          pw.Text(shopName.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 15, color: accentColor, letterSpacing: 1.5)),
          if (_showSlogan && shopSlogan.isNotEmpty) pw.Text(shopSlogan, style: pw.TextStyle(font: font, fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
          if (_showAddress || _showContact)
            pw.Text(
              "${_showAddress ? shopAddress : ''}${(_showAddress && _showContact && shopPhone.isNotEmpty) ? ' | ' : ''}${(_showContact && shopPhone.isNotEmpty) ? 'Tél: $shopPhone' : ''}",
              style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)
            ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1, color: accentColor),
          pw.SizedBox(height: 1),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
        ],
      );
    }

    if (_selectedStyle == PdfTemplateStyle.executive) {
      final goldColor = PdfColor.fromHex("#c5a880");
      return pw.Column(
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
                    pw.Text(shopName.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white, letterSpacing: 1)),
                    if (_showSlogan && shopSlogan.isNotEmpty) pw.Text(shopSlogan, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey200)),
                    pw.SizedBox(height: 4),
                    if (_showAddress) pw.Text(shopAddress, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey300)),
                    if (_showContact && shopPhone.isNotEmpty) pw.Text("Tél: $shopPhone", style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey300)),
                  ],
                ),
                if (_showLogo) ...[
                  if (logoImage != null)
                    pw.Container(width: 45, height: 45, padding: const pw.EdgeInsets.all(2), decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Image(logoImage, fit: pw.BoxFit.contain))
                  else
                    pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: goldColor, width: 1.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text("ELITE", style: pw.TextStyle(color: goldColor, fontSize: 9, font: fontBold))),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 15),
        ],
      );
    }

    if (_selectedStyle == PdfTemplateStyle.modern || _selectedStyle == PdfTemplateStyle.tech) {
      return pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (_showLogo) ...[
                if (logoImage != null) pw.Container(width: 45, height: 45, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
                else pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: accentColor, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text("ELITE GRH", style: pw.TextStyle(color: accentColor, fontSize: 8, font: fontBold))),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(shopName.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 14, color: accentColor)),
                  if (_showSlogan && shopSlogan.isNotEmpty) pw.Text(shopSlogan, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  if (_showAddress || _showContact)
                    pw.Text(
                      "${_showAddress ? shopAddress : ''}${(_showAddress && _showContact && shopPhone.isNotEmpty) ? ' | ' : ''}${(_showContact && shopPhone.isNotEmpty) ? 'Tél: $shopPhone' : ''}",
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 3, color: accentColor),
          pw.SizedBox(height: 12),
        ],
      );
    }

    // Default standard
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopName.toUpperCase(), style: pw.TextStyle(font: fontBold, fontSize: 16, color: accentColor)),
                if (_showSlogan && shopSlogan.isNotEmpty) pw.Text(shopSlogan, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                if (_showAddress || _showContact)
                  pw.Text(
                    "${_showAddress ? shopAddress : ''}${(_showAddress && _showContact && shopPhone.isNotEmpty) ? ' | ' : ''}${(_showContact && shopPhone.isNotEmpty) ? 'Tél: $shopPhone' : ''}",
                    style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)
                  ),
              ],
            ),
            if (_showLogo) ...[
              if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              else pw.Container(padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(color: accentColor, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text("ELITE GRH", style: pw.TextStyle(color: accentColor, fontSize: 8, font: fontBold))),
            ],
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5, color: accentColor),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Font font, pw.Font fontBold, PdfColor accentColor, String shopName, String shopAddress, String shopPhone, String shopEmail, String shopRc, String shopNif, pw.Context context) {
    final curYear = DateTime.now().year;
    
    if (_selectedStyle == PdfTemplateStyle.minimalist) {
      String minimalFooterText = shopName;
      if (_showContact) minimalFooterText += " | Tél: $shopPhone | Email: $shopEmail";
      if (_showLegal) minimalFooterText += " | RC: ${shopRc.isNotEmpty ? shopRc : 'N/A'} | NIF: ${shopNif.isNotEmpty ? shopNif : 'N/A'}";

      return pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(minimalFooterText, style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600)),
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
                pw.Text("Paraphes :", style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Container(width: 60, height: 20, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5))),
              ],
            ),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    "$shopName${_showAddress ? ' - $shopAddress' : ''}", 
                    style: pw.TextStyle(font: fontBold, fontSize: 8)
                  ),
                  if (_showContact)
                    pw.Text("Tél: $shopPhone | Email: $shopEmail", style: pw.TextStyle(font: font, fontSize: 7)),
                  if (_showLegal)
                    pw.Text("RC: ${shopRc.isNotEmpty ? shopRc : 'En cours'} | NIF: ${shopNif.isNotEmpty ? shopNif : 'En cours'}", style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                  if (_selectedStyle == PdfTemplateStyle.premium) ...[pw.SizedBox(height: 2), pw.Text("DOCUMENT CONFIDENTIEL ET STRICTEMENT PRIVÉ", style: pw.TextStyle(font: fontBold, fontSize: 6, color: PdfColors.red800))],
                  pw.SizedBox(height: 2),
                  pw.Text("© $curYear $shopName - Généré par Danaya+ Pro Elite", style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey500)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [pw.Text("Page ${context.pageNumber}/${context.pagesCount}", style: pw.TextStyle(font: font, fontSize: 8))],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfSignatureBox(String title, String subtitle, pw.Font fontBold, pw.Font font, PdfColor accentColor, PdfColor borderColor) {
    return pw.Expanded(
      child: pw.Container(
        height: 80,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 0.5), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8, color: accentColor)),
            pw.Spacer(),
            pw.Text(subtitle, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey500)),
          ],
        ),
      ),
    );
  }

  void _printPreview(ShopSettings? settings) async {
    final bytes = await _generatePdfPreview(PdfPageFormat.a4, settings);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: _nameCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final isPerso = _selectedTemplateKey == null || _selectedTemplateKey!.startsWith("P:");
    _quillController.readOnly = !isPerso;

    final settings = ref.watch(shopSettingsProvider).value;
    if (settings != null) {
      if (_sampleData['BOUTIQUE'] == 'DANAYA PLUS SARL') { _sampleData['BOUTIQUE'] = settings.name; _sampleControllers['BOUTIQUE']?.text = settings.name; }
      if (_sampleData['ADRESSE'] == 'ACI 2000, Bamako, Mali') { _sampleData['ADRESSE'] = settings.address; _sampleControllers['ADRESSE']?.text = settings.address; }
      if (_sampleData['DEVISE'] == 'FCFA') { _sampleData['DEVISE'] = settings.currency; _sampleControllers['DEVISE']?.text = settings.currency; }
    }

    final templatesState = ref.watch(templatesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c, isPerso, settings),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(c, templatesState),
                  _buildEditorCanvas(c, isPerso, settings),
                  _buildVariablesPanel(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DashColors c, bool isPerso, ShopSettings? settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(FluentIcons.arrow_left_24_regular)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Modèles Administratifs (Pro)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text("Éditeur de documents simplifiés & Impression PDF", style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),
          const Spacer(),
          if (isPerso) ...[
            if (_selectedTemplateKey != null) ...[
              OutlinedButton.icon(
                onPressed: _deleteTemplate,
                icon: const Icon(FluentIcons.delete_20_regular, color: Colors.red, size: 16),
                label: const Text("Supprimer", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(width: 12),
            ],
            FilledButton.icon(
              onPressed: _saveTemplate,
              icon: const Icon(FluentIcons.save_20_regular),
              label: const Text("Enregistrer le modèle", style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(backgroundColor: c.blue, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _duplicateTemplate,
              icon: const Icon(FluentIcons.copy_20_regular, size: 16),
              label: const Text("Dupliquer pour éditer", style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _printPreview(settings),
            icon: const Icon(FluentIcons.print_24_regular),
            label: const Text("Imprimer / PDF", style: TextStyle(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(backgroundColor: Colors.purple.shade600, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(DashColors c, AsyncValue<List<Map<String, dynamic>>> templatesState) {
    return Container(
      width: 320,
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c.blue, c.blue.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: c.blue.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: FilledButton.icon(
                onPressed: _createNewTemplate,
                icon: const Icon(FluentIcons.add_16_regular),
                label: const Text("Nouveau modèle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _sidebarSearchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Rechercher un modèle...",
                hintStyle: TextStyle(color: c.textMuted, fontSize: 12),
                prefixIcon: Icon(FluentIcons.search_20_regular, color: c.textSecondary, size: 16),
                filled: true,
                fillColor: c.surfaceElev,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.blue)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: templatesState.when(
              data: (templates) {
                final q = _sidebarSearchCtrl.text.toLowerCase();
                final filtered = q.isEmpty ? templates : templates.where((t) => (t['title'] as String).toLowerCase().contains(q)).toList();
                
                // Select first item if nothing is selected yet
                if (_selectedTemplateKey == null && templates.isNotEmpty && _nameCtrl.text.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _selectTemplate(templates.first['id'] as String, templates);
                  });
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    if (filtered.any((t) => t['is_system'] == 0)) ...[
                      _buildGroupHeader("MES MODÈLES SUR MESURE", c),
                      ...filtered.where((t) => t['is_system'] == 0).map((t) => _buildTemplateTile(t['id'] as String, t['title'] as String, true, c, templates)),
                      const SizedBox(height: 16),
                    ],
                    _buildGroupHeader("MODÈLES STANDARDS PRO", c),
                    ...filtered.where((t) => t['is_system'] == 1).map((t) => _buildTemplateTile(t['id'] as String, t['title'] as String, false, c, templates)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Erreur: \$e")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCanvas(DashColors c, bool isPerso, ShopSettings? settings) {
    return Expanded(
      child: Container(
        color: const Color(0xFFE8E8E8), // Word-like grey canvas background
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Mode Toggle Bar (compact) ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(bottom: BorderSide(color: c.border)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // Mode Switch
                  Container(
                    decoration: BoxDecoration(
                      color: c.surfaceElev,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeTab("Éditeur", FluentIcons.document_edit_16_regular, _isEditingMode, c, () => setState(() => _isEditingMode = true)),
                        _buildModeTab("Aperçu PDF", FluentIcons.document_pdf_16_regular, !_isEditingMode, c, () => setState(() => _isEditingMode = false)),
                      ],
                    ),
                  ),
                  if (!_isEditingMode) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.surfaceElev,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PdfTemplateStyle>(
                          value: _selectedStyle,
                          isDense: true,
                          icon: Icon(FluentIcons.chevron_down_12_regular, size: 12, color: c.textSecondary),
                          items: const [
                            DropdownMenuItem(value: PdfTemplateStyle.standard, child: Text("Standard (Bleu)")),
                            DropdownMenuItem(value: PdfTemplateStyle.premium, child: Text("Premium")),
                            DropdownMenuItem(value: PdfTemplateStyle.modern, child: Text("Moderne (Cyan)")),
                            DropdownMenuItem(value: PdfTemplateStyle.executive, child: Text("Executive")),
                            DropdownMenuItem(value: PdfTemplateStyle.heritage, child: Text("Héritage")),
                            DropdownMenuItem(value: PdfTemplateStyle.elegant, child: Text("Élégant")),
                            DropdownMenuItem(value: PdfTemplateStyle.tech, child: Text("Tech")),
                            DropdownMenuItem(value: PdfTemplateStyle.terracotta, child: Text("Terracotta")),
                            DropdownMenuItem(value: PdfTemplateStyle.royal, child: Text("Royal")),
                            DropdownMenuItem(value: PdfTemplateStyle.minimalist, child: Text("Minimaliste")),
                          ],
                          onChanged: (val) { if (val != null) setState(() => _selectedStyle = val); },
                          style: TextStyle(fontSize: 11, color: c.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(height: 24, width: 1, color: c.border),
                    const SizedBox(width: 16),
                    _buildToggleCheckbox("Logo", _showLogo, (v) => setState(() => _showLogo = v!)),
                    _buildToggleCheckbox("Slogan", _showSlogan, (v) => setState(() => _showSlogan = v!)),
                    _buildToggleCheckbox("Adresse", _showAddress, (v) => setState(() => _showAddress = v!)),
                    _buildToggleCheckbox("Contacts", _showContact, (v) => setState(() => _showContact = v!)),
                    _buildToggleCheckbox("RC/NIF", _showLegal, (v) => setState(() => _showLegal = v!)),
                  ],
                  const Spacer(),
                  if (_isEditingMode)
                    Text("Nom du document :", style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  if (_isEditingMode)
                    const SizedBox(width: 8),
                  if (_isEditingMode)
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _nameCtrl,
                        enabled: isPerso,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Titre du modèle...",
                          isDense: true,
                          filled: true,
                          fillColor: c.surfaceElev,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.blue, width: 1.5)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Toolbar (Word-like ribbon) ──
            if (_isEditingMode && isPerso)
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(size: 16),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: quill.QuillSimpleToolbar(
                        controller: _quillController,
                        config: quill.QuillSimpleToolbarConfig(
                          showFontFamily: false,
                          showFontSize: false,
                          showHeaderStyle: true,
                          showBoldButton: true,
                          showItalicButton: true,
                          showUnderLineButton: true,
                          showStrikeThrough: false,
                          showColorButton: false,
                          showBackgroundColorButton: false,
                          showListNumbers: true,
                          showListBullets: true,
                          showQuote: false,
                          showIndent: true,
                          showLink: false,
                          showAlignmentButtons: true,
                          showSearchButton: false,
                          showCodeBlock: false,
                          showInlineCode: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showDirection: false,
                          showClipboardCut: false,
                          showClipboardCopy: false,
                          showClipboardPaste: false,
                          buttonOptions: const quill.QuillSimpleToolbarButtonOptions(),
                          multiRowsDisplay: false,
                          toolbarSize: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── PDF Preview or Editor Canvas ──
            if (!_isEditingMode)
              Expanded(
                child: PdfPreview(
                  build: (format) => _generatePdfPreview(format, settings),
                  allowPrinting: true, allowSharing: true, canChangePageFormat: false, canChangeOrientation: false, pdfFileName: "${_nameCtrl.text}.pdf",
                ),
              )
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth - 48; // padding
                    double pageWidth = availableWidth.clamp(400, 850).toDouble();
                    double pageHeight = pageWidth / 0.707; // A4 ratio

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                      child: Center(
                        child: Column(
                          children: [
                            // The A4 page (scaled to fit screen, keeping ratio)
                            Container(
                              width: pageWidth,
                              constraints: BoxConstraints(minHeight: pageHeight),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(height: 1, color: c.blue.withValues(alpha: 0.15)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: pageWidth * 0.1,  // 10% horizontal margin
                                        vertical: pageWidth * 0.08,   // 8% vertical margin
                                      ),
                                      child: quill.QuillEditor.basic(
                                        controller: _quillController,
                                        focusNode: _editorFocusNode,
                                        config: quill.QuillEditorConfig(
                                          padding: EdgeInsets.zero,
                                          autoFocus: false,
                                          expands: false,
                                          scrollable: false,
                                          customStyles: quill.DefaultStyles(
                                            paragraph: quill.DefaultTextBlockStyle(
                                              TextStyle(fontSize: 12, height: 1.5, color: Colors.grey.shade900, fontFamily: 'Inter'),
                                              const quill.HorizontalSpacing(0, 0),
                                              const quill.VerticalSpacing(3, 3),
                                              const quill.VerticalSpacing(0, 0),
                                              null,
                                            ),
                                            h1: quill.DefaultTextBlockStyle(
                                              TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.25, color: Colors.grey.shade900, letterSpacing: -0.2),
                                              const quill.HorizontalSpacing(0, 0),
                                              const quill.VerticalSpacing(10, 5),
                                              const quill.VerticalSpacing(0, 0),
                                              null,
                                            ),
                                            h2: quill.DefaultTextBlockStyle(
                                              TextStyle(fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, height: 1.3, color: Colors.grey.shade800),
                                              const quill.HorizontalSpacing(0, 0),
                                              const quill.VerticalSpacing(8, 4),
                                              const quill.VerticalSpacing(0, 0),
                                              null,
                                            ),
                                            h3: quill.DefaultTextBlockStyle(
                                              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.35, color: Colors.grey.shade700),
                                              const quill.HorizontalSpacing(0, 0),
                                              const quill.VerticalSpacing(6, 3),
                                              const quill.VerticalSpacing(0, 0),
                                              null,
                                            ),
                                            bold: const TextStyle(fontWeight: FontWeight.w700),
                                            italic: const TextStyle(fontStyle: FontStyle.italic),
                                            underline: const TextStyle(decoration: TextDecoration.underline),
                                            lists: quill.DefaultListBlockStyle(
                                              TextStyle(fontSize: 9.5, height: 1.5, color: Colors.grey.shade900),
                                              const quill.HorizontalSpacing(0, 0),
                                              const quill.VerticalSpacing(2, 2),
                                              const quill.VerticalSpacing(0, 0),
                                              null, null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Page footer indicator
                            const SizedBox(height: 8),
                            Text("Page 1", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    final c = DashColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: c.blue,
              side: BorderSide(color: c.border, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, IconData icon, bool isActive, DashColors c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? c.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : c.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? Colors.white : c.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildVariablesPanel(DashColors c) {
    return Container(
      width: 300,
      decoration: BoxDecoration(color: c.surface, border: Border(left: BorderSide(color: c.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.blue.withValues(alpha: 0.15), c.blue.withValues(alpha: 0.05)]),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.tag_24_regular, color: c.blue),
                const SizedBox(width: 8),
                const Expanded(child: Text("Variables du Modèle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("Cliquez sur une variable pour l'insérer dans votre texte à la position du curseur :", style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.4)),
                const SizedBox(height: 16),
                ..._variables.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _insertVariable(v['code']!),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.blue.withValues(alpha: 0.25))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.add_12_filled, size: 10, color: c.blue),
                                const SizedBox(width: 4),
                                Text(v['code']!, style: TextStyle(color: c.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _getSampleController(v['code']!.replaceAll('[', '').replaceAll(']', '')),
                        decoration: InputDecoration(
                          labelText: v['label'],
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.blue)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          labelStyle: const TextStyle(fontSize: 11),
                        ),
                        style: TextStyle(fontSize: 13, color: c.textPrimary),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, DashColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 8),
      child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.textMuted, letterSpacing: 1.3)),
    );
  }

  Widget _buildTemplateTile(String id, String title, bool isPerso, DashColors c, List<Map<String, dynamic>> templates) {
    final isSelected = id == _selectedTemplateKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? c.blue.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? c.blue.withValues(alpha: 0.25) : Colors.transparent),
      ),
      child: Stack(
        children: [
          ListTile(
            onTap: () => _selectTemplate(id, templates),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: isSelected ? c.blue.withValues(alpha: 0.1) : c.surfaceElev, shape: BoxShape.circle),
              child: Icon(isPerso ? FluentIcons.document_edit_24_regular : FluentIcons.document_24_regular, color: isSelected ? c.blue : c.textSecondary, size: 18),
            ),
            title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? c.blue : c.textPrimary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: !isPerso ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text("PRO", style: TextStyle(color: c.blue, fontSize: 8, fontWeight: FontWeight.bold))) : null,
          ),
          if (isSelected) Positioned(left: 0, top: 12, bottom: 12, child: Container(width: 4, decoration: BoxDecoration(color: c.blue, borderRadius: const BorderRadius.only(topRight: Radius.circular(2), bottomRight: Radius.circular(2))))),
        ],
      ),
    );
  }
}
