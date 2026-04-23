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
  final BarcodeGenerationModel barcodeModel;
  final ValueChanged<BarcodeGenerationModel?> onBarcodeModelChanged;

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

  final String? currency;
  final bool? removeDecimals;

  final TextEditingController nameCtrl;
  final TextEditingController sloganCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final String? logoPath;

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

    required this.barcodeModel,
    required this.onBarcodeModelChanged,
    this.currency,
    this.removeDecimals,
  });

  @override
  State<PrintingSettingsSection> createState() => _PrintingSettingsSectionState();
}

class _PrintingSettingsSectionState extends State<PrintingSettingsSection> {
  Timer? _debounceTimer;
  late ValueNotifier<ShopSettings> _liveSettings;
  int _previewMode = 1; // Default to Invoice A4 as requested
  bool _forceHidePreview = false;

  @override
  void initState() {
    super.initState();
    _liveSettings = ValueNotifier(_getCurrentSettings());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _liveSettings.dispose();
    super.dispose();
  }

  void _triggerLiveUpdate({int delayMs = 300}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        _liveSettings.value = _getCurrentSettings();
      }
    });
  }

  void _onSettingChanged({int delayMs = 300}) {
    _triggerLiveUpdate(delayMs: delayMs);
    widget.onSaveDebounced();
  }

  @override
  void didUpdateWidget(PrintingSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Détecte les changements venant du parent pour forcer le rafraîchissement
    // On utilise un délai plus court (50ms) pour les changements de sélection directe (modèles, formats)
    if (oldWidget.barcodeModel != widget.barcodeModel ||
        oldWidget.receipt != widget.receipt ||
        oldWidget.invoice != widget.invoice ||
        oldWidget.quote != widget.quote ||
        oldWidget.labelFormat != widget.labelFormat) {
      _triggerLiveUpdate(delayMs: 50);
      return;
    }

    // Changements de réglages visuels
    if ((oldWidget.currency ?? "") != (widget.currency ?? "") ||
        (oldWidget.removeDecimals ?? true) != (widget.removeDecimals ?? true) ||
        oldWidget.showNameOnLabels != widget.showNameOnLabels ||
        oldWidget.showPriceOnLabels != widget.showPriceOnLabels ||
        oldWidget.showSkuOnLabels != widget.showSkuOnLabels ||
        oldWidget.showQrCode != widget.showQrCode) {
      _triggerLiveUpdate(delayMs: 150);
      return;
    }

    // Changements venant des controllers (déjà gérés par _onSettingChanged mais au cas où)
    if (oldWidget.labelWidthCtrl.text != widget.labelWidthCtrl.text ||
        oldWidget.labelHeightCtrl.text != widget.labelHeightCtrl.text ||
        oldWidget.marginLabelXCtrl.text != widget.marginLabelXCtrl.text ||
        oldWidget.marginLabelYCtrl.text != widget.marginLabelYCtrl.text) {
       _triggerLiveUpdate();
    }
  }
  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool canShowPreview = constraints.maxWidth > 1050;
        final bool showSidePreview = canShowPreview && !_forceHidePreview;
        
        final settingsContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!showSidePreview) ...[
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   if (canShowPreview) 
                    PremiumSettingsWidgets.buildGradientBtn(
                      onPressed: () => setState(() => _forceHidePreview = false),
                      icon: FluentIcons.eye_20_regular,
                      label: "AFFICHER L'APERÇU",
                      colors: [c.blue, const Color(0xFF4A90E2)],
                    )
                  else
                    PremiumSettingsWidgets.buildGradientBtn(
                      onPressed: () {
                        Future.microtask(() {
                          if (context.mounted) _showPreviewModal(context, c);
                        });
                      },
                      icon: FluentIcons.eye_tracking_20_filled,
                      label: "APERÇU DES DOCUMENTS",
                      colors: [c.blue, const Color(0xFF4A90E2)],
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

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
                  LayoutBuilder(
                    builder: (context, box) {
                      final bool isNarrow = box.maxWidth < 600;
                      if (isNarrow) {
                        return Column(
                          children: [
                            PremiumSettingsWidgets.buildCompactDropdown<ReceiptTemplate>(
                              context,
                              label: "Ticket (Thermique)",
                              value: widget.receipt ?? ReceiptTemplate.values.first,
                              items: ReceiptTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                              onChanged: (v) => Future.microtask(() { widget.onReceiptChanged(v); _onSettingChanged(); }),
                              color: c.violet,
                            ),
                            const SizedBox(height: 12),
                            PremiumSettingsWidgets.buildCompactDropdown<InvoiceTemplate>(
                              context,
                              label: "Facture (A4)",
                              value: widget.invoice ?? InvoiceTemplate.values.first,
                              items: InvoiceTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                              onChanged: (v) => Future.microtask(() { widget.onInvoiceChanged(v); _onSettingChanged(); }),
                              color: c.violet,
                            ),
                            const SizedBox(height: 12),
                            PremiumSettingsWidgets.buildCompactDropdown<QuoteTemplate>(
                              context,
                              label: "Devis (A4)",
                              value: widget.quote ?? QuoteTemplate.values.first,
                              items: QuoteTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                              onChanged: (v) => Future.microtask(() { widget.onQuoteChanged(v); _onSettingChanged(); }),
                              color: c.violet,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: PremiumSettingsWidgets.buildCompactDropdown<ReceiptTemplate>(
                              context,
                              label: "Ticket (Thermique)",
                              value: widget.receipt ?? ReceiptTemplate.values.first,
                              items: ReceiptTemplate.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                              onChanged: (v) => Future.microtask(() { widget.onReceiptChanged(v); _onSettingChanged(); }),
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
                              onChanged: (v) => Future.microtask(() { widget.onInvoiceChanged(v); _onSettingChanged(); }),
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
                              onChanged: (v) => Future.microtask(() { widget.onQuoteChanged(v); _onSettingChanged(); }),
                              color: c.violet,
                            ),
                          ),
                        ],
                      );
                    },
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
              child: LayoutBuilder(
                builder: (context, box) {
                  final bool isNarrow = box.maxWidth < 600;
                  return Column(
                    children: [
                      if (isNarrow) ...[
                        PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleReceiptCtrl, label: "Titre Ticket", icon: FluentIcons.text_16_regular, hint: "TICKET DE CAISSE", color: c.emerald, onChanged: _onSettingChanged),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleInvoiceCtrl, label: "Titre Facture", icon: FluentIcons.text_16_regular, hint: "FACTURE COMMERCIALE", color: c.emerald, onChanged: _onSettingChanged),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleQuoteCtrl, label: "Titre Devis", icon: FluentIcons.text_16_regular, hint: "DEVIS", color: c.emerald, onChanged: _onSettingChanged),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleProformaCtrl, label: "Titre Proforma", icon: FluentIcons.text_16_regular, hint: "FACTURE PROFORMA", color: c.emerald, onChanged: _onSettingChanged),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleDeliveryNoteCtrl, label: "Titre Livraison", icon: FluentIcons.text_16_regular, hint: "BON DE LIVRAISON", color: c.emerald, onChanged: _onSettingChanged),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactField(context, controller: widget.receiptFooterCtrl, label: "Message Ticket", icon: FluentIcons.text_16_regular, hint: "Merci !", color: c.emerald, onChanged: _onSettingChanged),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleReceiptCtrl, label: "Titre Ticket", icon: FluentIcons.text_16_regular, hint: "TICKET DE CAISSE", color: c.emerald, onChanged: _onSettingChanged)),
                            const SizedBox(width: 14),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleInvoiceCtrl, label: "Titre Facture", icon: FluentIcons.text_16_regular, hint: "FACTURE COMMERCIALE", color: c.emerald, onChanged: _onSettingChanged)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleQuoteCtrl, label: "Titre Devis", icon: FluentIcons.text_16_regular, hint: "DEVIS", color: c.emerald, onChanged: _onSettingChanged)),
                            const SizedBox(width: 14),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleProformaCtrl, label: "Titre Proforma", icon: FluentIcons.text_16_regular, hint: "FACTURE PROFORMA", color: c.emerald, onChanged: _onSettingChanged)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.titleDeliveryNoteCtrl, label: "Titre Livraison", icon: FluentIcons.text_16_regular, hint: "BON DE LIVRAISON", color: c.emerald, onChanged: _onSettingChanged)),
                            const SizedBox(width: 14),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.receiptFooterCtrl, label: "Message de fin (Ticket)", icon: FluentIcons.text_16_regular, hint: "Merci de votre visite !", color: c.emerald, onChanged: _onSettingChanged)),
                          ],
                        ),
                      ],
                    ],
                  );
                },
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
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "QR code sur les tickets", subtitle: "Ajoute un QR code", value: widget.showQrCode, onChanged: (v) => Future.microtask(() { widget.onShowQrCodeChanged(v); _onSettingChanged(); }), activeThumbColor: c.amber, icon: FluentIcons.qr_code_24_regular),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Aperçu avant impression", subtitle: "Affiche le PDF", value: widget.showPreviewBeforePrint, onChanged: (v) => Future.microtask(() { widget.onShowPreviewBeforePrintChanged(v); _onSettingChanged(); }), activeThumbColor: c.amber, icon: FluentIcons.eye_24_regular),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Auto-impression Ticket", subtitle: "Lance l'impression", value: widget.autoPrintTicket, onChanged: (v) => Future.microtask(() { widget.onAutoPrintTicketChanged(v); _onSettingChanged(); }), activeThumbColor: c.amber, icon: FluentIcons.receipt_24_regular),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Auto-impression Livraison", subtitle: "Livre automatiquement", value: widget.autoPrintDeliveryNote, onChanged: (v) => Future.microtask(() { widget.onAutoPrintDeliveryNoteChanged(v); _onSettingChanged(); }), activeThumbColor: c.amber, icon: FluentIcons.box_24_regular),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Impression directe", subtitle: "Sans dialogue système", value: widget.directPhysicalPrinting, onChanged: (v) => Future.microtask(() { widget.onDirectPhysicalPrintingChanged(v); _onSettingChanged(); }), activeThumbColor: c.amber, icon: FluentIcons.print_24_regular),
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
                        Text("Ticket Thermique", style: TextStyle(fontWeight: FontWeight.w900, color: c.rose, fontSize: 13, letterSpacing: 0.5)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketTopCtrl, label: "Haut", icon: FluentIcons.arrow_up_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                            const SizedBox(width: 8),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketBottomCtrl, label: "Bas", icon: FluentIcons.arrow_down_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketLeftCtrl, label: "Gauche", icon: FluentIcons.arrow_left_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                            const SizedBox(width: 8),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginTicketRightCtrl, label: "Droite", icon: FluentIcons.arrow_right_16_regular, hint: "5", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
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
                        Text("Document A4", style: TextStyle(fontWeight: FontWeight.w900, color: c.rose, fontSize: 13, letterSpacing: 0.5)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceTopCtrl, label: "Haut", icon: FluentIcons.arrow_up_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                            const SizedBox(width: 8),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceBottomCtrl, label: "Bas", icon: FluentIcons.arrow_down_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceLeftCtrl, label: "Gauche", icon: FluentIcons.arrow_left_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                            const SizedBox(width: 8),
                            Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginInvoiceRightCtrl, label: "Droite", icon: FluentIcons.arrow_right_16_regular, hint: "20", isNumber: true, color: c.rose, onChanged: _onSettingChanged)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── GÉNÉRATEUR D'ÉTIQUETTES (BARCODES) ──
            PremiumSettingsWidgets.buildSectionHeader(
              context,
              icon: FluentIcons.barcode_scanner_24_filled,
              title: "Générateur d'Étiquettes",
              subtitle: "Configuration des codes-barres et étalonnage",
              color: c.blue,
            ),
            const SizedBox(height: 12),
            PremiumSettingsWidgets.buildCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(builder: (context, box) {
                    return Column(children: [
                      Row(
                        children: [
                          Expanded(
                            child: PremiumSettingsWidgets.buildCompactDropdown<String?>(
                              context,
                              label: "Imprimante cible (Étiquettes)",
                              value: widget.availablePrinters.any((p) => p.name == widget.labelPrinter) ? widget.labelPrinter : null,
                              items: widget.availablePrinters.map((p) => DropdownMenuItem<String?>(value: p.name, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => Future.microtask(() { widget.onLabelPrinterChanged(v); _onSettingChanged(); }),
                              color: c.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: IconButton(
                              icon: Icon(FluentIcons.arrow_sync_24_regular, color: c.blue, size: 20),
                              tooltip: "Actualiser les imprimantes",
                              onPressed: widget.onLoadPrinters,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: PremiumSettingsWidgets.buildCompactDropdown<LabelPrintingFormat>(
                          context,
                          label: "Format d'affichage",
                          value: widget.labelFormat,
                          items: const [
                            DropdownMenuItem(value: LabelPrintingFormat.a4Sheets, child: Text("PLANCHES A4 (3 COLONNES)")),
                            DropdownMenuItem(value: LabelPrintingFormat.singleLabel, child: Text("ÉTIQUETTE UNIQUE (ROULEAU)")),
                          ],
                          onChanged: (v) => Future.microtask(() { widget.onLabelFormatChanged(v); _onSettingChanged(delayMs: 50); }),
                          color: c.blue,
                        )),
                      ]),
                      const SizedBox(height: 14),
                      if (widget.labelFormat == LabelPrintingFormat.singleLabel) ...[
                        Row(children: [
                          Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.labelWidthCtrl, label: "Largeur (mm)", icon: FluentIcons.arrow_expand_24_regular, hint: "50", isNumber: true, color: c.blue, onChanged: _onSettingChanged)),
                          const SizedBox(width: 14),
                          Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.labelHeightCtrl, label: "Hauteur (mm)", icon: FluentIcons.arrow_expand_24_regular, hint: "30", isNumber: true, color: c.blue, onChanged: _onSettingChanged)),
                        ]),
                        const SizedBox(height: 14),
                      ],
                      Row(children: [
                        Expanded(child: PremiumSettingsWidgets.buildCompactDropdown<BarcodeGenerationModel>(
                          context,
                          label: "Standard de codification",
                          value: widget.barcodeModel,
                          items: BarcodeGenerationModel.values.map((m) {
                            String label = m == BarcodeGenerationModel.ean13 ? "EAN-13 (Standard Retail)" : 
                                          m == BarcodeGenerationModel.upcA ? "UPC-A (Standard US)" : 
                                          m == BarcodeGenerationModel.code128 ? "CODE 128 (Alpha-Numérique)" : "NUMÉRIQUE 9 (Optimisé)";
                            return DropdownMenuItem(value: m, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                          }).toList(),
                          onChanged: (v) => Future.microtask(() { widget.onBarcodeModelChanged(v); _onSettingChanged(delayMs: 50); }),
                          color: c.blue,
                        )),
                      ]),
                    ]);
                  }),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 14),
                  Text("Calibrage & Marges Lab", style: TextStyle(fontWeight: FontWeight.w900, color: c.blue, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginLabelXCtrl, label: "Marge X (Calibration)", icon: FluentIcons.arrow_move_24_regular, hint: "0", isNumber: true, color: c.blue, onChanged: _onSettingChanged)),
                    const SizedBox(width: 14),
                    Expanded(child: PremiumSettingsWidgets.buildCompactField(context, controller: widget.marginLabelYCtrl, label: "Marge Y (Calibration)", icon: FluentIcons.arrow_move_24_regular, hint: "0", isNumber: true, color: c.blue, onChanged: _onSettingChanged)),
                  ]),
                  const SizedBox(height: 20),
                  Text("Options d'Affichage", style: TextStyle(fontWeight: FontWeight.w900, color: c.blue, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Afficher le nom du produit", subtitle: "Libellé de l'article", value: widget.showNameOnLabels, onChanged: (v) => Future.microtask(() { widget.onShowNameOnLabelsChanged(v); _onSettingChanged(); }), activeThumbColor: c.blue, icon: FluentIcons.text_field_16_regular),
                  const SizedBox(height: 10),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Afficher le prix de vente", subtitle: "Prix TTC", value: widget.showPriceOnLabels, onChanged: (v) => Future.microtask(() { widget.onShowPriceOnLabelsChanged(v); _onSettingChanged(); }), activeThumbColor: c.blue, icon: FluentIcons.money_16_regular),
                  const SizedBox(height: 10),
                  PremiumSettingsWidgets.buildCompactSwitch(context, title: "Afficher le SKU / Code", subtitle: "Référence visuelle", value: widget.showSkuOnLabels, onChanged: (v) => Future.microtask(() { widget.onShowSkuOnLabelsChanged(v); _onSettingChanged(); }), activeThumbColor: c.blue, icon: FluentIcons.barcode_scanner_24_regular),
                ],
              ),
            ),
          ],
        );

        if (showSidePreview) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 20),
                  child: settingsContent,
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  height: MediaQuery.of(context).size.height - 180,
                  decoration: BoxDecoration(
                    color: c.surfaceElev,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: _buildLivePreviewPane(c),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms);
        }

        return SingleChildScrollView(child: settingsContent);
      },
    );
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
      
      // Modèles
      defaultReceipt: widget.receipt ?? ReceiptTemplate.classic,
      defaultInvoice: widget.invoice ?? InvoiceTemplate.clean,
      defaultQuote: widget.quote ?? QuoteTemplate.prestige,
      
      // Marges Ticket
      marginTicketTop: double.tryParse(widget.marginTicketTopCtrl.text) ?? 5.0,
      marginTicketBottom: double.tryParse(widget.marginTicketBottomCtrl.text) ?? 5.0,
      marginTicketLeft: double.tryParse(widget.marginTicketLeftCtrl.text) ?? 5.0,
      marginTicketRight: double.tryParse(widget.marginTicketRightCtrl.text) ?? 5.0,
      
      // Marges A4
      marginInvoiceTop: double.tryParse(widget.marginInvoiceTopCtrl.text) ?? 20.0,
      marginInvoiceBottom: double.tryParse(widget.marginInvoiceBottomCtrl.text) ?? 20.0,
      marginInvoiceLeft: double.tryParse(widget.marginInvoiceLeftCtrl.text) ?? 20.0,
      marginInvoiceRight: double.tryParse(widget.marginInvoiceRightCtrl.text) ?? 20.0,
      
      // Marges & Format Étiquette
      marginLabelX: double.tryParse(widget.marginLabelXCtrl.text) ?? 0.0,
      marginLabelY: double.tryParse(widget.marginLabelYCtrl.text) ?? 0.0,
      labelWidth: double.tryParse(widget.labelWidthCtrl.text) ?? 50.0,
      labelHeight: double.tryParse(widget.labelHeightCtrl.text) ?? 30.0,
      labelFormat: widget.labelFormat,
      
       // Options visuelles
      showNameOnLabels: widget.showNameOnLabels,
      showPriceOnLabels: widget.showPriceOnLabels,
      showSkuOnLabels: widget.showSkuOnLabels,
      showQrCode: widget.showQrCode,
      barcodeModel: widget.barcodeModel,
      currency: widget.currency ?? 'CFA',
      removeDecimals: widget.removeDecimals ?? true,
    ).copyWith(); // Force a new hash entry for ValueKey even if data is stable
  }

  Widget _buildLivePreviewPane(DashColors c) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: c.surfaceElev,
            border: Border(bottom: BorderSide(color: c.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.eye_24_filled, color: c.blue, size: 18),
              const SizedBox(width: 8),
              Text("APERÇU EN DIRECT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: c.blue)),
              const Spacer(),
              _buildPreviewModeSwitch(c),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _forceHidePreview = true),
                icon: Icon(FluentIcons.panel_right_contract_20_regular, color: c.textMuted, size: 20),
                tooltip: "Masquer l'aperçu",
              ),
            ],
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ValueListenableBuilder<ShopSettings>(
              valueListenable: _liveSettings,
              builder: (context, settings, _) {
                return PdfPreview(
                  key: ValueKey("preview_${_previewMode}_${settings.hashCode}_${settings.barcodeModel}"),
                  build: (format) => _generatePreviewPdf(settings, format, _previewMode),
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  dpi: (_previewMode == 0 || _previewMode == 7) ? 600 : 300,
                  loadingWidget: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewModeSwitch(DashColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallModeBtn("TICKET", 0, c),
          _buildSmallModeBtn("A4", 1, c),
          _buildSmallModeBtn("DEVIS", 2, c),
          _buildSmallModeBtn("LABEL", 7, c),
        ],
      ),
    );
  }

  Widget _buildSmallModeBtn(String label, int mode, DashColors c) {
    final bool isActive = _previewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _previewMode = mode);
        _triggerLiveUpdate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? c.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : c.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
      ),
    );
  }

  void _showPreviewModal(BuildContext context, DashColors c) {
    showDialog(
      context: context,
      builder: (ctx) => _PreviewDialog(settings: _getCurrentSettings(), c: c, initialMode: _previewMode, generateFn: _generatePreviewPdf),
    );
  }

  Future<Uint8List> _generatePreviewPdf(ShopSettings ds, PdfPageFormat format, int mode) async {
    try {
      switch (mode) {
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
          return QuoteService.generateSamplePdf(ds);
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
        case 5: return _dummyThermalReport(ds, format);
        case 6: return _dummyPdfReport(ds, format);
        case 7: return InventoryAutomationService.generateSampleLabelPdf(ds);
        default: return ReceiptService.generateSamplePdf(ds);
      }
    } catch (e) {
       // Fallback en cas d'erreur de rendu (ex: template vide ou erreur cache)
       final pdf = pw.Document();
       pdf.addPage(pw.Page(build: (pw.Context ctx) => pw.Center(child: pw.Text("Erreur d'aperçu : $e"))));
       return pdf.save();
    }
  }

  Future<Uint8List> _dummyThermalReport(ShopSettings ds, PdfPageFormat format) async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(
      base: PdfResourceService.instance.regular,
      bold: PdfResourceService.instance.bold,
      italic: PdfResourceService.instance.italic,
    ));

    final thermalFormat = format.copyWith(width: format.width > 250 ? 226 : format.width).copyWith(
      marginLeft: 5 * PdfPageFormat.mm, marginTop: 5 * PdfPageFormat.mm,
      marginRight: 5 * PdfPageFormat.mm, marginBottom: 5 * PdfPageFormat.mm,
    );
    
    pdf.addPage(pw.Page(pageFormat: thermalFormat, build: (pw.Context ctx) => pw.Column(children: [
      if (ds.logoPath != null && File(ds.logoPath!).existsSync())
        pw.Container(height: 40, margin: const pw.EdgeInsets.only(bottom: 10), child: pw.Image(pw.MemoryImage(File(ds.logoPath!).readAsBytesSync()))),
      pw.Text(ds.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
      if (ds.slogan.isNotEmpty) pw.Text(ds.slogan, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
      pw.SizedBox(height: 5),
      pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: const pw.BoxDecoration(color: PdfColors.black), child: pw.Text("RAPPORT DE CLÔTURE Z", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white))),
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Date :"), pw.Text(DateFormatter.formatDate(DateTime.now()))]),
      pw.Divider(borderStyle: pw.BorderStyle.dashed),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Net :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("835.000 F", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
      pw.Divider(borderStyle: pw.BorderStyle.dashed),
      pw.SizedBox(height: 10),
      pw.Text("Signé le ${DateFormatter.formatDateTime(DateTime.now())}", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
    ])));
    return pdf.save();
  }

  Future<Uint8List> _dummyPdfReport(ShopSettings ds, PdfPageFormat format) async {
     final pdf = pw.Document(theme: pw.ThemeData.withFont(
        base: PdfResourceService.instance.regular, bold: PdfResourceService.instance.bold, italic: PdfResourceService.instance.italic,
      ));
     final accent = PdfColor.fromHex('#2196F3');
     pdf.addPage(pw.MultiPage(
       pageFormat: format, margin: const pw.EdgeInsets.all(32),
       header: (ctx) => pw.Container(padding: const pw.EdgeInsets.only(bottom: 20), decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
         pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(ds.name.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent)), if (ds.address.isNotEmpty) pw.Text(ds.address, style: const pw.TextStyle(fontSize: 8))]),
         pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text("AUDIT DE GESTION", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)), pw.Text("Généré le: ${DateFormatter.formatDate(DateTime.now())}", style: const pw.TextStyle(fontSize: 9))]),
       ])),
       build: (ctx) => [
         pw.SizedBox(height: 30),
         pw.Text("RÉSUMÉ DES INDICATEURS CLÉS (KPI)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accent)),
         pw.SizedBox(height: 15),
         pw.Row(children: [ _kpiCard("CHIFFRE D'AFFAIRES", "2.450.000 F", accent), _kpiCard("BÉNÉFICE BRUT", "840.000 F", PdfColors.green700), _kpiCard("VALEUR STOCK", "12.000.000 F", PdfColors.orange700)]),
       ]));
     return pdf.save();
  }

  pw.Widget _kpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 5),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Column(children: [pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)), pw.SizedBox(height: 5), pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color))]),
    ));
  }
}

class _PreviewDialog extends StatefulWidget {
  final ShopSettings settings;
  final DashColors c;
  final int initialMode;
  final Future<Uint8List> Function(ShopSettings, PdfPageFormat, int) generateFn;

  const _PreviewDialog({required this.settings, required this.c, required this.initialMode, required this.generateFn});

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late int _previewMode;

  @override
  void initState() {
    super.initState();
    _previewMode = widget.initialMode;
  }


  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: RepaintBoundary(
        child: Container(
          width: 800,
          height: MediaQuery.of(context).size.height * 0.85,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: Column(
          children: [
            // HEader
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.surfaceElev,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.eye_tracking_24_filled, color: c.blue, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Aperçu des Documents", 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 220,
                    child: PremiumSettingsWidgets.buildCompactDropdown<int>(
                      context,
                      label: "Modèle",
                      value: _previewMode,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("Ticket")),
                        DropdownMenuItem(value: 1, child: Text("Facture A4")),
                        DropdownMenuItem(value: 2, child: Text("Devis A4")),
                        DropdownMenuItem(value: 3, child: Text("Proforma")),
                        DropdownMenuItem(value: 4, child: Text("Livraison")),
                        DropdownMenuItem(value: 7, child: Text("Étiquette")),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _previewMode = v); },
                      color: c.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(FluentIcons.dismiss_20_filled, color: c.textMuted),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: RepaintBoundary(
                child: PdfPreview(
                  key: ValueKey("modal_${widget.settings.hashCode}_$_previewMode"),
                  build: (format) => widget.generateFn(widget.settings, format, _previewMode),
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  // Retrait de maxPageWidth pour une netteté maximale
                  dpi: (_previewMode == 0 || _previewMode == 7) ? 600 : 300,
                  loadingWidget: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
 }
}
