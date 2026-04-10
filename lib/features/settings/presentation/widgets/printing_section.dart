import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/services/pdf_resource_service.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';
import '../../providers/shop_settings_provider.dart';
import '../../../pos/services/receipt_service.dart';
import '../../../pos/services/invoice_service.dart';
import '../../../pos/services/quote_service.dart';
import '../../../inventory/application/inventory_automation_service.dart';
import '../../domain/models/shop_settings_models.dart';

class PrintingSettingsSection extends StatefulWidget {
  final ReceiptTemplate? receipt;
  final ValueChanged<ReceiptTemplate?> onReceiptChanged;
  final InvoiceTemplate? invoice;
  final ValueChanged<InvoiceTemplate?> onInvoiceChanged;
  final QuoteTemplate? quote;
  final ValueChanged<QuoteTemplate?> onQuoteChanged;
  final PurchaseOrderTemplate? purchaseOrder;
  final ValueChanged<PurchaseOrderTemplate?> onPurchaseOrderChanged;
  final TextEditingController receiptFooterCtrl;
  
  final TextEditingController titleInvoiceCtrl;
  final TextEditingController titleReceiptCtrl;
  final TextEditingController titleQuoteCtrl;
  final TextEditingController titleProformaCtrl;
  final TextEditingController titleDeliveryNoteCtrl;

  final bool showQrCode;
  final ValueChanged<bool> onShowQrCodeChanged;
  final bool directPhysicalPrinting;
  final ValueChanged<bool> onDirectPhysicalPrintingChanged;
  final bool autoPrintTicket;
  final ValueChanged<bool> onAutoPrintTicketChanged;
  final bool showPreviewBeforePrint;
  final ValueChanged<bool> onShowPreviewBeforePrintChanged;
  
  final String? thermalPrinter;
  final ValueChanged<String?> onThermalPrinterChanged;
  final String? invoicePrinter;
  final ValueChanged<String?> onInvoicePrinterChanged;
  final String? quotePrinter;
  final ValueChanged<String?> onQuotePrinterChanged;
  final String? purchaseOrderPrinter;
  final ValueChanged<String?> onPurchaseOrderPrinterChanged;
  final String? labelPrinter;
  final ValueChanged<String?> onLabelPrinterChanged;
  final String? reportPrinter;
  final ValueChanged<String?> onReportPrinterChanged;
  
  final List<Printer> availablePrinters;
  final VoidCallback onLoadPrinters;
  
  final LabelPrintingFormat labelFormat;
  final ValueChanged<LabelPrintingFormat?> onLabelFormatChanged;
  final TextEditingController labelWidthCtrl;
  final TextEditingController labelHeightCtrl;
  final bool showNameOnLabels;
  final ValueChanged<bool> onShowNameOnLabelsChanged;
  final bool showPriceOnLabels;
  final ValueChanged<bool> onShowPriceOnLabelsChanged;
  final bool showSkuOnLabels;
  final ValueChanged<bool> onShowSkuOnLabelsChanged;

  final TextEditingController marginTicketTopCtrl;
  final TextEditingController marginTicketBottomCtrl;
  final TextEditingController marginTicketLeftCtrl;
  final TextEditingController marginTicketRightCtrl;
  final TextEditingController marginInvoiceTopCtrl;
  final TextEditingController marginInvoiceBottomCtrl;
  final TextEditingController marginInvoiceLeftCtrl;
  final TextEditingController marginInvoiceRightCtrl;
  final TextEditingController marginLabelXCtrl;
  final TextEditingController marginLabelYCtrl;

  final bool autoPrintDeliveryNote;
  final ValueChanged<bool> onAutoPrintDeliveryNoteChanged;
  final VoidCallback onSaveDebounced;
  final Function(String?, String) onTestPrint;
  
  final bool openCashDrawer;
  final ValueChanged<bool> onOpenCashDrawerChanged;
  final bool enableSounds;
  final ValueChanged<bool> onEnableSoundsChanged;
  final bool enableAppSounds;
  final ValueChanged<bool> onEnableAppSoundsChanged;
  final bool enableCustomerDisplaySounds;
  final ValueChanged<bool> onEnableCustomerDisplaySoundsChanged;
  final bool useCustomerDisplay3D;
  final ValueChanged<bool> onUseCustomerDisplay3DChanged;
  final VoidCallback onTestSound;

  const PrintingSettingsSection({
    super.key,
    required this.receipt,
    required this.onReceiptChanged,
    required this.invoice,
    required this.onInvoiceChanged,
    required this.quote,
    required this.onQuoteChanged,
    required this.purchaseOrder,
    required this.onPurchaseOrderChanged,
    required this.receiptFooterCtrl,
    required this.titleInvoiceCtrl,
    required this.titleReceiptCtrl,
    required this.titleQuoteCtrl,
    required this.titleProformaCtrl,
    required this.titleDeliveryNoteCtrl,
    required this.showQrCode,
    required this.onShowQrCodeChanged,
    required this.directPhysicalPrinting,
    required this.onDirectPhysicalPrintingChanged,
    required this.autoPrintTicket,
    required this.onAutoPrintTicketChanged,
    required this.showPreviewBeforePrint,
    required this.onShowPreviewBeforePrintChanged,
    required this.thermalPrinter,
    required this.onThermalPrinterChanged,
    required this.invoicePrinter,
    required this.onInvoicePrinterChanged,
    required this.quotePrinter,
    required this.onQuotePrinterChanged,
    required this.purchaseOrderPrinter,
    required this.onPurchaseOrderPrinterChanged,
    required this.labelPrinter,
    required this.onLabelPrinterChanged,
    required this.reportPrinter,
    required this.onReportPrinterChanged,
    required this.availablePrinters,
    required this.onLoadPrinters,
    required this.labelFormat,
    required this.onLabelFormatChanged,
    required this.labelWidthCtrl,
    required this.labelHeightCtrl,
    required this.showNameOnLabels,
    required this.onShowNameOnLabelsChanged,
    required this.showPriceOnLabels,
    required this.onShowPriceOnLabelsChanged,
    required this.showSkuOnLabels,
    required this.onShowSkuOnLabelsChanged,
    required this.marginTicketTopCtrl,
    required this.marginTicketBottomCtrl,
    required this.marginTicketLeftCtrl,
    required this.marginTicketRightCtrl,
    required this.marginInvoiceTopCtrl,
    required this.marginInvoiceBottomCtrl,
    required this.marginInvoiceLeftCtrl,
    required this.marginInvoiceRightCtrl,
    required this.marginLabelXCtrl,
    required this.marginLabelYCtrl,
    required this.autoPrintDeliveryNote,
    required this.onAutoPrintDeliveryNoteChanged,
    required this.onSaveDebounced,
    required this.onTestPrint,
    required this.openCashDrawer,
    required this.onOpenCashDrawerChanged,
    required this.enableSounds,
    required this.onEnableSoundsChanged,
    required this.enableAppSounds,
    required this.onEnableAppSoundsChanged,
    required this.enableCustomerDisplaySounds,
    required this.onEnableCustomerDisplaySoundsChanged,
    required this.useCustomerDisplay3D,
    required this.onUseCustomerDisplay3DChanged,
    required this.onTestSound,

    required this.nameCtrl,
    required this.sloganCtrl,
    required this.addressCtrl,
    required this.phoneCtrl,
    required this.logoPath,
  });

  final TextEditingController nameCtrl;
  final TextEditingController sloganCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final String? logoPath;

  @override
  State<PrintingSettingsSection> createState() => _PrintingSettingsSectionState();
}

class _PrintingSettingsSectionState extends State<PrintingSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── BOUTON D'APERÇU FLOTTANT (PREMIUM) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PremiumSettingsWidgets.buildGradientBtn(
              onPressed: () => _showPreviewModal(context, c),
              icon: FluentIcons.eye_tracking_20_filled,
              label: "APERÇU DES DOCUMENTS",
              colors: [c.blue, const Color(0xFF4A90E2)],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── SELECTION DES MODELES ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.document_search_24_filled,
          title: "Modèles & Thèmes",
          subtitle: "Sélection des designs des documents",
          color: c.violet,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              Row(
                children: [
                   Expanded(
                     child: PremiumSettingsWidgets.buildCompactDropdown<ReceiptTemplate>(
                       context,
                       label: "Ticket (Thermique)",
                       value: widget.receipt ?? ReceiptTemplate.values.first,
                       items: ReceiptTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                       onChanged: widget.onReceiptChanged,
                       color: c.violet,
                     ),
                   ),
                   const SizedBox(width: 14),
                   Expanded(
                     child: PremiumSettingsWidgets.buildCompactDropdown<InvoiceTemplate>(
                       context,
                       label: "Facture (A4)",
                       value: widget.invoice ?? InvoiceTemplate.values.first,
                       items: InvoiceTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                       onChanged: widget.onInvoiceChanged,
                       color: c.violet,
                     ),
                   ),
                   const SizedBox(width: 14),
                   Expanded(
                     child: PremiumSettingsWidgets.buildCompactDropdown<QuoteTemplate>(
                       context,
                       label: "Devis (A4)",
                       value: widget.quote ?? QuoteTemplate.values.first,
                       items: QuoteTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                       onChanged: widget.onQuoteChanged,
                       color: c.violet,
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 16),
              PremiumSettingsWidgets.buildInfoBox(
                context,
                text: "Les thèmes s'appliquent immédiatement sur toutes les nouvelles impressions.",
                color: c.violet,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── PERSONNALISATION DES TITRES ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.text_font_24_filled,
          title: "Titres Imprimés",
          subtitle: "Personnalisation du nommage des documents",
          color: c.emerald,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context, controller: widget.titleReceiptCtrl, label: "Titre Ticket", icon: FluentIcons.text_16_regular, hint: "TICKET DE CAISSE", color: c.emerald, onChanged: widget.onSaveDebounced,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context, controller: widget.titleInvoiceCtrl, label: "Titre Facture", icon: FluentIcons.text_16_regular, hint: "FACTURE COMMERCIALE", color: c.emerald, onChanged: widget.onSaveDebounced,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context, controller: widget.titleQuoteCtrl, label: "Titre Devis", icon: FluentIcons.text_16_regular, hint: "DEVIS", color: c.emerald, onChanged: widget.onSaveDebounced,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context, controller: widget.titleProformaCtrl, label: "Titre Proforma", icon: FluentIcons.text_16_regular, hint: "FACTURE PROFORMA", color: c.emerald, onChanged: widget.onSaveDebounced,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context, controller: widget.titleDeliveryNoteCtrl, label: "Titre Livraison", icon: FluentIcons.text_16_regular, hint: "BON DE LIVRAISON", color: c.emerald, onChanged: widget.onSaveDebounced,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context, controller: widget.receiptFooterCtrl, label: "Message de fin (Ticket)", icon: FluentIcons.text_16_regular, hint: "Merci de votre visite !", color: c.emerald, onChanged: widget.onSaveDebounced,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── OPTIONS D'IMPRESSION ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.print_add_24_filled,
          title: "Options d'Impression",
          subtitle: "Règles d'impression automatiques et QR Code",
          color: c.amber,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(context, title: "QR code sur les tickets", subtitle: "Ajoute un QR code de vérification à la fin du ticket", value: widget.showQrCode, onChanged: widget.onShowQrCodeChanged, activeColor: c.amber, icon: FluentIcons.qr_code_24_regular),
              const SizedBox(height: 12),
              PremiumSettingsWidgets.buildCompactSwitch(context, title: "Aperçu avant impression", subtitle: "Affiche le PDF avant d'imprimer", value: widget.showPreviewBeforePrint, onChanged: widget.onShowPreviewBeforePrintChanged, activeColor: c.amber, icon: FluentIcons.eye_24_regular),
              const SizedBox(height: 12),
              PremiumSettingsWidgets.buildCompactSwitch(context, title: "Auto-impression Ticket", subtitle: "Lance l'impression à chaque encaissement", value: widget.autoPrintTicket, onChanged: widget.onAutoPrintTicketChanged, activeColor: c.amber, icon: FluentIcons.receipt_24_regular),
              const SizedBox(height: 12),
              PremiumSettingsWidgets.buildCompactSwitch(context, title: "Auto-impression Livraison", subtitle: "Lance l'impression du bon de livraison automatiquement", value: widget.autoPrintDeliveryNote, onChanged: widget.onAutoPrintDeliveryNoteChanged, activeColor: c.amber, icon: FluentIcons.box_24_regular),
              const SizedBox(height: 12),
              PremiumSettingsWidgets.buildCompactSwitch(context, title: "Impression directe", subtitle: "Envoie au spooler sans le dialogue système", value: widget.directPhysicalPrinting, onChanged: widget.onDirectPhysicalPrintingChanged, activeColor: c.amber, icon: FluentIcons.print_24_regular),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── MARGES ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.border_all_24_filled,
          title: "Marges d'Impression (mm)",
          subtitle: "Ajustez pour aligner avec vos imprimantes",
          color: c.rose,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PremiumSettingsWidgets.buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ticket Thermique", style: TextStyle(fontWeight: FontWeight.w900, color: c.rose, fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketTopCtrl, label: "Haut", icon: FluentIcons.arrow_up_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                        const SizedBox(width: 8),
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketBottomCtrl, label: "Bas", icon: FluentIcons.arrow_down_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketLeftCtrl, label: "Gauche", icon: FluentIcons.arrow_left_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                        const SizedBox(width: 8),
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketRightCtrl, label: "Droite", icon: FluentIcons.arrow_right_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PremiumSettingsWidgets.buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Document A4", style: TextStyle(fontWeight: FontWeight.w900, color: c.rose, fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceTopCtrl, label: "Haut", icon: FluentIcons.arrow_up_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                        const SizedBox(width: 8),
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceBottomCtrl, label: "Bas", icon: FluentIcons.arrow_down_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceLeftCtrl, label: "Gauche", icon: FluentIcons.arrow_left_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                        const SizedBox(width: 8),
                        Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceRightCtrl, label: "Droite", icon: FluentIcons.arrow_right_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: widget.onSaveDebounced)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  ShopSettings _getCurrentSettings() {
    return ShopSettings(
      name: widget.nameCtrl.text,
      slogan: widget.sloganCtrl.text,
      address: widget.addressCtrl.text,
      phone: widget.phoneCtrl.text,
      logoPath: widget.logoPath,
      titleReceipt: widget.titleReceiptCtrl.text,
      titleInvoice: widget.titleInvoiceCtrl.text,
      titleQuote: widget.titleQuoteCtrl.text,
      titleProforma: widget.titleProformaCtrl.text,
      titleDeliveryNote: widget.titleDeliveryNoteCtrl.text,
      receiptFooter: widget.receiptFooterCtrl.text,
      marginTicketTop: double.tryParse(widget.marginTicketTopCtrl.text) ?? 5.0,
      marginTicketBottom: double.tryParse(widget.marginTicketBottomCtrl.text) ?? 5.0,
      marginTicketLeft: double.tryParse(widget.marginTicketLeftCtrl.text) ?? 5.0,
      marginTicketRight: double.tryParse(widget.marginTicketRightCtrl.text) ?? 5.0,
      marginInvoiceTop: double.tryParse(widget.marginInvoiceTopCtrl.text) ?? 20.0,
      marginInvoiceBottom: double.tryParse(widget.marginInvoiceBottomCtrl.text) ?? 20.0,
      marginInvoiceLeft: double.tryParse(widget.marginInvoiceLeftCtrl.text) ?? 20.0,
      marginInvoiceRight: double.tryParse(widget.marginInvoiceRightCtrl.text) ?? 20.0,
      marginLabelX: double.tryParse(widget.marginLabelXCtrl.text) ?? 0.0,
      marginLabelY: double.tryParse(widget.marginLabelYCtrl.text) ?? 0.0,
      labelWidth: double.tryParse(widget.labelWidthCtrl.text) ?? 50.0,
      labelHeight: double.tryParse(widget.labelHeightCtrl.text) ?? 30.0,
      showNameOnLabels: widget.showNameOnLabels,
      showPriceOnLabels: widget.showPriceOnLabels,
      showSkuOnLabels: widget.showSkuOnLabels,
      defaultReceipt: widget.receipt ?? ReceiptTemplate.classic,
      defaultInvoice: widget.invoice ?? InvoiceTemplate.corporate,
      defaultQuote: widget.quote ?? QuoteTemplate.prestige,
    );
  }

  void _showPreviewModal(BuildContext context, DashColors c) {
    showDialog(
      context: context,
      builder: (ctx) => _PreviewDialog(settings: _getCurrentSettings(), c: c),
    );
  }
}

class _PreviewDialog extends StatefulWidget {
  final ShopSettings settings;
  final DashColors c;

  const _PreviewDialog({required this.settings, required this.c});

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  int _previewMode = 0; // 0:SALE, 1:INVOICE, 2:QUOTE, 3:PROFORMA, 4:DELIVERY, 5:SHIFT, 6:AUDIT, 7:LABEL

  Future<Uint8List> _generatePreviewPdf() async {
    final ds = widget.settings;
    
    switch (_previewMode) {
      case 0: return ReceiptService.generateSamplePdf(ds);
      case 1:
        final data = InvoiceData(
          invoiceNumber: "FACT-2024-0001",
          date: DateTime.now(),
          items: [const InvoiceItem(name: "PC Portable Haute Performance", qty: 1, unitPrice: 450000)],
          subtotal: 450000, totalAmount: 450000, amountPaid: 450000, change: 0,
          cashierName: "DÉMO PRO", settings: ds,
        );
        return (await InvoiceService.buildDocument(data, ds.defaultInvoice)).save();
      case 2:
        final data = QuoteData(
          quoteNumber: "DEV-2024-0042",
          date: DateTime.now(),
          items: [const QuoteItem(name: "Installation Système Danaya+", qty: 1, unitPrice: 150000)],
          subtotal: 150000, totalAmount: 150000, cashierName: "EXPERT PRO", settings: ds,
        );
        return (await QuoteService.buildDocument(data, ds.defaultQuote)).save();
      case 3:
        final data = InvoiceData(
          invoiceNumber: "PROF-2024-0067",
          date: DateTime.now(),
          items: [const InvoiceItem(name: "Mobilier de Bureau Pro", qty: 2, unitPrice: 25000)],
          subtotal: 50000, totalAmount: 50000, amountPaid: 0, change: 0,
          cashierName: "COMMERCIAL", settings: ds, isProforma: true,
        );
        return (await InvoiceService.buildDocument(data, ds.defaultInvoice)).save();
      case 4:
        final data = InvoiceData(
          invoiceNumber: "BL-2024-0089",
          date: DateTime.now(),
          items: [const InvoiceItem(name: "Carton de RAM DDR4 16GB", qty: 50, unitPrice: 35000)],
          subtotal: 1750000, totalAmount: 1750000, amountPaid: 1750000, change: 0,
          cashierName: "LOGISTIQUE", settings: ds, isDeliveryNote: true,
        );
        return (await InvoiceService.buildDocument(data, ds.defaultInvoice)).save();
      case 5: return _dummyThermalReport(ds);
      case 6: return _dummyPdfReport(ds);
      case 7: return InventoryAutomationService.generateSampleLabelPdf(ds);
      default: return ReceiptService.generateSamplePdf(ds);
    }
  }

  Future<Uint8List> _dummyThermalReport(ShopSettings ds) async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(
      base: PdfResourceService.instance.regular,
      bold: PdfResourceService.instance.bold,
      italic: PdfResourceService.instance.italic,
    ));
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity).copyWith(
        marginLeft: 5 * PdfPageFormat.mm,
        marginTop: 5 * PdfPageFormat.mm,
        marginRight: 5 * PdfPageFormat.mm,
        marginBottom: 5 * PdfPageFormat.mm,
      ),
      build: (ctx) => pw.Column(children: [
        if (ds.logoPath != null && File(ds.logoPath!).existsSync())
          pw.Container(
            height: 40,
            child: pw.Image(pw.MemoryImage(File(ds.logoPath!).readAsBytesSync())),
            margin: pw.EdgeInsets.only(bottom: 10),
          ),
        pw.Text(ds.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        if (ds.slogan.isNotEmpty) pw.Text(ds.slogan, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 5),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(color: PdfColors.black),
          child: pw.Text("RAPPORT DE CLÔTURE Z", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white)),
        ),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Date :"), pw.Text(DateFormatter.formatDate(DateTime.now()))]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Caissier :"), pw.Text("ADMINISTRATEUR")]),
        pw.SizedBox(height: 5),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Ventes (42) :"), pw.Text("850.000 F")]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Retours (1) :"), pw.Text("- 15.000 F")]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Net :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("835.000 F", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 10),
        pw.Text("RÉCAPITULATIF MODALITÉS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Espèces :"), pw.Text("600.000 F")]),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Mobile Money :"), pw.Text("235.000 F")]),
        pw.Divider(borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 10),
        pw.Text("Signé le ${DateFormatter.formatDateTime(DateTime.now())}", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ])));
    return pdf.save();
  }

  Future<Uint8List> _dummyPdfReport(ShopSettings ds) async {
     final pdf = pw.Document(theme: pw.ThemeData.withFont(
        base: PdfResourceService.instance.regular,
        bold: PdfResourceService.instance.bold,
        italic: PdfResourceService.instance.italic,
      ));
     final accent = PdfColor.fromHex('#2196F3');
     
     pdf.addPage(pw.MultiPage(
       pageFormat: PdfPageFormat.a4,
       margin: const pw.EdgeInsets.all(32),
       header: (ctx) => pw.Container(
         padding: const pw.EdgeInsets.only(bottom: 20),
         decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2))),
         child: pw.Row(
           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
           children: [
             pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
               pw.Text(ds.name.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent)),
               if (ds.address.isNotEmpty) pw.Text(ds.address, style: const pw.TextStyle(fontSize: 8)),
             ]),
             pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
               pw.Text("AUDIT DE GESTION", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
               pw.Text("Généré le: ${DateFormatter.formatDate(DateTime.now())}", style: const pw.TextStyle(fontSize: 9)),
             ]),
           ],
         ),
       ),
       build: (ctx) => [
         pw.SizedBox(height: 30),
         pw.Text("RÉSUMÉ DES INDICATEURS CLÉS (KPI)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
         pw.SizedBox(height: 15),
         pw.Row(children: [
           _kpiCard("CHIFFRE D'AFFAIRES", "2.450.000 F", accent),
           _kpiCard("BÉNÉFICE BRUT", "840.000 F", PdfColors.green700),
           _kpiCard("VALEUR STOCK", "12.000.000 F", PdfColors.orange700),
         ]),
         pw.SizedBox(height: 30),
         pw.Text("TOP 5 PRODUITS LES PLUS VENDUS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
         pw.SizedBox(height: 10),
         pw.TableHelper.fromTextArray(
           headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
           headerDecoration: pw.BoxDecoration(color: accent),
           cellAlignment: pw.Alignment.centerLeft,
           data: [
             ['Libellé Produit', 'Qté Vendue', 'CA Généré', 'Marge'],
             ['Ordinateur HP EliteBook', '5', '1.250.000 F', '250.000 F'],
             ['Disque SSD 500GB', '12', '420.000 F', '120.000 F'],
           ],
         ),
       ]));
     return pdf.save();
  }

  pw.Widget _kpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 5),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Column(children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.85,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            // HEader
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: c.surfaceElev,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.eye_tracking_24_filled, color: c.blue),
                  const SizedBox(width: 12),
                  Text("Aperçu des Documents", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.blue)),
                  const Spacer(),
                  PremiumSettingsWidgets.buildCompactDropdown<int>(
                    context,
                    label: "Document à prévisualiser",
                    value: _previewMode,
                    items: const [
                       DropdownMenuItem(value: 0, child: Text("Ticket de Caisse", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 1, child: Text("Facture A4", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 2, child: Text("Devis A4", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 3, child: Text("Facture Proforma", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 4, child: Text("Bon de Livraison", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 5, child: Text("Clôture Z", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                       DropdownMenuItem(value: 6, child: Text("Rapport PDF", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _previewMode = v); },
                    color: c.blue,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(FluentIcons.dismiss_24_filled, color: c.textMuted),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: PdfPreview(
                key: ValueKey("preview-$_previewMode-${widget.settings.defaultReceipt}-${widget.settings.defaultInvoice}"),
                build: (format) => _generatePreviewPdf(),
                useActions: false,
                allowPrinting: false,
                allowSharing: false,
                canChangeOrientation: false,
                canChangePageFormat: false,
                maxPageWidth: 600,
                dpi: 200,
                loadingWidget: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
