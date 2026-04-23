import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/application/inventory_automation_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';

class LabelPrintingUtils {
  /// Affiche un dialogue de confirmation avant l'impression d'étiquettes.
  /// Utile après la création d'un produit ou un approvisionnement.
  static Future<void> confirmAndPrintLabels(
    BuildContext context, 
    WidgetRef ref, {
    required List<Product> products,
    required String sourceAction, // e.g., "Création du produit", "Arrivée de stock"
  }) async {
    if (products.isEmpty) return;

    final productNames = products.map((p) => p.name).toSet().toList();
    final totalCount = products.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Impression des Étiquettes",
        icon: FluentIcons.barcode_scanner_24_regular,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ANNULER"),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(FluentIcons.print_16_filled, size: 16),
            label: const Text("IMPRIMER MAINTENANT"),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Action : $sourceAction",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Text(
              "L'impression automatique est activée. Voulez-vous imprimer $totalCount étiquette(s) pour les articles suivants ?",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: productNames.map((name) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.circle_12_filled, size: 8, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(inventoryAutomationServiceProvider).printBarcodeLabels(products);
    }
  }
}
