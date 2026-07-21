import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';
import 'package:danaya_plus/features/srm/application/purchase_pdf_service.dart';
import 'package:danaya_plus/core/services/email_templates.dart';

class PurchaseDocPreviewDialog extends ConsumerStatefulWidget {
  final PurchasePdfData pdfData;

  const PurchaseDocPreviewDialog({super.key, required this.pdfData});

  @override
  ConsumerState<PurchaseDocPreviewDialog> createState() => _PurchaseDocPreviewDialogState();
}

class _PurchaseDocPreviewDialogState extends ConsumerState<PurchaseDocPreviewDialog> {
  late PurchaseOrderTemplate _selectedTemplate;
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.pdfData.settings.defaultPurchaseOrder;
  }

  Future<void> _sendEmail() async {
    final emailCtrl = TextEditingController(text: widget.pdfData.supplier.email);
    
    String? selectedEmailTemplate = 'modern';
    
    final resultList = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => EnterpriseWidgets.buildPremiumDialog(
          context,
          title: "Envoyer par Email",
          icon: FluentIcons.mail_24_regular,
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Veuillez confirmer ou saisir l'adresse e-mail du fournisseur :",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: emailCtrl,
                label: "ADRESSE E-MAIL DU FOURNISSEUR",
                hint: "Ex: contact@fournisseur.com",
                icon: FluentIcons.mail_24_regular,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              const Text(
                "Modèle d'Email :",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedEmailTemplate,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: EmailTemplates.catalog.map((e) => DropdownMenuItem(
                  value: e['id'],
                  child: Text(e['name'] ?? ''),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedEmailTemplate = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, [emailCtrl.text.trim(), selectedEmailTemplate!]),
              child: const Text("Confirmer & Envoyer"),
            ),
          ],
        ),
      ),
    );

    if (resultList == null || resultList[0].isEmpty) return;
    
    final targetEmail = resultList[0];
    final targetTemplate = resultList[1];

    setState(() => _isSendingEmail = true);

    try {
      final updatedData = PurchasePdfData(
        order: widget.pdfData.order,
        supplier: widget.pdfData.supplier,
        items: widget.pdfData.items,
        settings: widget.pdfData.settings.copyWith(defaultPurchaseOrder: _selectedTemplate),
      );

      final doc = await PurchasePdfService.build(updatedData);
      final bytes = await doc.save();
      
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Bon_Commande_${widget.pdfData.order.reference}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final emailService = EmailService(widget.pdfData.settings);
      
      final result = await emailService.sendPurchaseOrder(
        recipient: targetEmail,
        poNumber: widget.pdfData.order.reference,
        supplierName: widget.pdfData.supplier.name,
        pdfFile: file,
        emailTemplateId: targetTemplate,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bon de commande envoyé avec succès !"), backgroundColor: Colors.green),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Erreur d'envoi"),
              content: Text(result.errorMessage ?? "Erreur inconnue."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final updatedData = PurchasePdfData(
      order: widget.pdfData.order,
      supplier: widget.pdfData.supplier,
      items: widget.pdfData.items,
      settings: widget.pdfData.settings.copyWith(defaultPurchaseOrder: _selectedTemplate),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1000,
        height: 800,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            // HEADER BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(FluentIcons.document_pdf_24_regular, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Aperçu du Bon de Commande", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("Réf: ${widget.pdfData.order.reference}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  // TOP ACTIONS
                  _buildHeaderAction(
                    FluentIcons.mail_20_regular, 
                    "Envoyer par Email", 
                    _sendEmail, 
                    Colors.orange, 
                    isLoading: _isSendingEmail
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderAction(
                    FluentIcons.print_20_regular, 
                    "Imprimer", 
                    () => PurchasePdfService.generateAndPrint(updatedData), 
                    theme.colorScheme.primary
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(FluentIcons.dismiss_20_regular),
                    tooltip: "Fermer",
                  ),
                ],
              ),
            ),
            
            // MAIN CONTENT
            Expanded(
              child: Row(
                children: [
                  // SETTINGS SIDEBAR
                  Container(
                    width: 250,
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                      border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("MODÈLE DE DOCUMENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 12),
                        ...PurchaseOrderTemplate.values.map((tpl) => _buildTemplateCard(tpl, theme, isDark)),
                      ],
                    ),
                  ),
                  
                  // PDF VIEWER
                  Expanded(
                    child: PdfPreview(
                      build: (format) async {
                        final doc = await PurchasePdfService.build(updatedData);
                        return doc.save();
                      },
                      allowPrinting: true,
                      allowSharing: true,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      shouldRepaint: true,
                      pdfFileName: "Bon_Commande_${widget.pdfData.order.reference}.pdf",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(PurchaseOrderTemplate tpl, ThemeData theme, bool isDark) {
    final isSelected = _selectedTemplate == tpl;
    return InkWell(
      onTap: () => setState(() => _selectedTemplate = tpl),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.1) 
            : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? FluentIcons.checkmark_circle_20_filled : FluentIcons.circle_20_regular,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              tpl.name.toUpperCase(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white : Colors.black87),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String label, VoidCallback onTap, Color color, {bool isLoading = false}) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading 
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
