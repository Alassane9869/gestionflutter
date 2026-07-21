import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/features/hr/domain/models/payroll.dart';
import 'package:danaya_plus/features/hr/services/hr_pdf_service.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';
import 'package:flutter/services.dart';
import 'package:danaya_plus/core/services/whatsapp_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HrDocViewer extends ConsumerStatefulWidget {
  final User employee;
  final EmployeeContract? contract;
  final Payroll? payroll;
  final String initialType; // "contract", "payroll", "attestation"

  const HrDocViewer({
    super.key,
    required this.employee,
    this.contract,
    this.payroll,
    required this.initialType,
  });

  @override
  ConsumerState<HrDocViewer> createState() => _HrDocViewerState();
}

class _HrDocViewerState extends ConsumerState<HrDocViewer> {
  late String _currentType;
  bool _isSendingEmail = false;
  bool _isSendingWhatsapp = false;
  PdfTemplateStyle _selectedStyle = PdfTemplateStyle.standard;
  int _printCopies = 1;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
  }

  Future<Uint8List> _buildCurrentDocBytes() async {
    final settings = ref.read(shopSettingsProvider).value ?? const ShopSettings();
    final service = HrPdfService();

    if (_currentType == "contract" && widget.contract != null) {
      return service.generateContractPdfBytes(widget.employee, widget.contract!, _selectedStyle, settings);
    } else if (_currentType == "payroll" && widget.payroll != null) {
      return service.generatePayrollPdfBytes(widget.employee, widget.payroll!, _selectedStyle, settings);
    } else if (_currentType == "passation") {
      return service.generatePassationPdfBytes(widget.employee, widget.contract, _selectedStyle, settings);
    } else {
      return service.generateAttestationPdfBytes(widget.employee, widget.contract, _selectedStyle, settings);
    }
  }

  String _getFileName() {
    final name = widget.employee.fullName.replaceAll(' ', '_');
    if (_currentType == "contract") {
      return "Contrat_$name.pdf";
    } else if (_currentType == "payroll" && widget.payroll != null) {
      return "Bulletin_${name}_${widget.payroll!.periodLabel}.pdf";
    } else if (_currentType == "passation") {
      return "Passation_$name.pdf";
    } else {
      return "Attestation_$name.pdf";
    }
  }

  Future<void> _sendEmail() async {
    final emailCtrl = TextEditingController(text: widget.employee.email ?? '');
    
    final targetEmail = await showDialog<String>(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Envoyer par Email",
        icon: FluentIcons.mail_24_regular,
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Veuillez confirmer l'adresse e-mail de l'employé :",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: emailCtrl,
              label: "ADRESSE E-MAIL",
              hint: "Ex: employe@domain.com",
              icon: FluentIcons.mail_24_regular,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(onPressed: () => Navigator.pop(context, emailCtrl.text.trim()), child: const Text("Confirmer & Envoyer")),
        ],
      ),
    );

    if (targetEmail == null || targetEmail.isEmpty) return;

    setState(() => _isSendingEmail = true);

    try {
      final bytes = await _buildCurrentDocBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${_getFileName()}');
      await file.writeAsBytes(bytes);

      final emailService = ref.read(emailServiceProvider);
      
      String subject = "Document RH - ${widget.employee.fullName}";
      String body = "Bonjour ${widget.employee.fullName},\n\nVeuillez trouver ci-joint votre document RH.\n\nCordialement,";
      
      if (_currentType == "contract") {
        subject = "Votre Contrat de Travail";
      } else if (_currentType == "payroll") {
        subject = "Votre Bulletin de Paie - ${widget.payroll!.periodLabel}";
      } else if (_currentType == "passation") {
        subject = "Procès-verbal de Passation de Service";
      } else if (_currentType == "attestation") {
        subject = "Votre Attestation";
      }

      final result = await emailService.sendProfessionalEmail(
        recipient: targetEmail,
        subject: subject,
        message: body,
        attachments: [file],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? "Email envoyé avec succès !" : "Échec : ${result.errorMessage}"),
            backgroundColor: result.success ? Colors.green.shade600 : Colors.red,
          ),
        );
      }
      
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'envoi : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  Future<void> _sendWhatsApp() async {
    String? targetPhone = widget.employee.phone;

    if (targetPhone == null || targetPhone.trim().isEmpty) {
      final phoneCtrl = TextEditingController();
      
      targetPhone = await showDialog<String>(
        context: context,
        builder: (context) => EnterpriseWidgets.buildPremiumDialog(
          context,
          title: "Envoyer par WhatsApp",
          icon: FontAwesomeIcons.whatsapp,
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "L'employé n'a pas de numéro enregistré. Veuillez le saisir :",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: phoneCtrl,
                label: "NUMÉRO DE TÉLÉPHONE (WHATSAPP)",
                hint: "Ex: 76000000 ou 22376000000",
                icon: FontAwesomeIcons.whatsapp,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, phoneCtrl.text.trim()),
              child: const Text("Confirmer"),
            ),
          ],
        ),
      );
    }

    if (targetPhone == null || targetPhone.isEmpty) return;

    setState(() => _isSendingWhatsapp = true);

    try {
      final cleanPhone = targetPhone.replaceAll(RegExp(r'[^\d]'), '');
      String finalPhone = cleanPhone;
      if (cleanPhone.length == 8) {
        finalPhone = '223$cleanPhone'; // Préfixe Mali par défaut
      }

      final settings = ref.read(shopSettingsProvider).value;
      final whatsappService = ref.read(whatsappServiceProvider);
      final String shopName = settings?.name ?? "Danaya+";

      final bytes = await _buildCurrentDocBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${_getFileName()}');
      await file.writeAsBytes(bytes);

      String docTypeLabel = "votre document RH";
      if (_currentType == "contract") {
        docTypeLabel = "votre Contrat de Travail";
      } else if (_currentType == "payroll") {
        docTypeLabel = "votre Bulletin de Paie";
      } else if (_currentType == "attestation") {
        docTypeLabel = "votre Attestation";
      }

      final String message = "Bonjour ${widget.employee.firstName ?? widget.employee.fullName}, voici $docTypeLabel venant de $shopName.";
      
      final success = await whatsappService.openWhatsAppDirectly(
        phone: finalPhone,
        message: message,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir WhatsApp sur cet appareil."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur WhatsApp : $e"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingWhatsapp = false);
    }
  }

  Future<void> _shareDoc() async {
    try {
      final bytes = await _buildCurrentDocBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${_getFileName()}');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _getFileName().replaceAll('.pdf', ''),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du partage : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDocTab(String label, String type, ThemeData theme, bool isDark) {
    final isSelected = _currentType == type;
    return InkWell(
      onTap: () => setState(() => _currentType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String label, VoidCallback onTap, Color color, {bool isLoading = false}) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
            else
              Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showStyleSelector() {
    final styleLabels = {
      PdfTemplateStyle.standard: "Élite Corporate",
      PdfTemplateStyle.premium: "Élite Premium",
      PdfTemplateStyle.modern: "Élite Moderne",
      PdfTemplateStyle.executive: "Élite Executive",
      PdfTemplateStyle.heritage: "Élite Héritage",
      PdfTemplateStyle.elegant: "Élite Élégant",
      PdfTemplateStyle.tech: "Élite Tech",
      PdfTemplateStyle.terracotta: "Élite Terracotta",
      PdfTemplateStyle.royal: "Élite Royal",
      PdfTemplateStyle.minimalist: "Élite Minimaliste",
    };

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: theme.colorScheme.surface,
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 500),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: PdfTemplateStyle.values.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final style = PdfTemplateStyle.values[index];
                return ListTile(
                  title: Text(styleLabels[style] ?? style.name, style: const TextStyle(fontSize: 14)),
                  trailing: _selectedStyle == style ? Icon(FluentIcons.checkmark_20_regular, color: theme.colorScheme.primary) : null,
                  onTap: () {
                    setState(() => _selectedStyle = style);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1000,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))
          ],
        ),
        child: Column(
          children: [
            // ─── HEADER ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(FluentIcons.document_pdf_24_regular, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Aperçu du Document", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text("Employé: ${widget.employee.fullName}", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    ],
                  ),
                  const Spacer(),
                  _buildHeaderAction(FluentIcons.mail_20_regular, "Email", _sendEmail, Colors.orange, isLoading: _isSendingEmail),
                  _buildHeaderAction(FontAwesomeIcons.whatsapp, "WhatsApp", _sendWhatsApp, Colors.green, isLoading: _isSendingWhatsapp),
                  _buildHeaderAction(FluentIcons.share_20_regular, "Partager", _shareDoc, theme.colorScheme.primary),
                  Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                  
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (_printCopies > 1) setState(() => _printCopies--);
                        },
                        child: Icon(FluentIcons.subtract_16_regular, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text("$_printCopies", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      ),
                      InkWell(
                        onTap: () => setState(() => _printCopies++),
                        child: Icon(FluentIcons.add_16_regular, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  _buildHeaderAction(FluentIcons.print_20_regular, "Imprimer", () async {
                    final bytes = await _buildCurrentDocBytes();
                    final settings = ref.read(shopSettingsProvider).value ?? const ShopSettings();
                    
                    if (settings.directPhysicalPrinting) {
                      for (int i = 0; i < _printCopies; i++) {
                        await PrintingHelper.printBytesWithFallback(
                          bytes: bytes,
                          targetPrinterName: _currentType == "contract" ? settings.contractPrinterName : settings.payrollPrinterName,
                          directPrint: true,
                          jobName: "${_getFileName()}_copy_$i",
                        );
                        if (i < _printCopies - 1) await Future.delayed(const Duration(milliseconds: 500));
                      }
                    } else {
                      await PrintingHelper.printBytesWithFallback(
                        bytes: bytes,
                        targetPrinterName: _currentType == "contract" ? settings.contractPrinterName : settings.payrollPrinterName,
                        directPrint: false,
                        jobName: _getFileName(),
                      );
                    }
                  }, theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(FluentIcons.dismiss_24_regular, color: Colors.grey.shade500, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─── TABS + STYLE SELECTOR ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.contract != null) _buildDocTab("CONTRAT", "contract", theme, isDark),
                        if (widget.payroll != null) _buildDocTab("BULLETIN PAIE", "payroll", theme, isDark),
                        _buildDocTab("ATTESTATION", "attestation", theme, isDark),
                        _buildDocTab("PASSATION", "passation", theme, isDark),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _showStyleSelector,
                    icon: const Icon(FluentIcons.paint_brush_16_regular, size: 16),
                    label: Text("Style: ${_selectedStyle.name.toUpperCase()}"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─── APERÇU PDF ───
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF0A0A0C) : Colors.grey.shade200,
                child: FutureBuilder<Uint8List>(
                  key: ValueKey("$_currentType-$_selectedStyle"), 
                  future: _buildCurrentDocBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                            const SizedBox(height: 12),
                            Text("GÉNÉRATION DU DOCUMENT...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: theme.colorScheme.primary)),
                          ],
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Erreur technique : ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 12)));
                    }
                    
                    return PdfPreview(
                      build: (format) async => snapshot.data!,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      scrollViewDecoration: const BoxDecoration(color: Colors.transparent),
                      pdfPreviewPageDecoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
