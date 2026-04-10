import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/core/services/hardware_service.dart';

import 'package:printing/printing.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';

final devicesListProvider = FutureProvider<List<ExternalDevice>>((ref) async {
  final service = ref.read(hardwareServiceProvider);
  final usb = await service.listUsbDevices();
  final printers = await service.listPrinters();
  return [...usb, ...printers];
});

class HardwareSettingsSection extends ConsumerWidget {
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
  final String? contractPrinter;
  final ValueChanged<String?> onContractPrinterChanged;
  final String? payrollPrinter;
  final ValueChanged<String?> onPayrollPrinterChanged;
  final String? proformaPrinter;
  final ValueChanged<String?> onProformaPrinterChanged;
  final String? deliveryPrinter;
  final ValueChanged<String?> onDeliveryPrinterChanged;
  final List<Printer> availablePrinters;
  final VoidCallback onLoadPrinters;
  final bool openCashDrawer;
  final ValueChanged<bool> onOpenCashDrawerChanged;
  final Function(String?) onTestCashDrawer;
  final bool directPhysicalPrinting;
  final ValueChanged<bool> onDirectPhysicalPrintingChanged;
  final bool autoPrintTicket;
  final ValueChanged<bool> onAutoPrintTicketChanged;
  final bool showPreviewBeforePrint;
  final ValueChanged<bool> onShowPreviewBeforePrintChanged;

  const HardwareSettingsSection({
    super.key,
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
    required this.contractPrinter,
    required this.onContractPrinterChanged,
    required this.payrollPrinter,
    required this.onPayrollPrinterChanged,
    required this.proformaPrinter,
    required this.onProformaPrinterChanged,
    required this.deliveryPrinter,
    required this.onDeliveryPrinterChanged,
    required this.availablePrinters,
    required this.onLoadPrinters,
    required this.openCashDrawer,
    required this.onOpenCashDrawerChanged,
    required this.onTestCashDrawer,
    required this.directPhysicalPrinting,
    required this.onDirectPhysicalPrintingChanged,
    required this.autoPrintTicket,
    required this.onAutoPrintTicketChanged,
    required this.showPreviewBeforePrint,
    required this.onShowPreviewBeforePrintChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesListProvider);
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          title: "Gestion du Matériel",
          subtitle: "Configurez vos imprimantes, tiroirs et scanners de caisse.",
          icon: FluentIcons.usb_stick_24_regular,
          color: c.blue,
        ),
        const SizedBox(height: 24),

        // ── 1. ASSIGNATION DES IMPRIMANTES ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.print_24_filled,
          title: "Imprimantes Système",
          subtitle: "Définissez quelle imprimante gère quel type de document",
          color: c.violet,
          trailing: InkWell(
            onTap: onLoadPrinters,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: c.violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                   Icon(FluentIcons.arrow_sync_16_regular, color: c.violet, size: 16),
                   const SizedBox(width: 8),
                   Text("Actualiser", style: TextStyle(color: c.violet, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PremiumSettingsWidgets.buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📦 FLUX COMMERCIAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: c.blue, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    _buildPrinterDropdown(context, c, "TICKETS / REÇUS (80mm)", thermalPrinter, onThermalPrinterChanged),
                    const SizedBox(height: 12),
                    _buildPrinterDropdown(context, c, "FACTURES A4", invoicePrinter, onInvoicePrinterChanged),
                    const SizedBox(height: 12),
                    _buildPrinterDropdown(context, c, "PROFORMA", proformaPrinter, onProformaPrinterChanged),
                    const SizedBox(height: 12),
                    _buildPrinterDropdown(context, c, "DEVIS & OFFRES", quotePrinter, onQuotePrinterChanged),
                    const SizedBox(height: 12),
                    _buildPrinterDropdown(context, c, "ACHATS (Bons de commande)", purchaseOrderPrinter, onPurchaseOrderPrinterChanged),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  PremiumSettingsWidgets.buildCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🚛 LOGISTIQUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: c.amber, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _buildPrinterDropdown(context, c, "BONS DE LIVRAISON", deliveryPrinter, onDeliveryPrinterChanged),
                        const SizedBox(height: 12),
                        _buildPrinterDropdown(context, c, "ÉTIQUETTES PRODUITS", labelPrinter, onLabelPrinterChanged),
                      ],
                    )
                  ),
                  const SizedBox(height: 16),
                  PremiumSettingsWidgets.buildCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📝 R.H. & ADMINISTRATIF", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: c.rose, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        _buildPrinterDropdown(context, c, "CONTRATS DE TRAVAIL", contractPrinter, onContractPrinterChanged),
                        const SizedBox(height: 12),
                        _buildPrinterDropdown(context, c, "BULLETINS DE PAIE", payrollPrinter, onPayrollPrinterChanged),
                        const SizedBox(height: 12),
                        _buildPrinterDropdown(context, c, "RAPPORTS D'ACTIVITÉ", reportPrinter, onReportPrinterChanged),
                      ],
                    )
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── 2. TIROIR-CAISSE ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.money_24_filled,
          title: "Tiroir-Caisse",
          subtitle: "Gestion de l'ouverture physique connectée",
          color: c.emerald,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context, 
                title: "Ouverture automatique", 
                subtitle: "Ouvre le tiroir à la fin de chaque vente validée", 
                value: openCashDrawer, 
                onChanged: onOpenCashDrawerChanged, 
                activeColor: c.emerald, 
                icon: FluentIcons.money_16_regular
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text("Test manuel d'éjection", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    ),
                    PremiumSettingsWidgets.buildGradientBtn(
                      onPressed: () => onTestCashDrawer(thermalPrinter),
                      icon: FluentIcons.door_arrow_left_16_filled,
                      label: "ÉJECTER MAINTENANT",
                      colors: [c.emerald, Colors.green],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 3. AUTOMATISMES ──
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSettingsWidgets.buildSectionHeader(
                    context,
                    icon: FluentIcons.flow_24_filled,
                    title: "Flux d'Impression",
                    subtitle: "Règles d'envoi",
                    color: c.amber,
                  ),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCard(
                    context,
                    child: Column(
                      children: [
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Impression Directe (Bypass)", subtitle: "Imprime sans dialogue Windows (BETA)", value: directPhysicalPrinting, onChanged: onDirectPhysicalPrintingChanged, activeColor: c.amber, icon: FluentIcons.print_20_regular),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Impression Auto Ticket", subtitle: "A la fin d'une vente", value: autoPrintTicket, onChanged: onAutoPrintTicketChanged, activeColor: c.amber, icon: FluentIcons.receipt_20_regular),
                        const SizedBox(height: 12),
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Aperçu PDF avant impression", subtitle: "Affiche le PDF", value: showPreviewBeforePrint, onChanged: onShowPreviewBeforePrintChanged, activeColor: c.amber, icon: FluentIcons.eye_20_regular),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSettingsWidgets.buildSectionHeader(
                    context,
                    icon: FluentIcons.device_eq_24_filled,
                    title: "Diagnostic USB",
                    subtitle: "Périphériques détectés",
                    color: c.rose,
                  ),
                  const SizedBox(height: 12),
                  devicesAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (e, _) => Center(child: Text("Erreur : $e")),
                    data: (devices) {
                      final usb = devices.where((d) => d.deviceClass == DeviceClass.usb).toList();
                      return _buildDeviceCategory(context, c, title: "Scanners & Accessoires", devices: usb, icon: FluentIcons.barcode_scanner_24_regular);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrinterDropdown(BuildContext context, DashColors c, String label, String? value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: c.textSecondary, fontSize: 9, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: availablePrinters.any((p) => p.name == value) ? value : null,
              isExpanded: true,
              dropdownColor: c.surfaceElev,
              hint: Text("Sélectionner une imprimante...", style: TextStyle(fontSize: 11, color: c.textMuted)),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
              items: availablePrinters.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCategory(BuildContext context, DashColors c, {required String title, required List<ExternalDevice> devices, required IconData icon}) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: icon, color: c.rose),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: c.textPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c.rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text("${devices.length}", style: TextStyle(color: c.rose, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (devices.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("Aucun périphérique détecté", style: TextStyle(color: c.textMuted, fontSize: 11))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              separatorBuilder: (_, __) => Divider(color: c.border.withValues(alpha: 0.3)),
              itemBuilder: (context, index) {
                final device = devices[index];
                final isOk = device.status == 'OK' || device.status == 'Prêt';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PremiumSettingsWidgets.buildIconBadge(icon: device.deviceClass == DeviceClass.printer ? FluentIcons.print_20_regular : FluentIcons.usb_stick_20_regular, color: isOk ? c.emerald : Colors.grey),
                  title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  subtitle: Text(device.status, style: TextStyle(fontSize: 10, color: isOk ? c.emerald : Colors.grey, fontWeight: FontWeight.bold)),
                );
              },
            ),
        ],
      ),
    );
  }
}
