import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:flutter/foundation.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

final stockAlertServiceProvider = Provider<StockAlertService>((ref) {
  return StockAlertService(ref);
});

class StockAlertService {
  final Ref ref;
  static const _lastAlertDateKey = 'last_stock_alert_date';

  StockAlertService(this.ref);

  /// Checks for products with low stock and sends an email report to the shop owner.
  /// Limited to once per day AND only after the configured hour.
  Future<void> checkAndSendAlert() async {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null || !settings.stockAlertsEnabled || settings.backupEmailRecipient.isEmpty) {
      debugPrint("StockAlertService: Alerts disabled or recipient missing.");
      return;
    }

    final now = DateTime.now();

    // ⏰ Vérification de l'heure : n'envoyer qu'à partir de l'heure configurée 
    // (utilisée depuis reportEmailHour, 20h par défaut)
    final sendHour = settings.reportEmailHour; // Ex: 20 pour 20h
    if (now.hour < sendHour) {
      debugPrint("StockAlertService: Too early (${now.hour}h < ${sendHour}h). Will retry later.");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormatter.formatFileName(now);
      final lastAlertDate = prefs.getString(_lastAlertDateKey);

      if (lastAlertDate == today) {
        debugPrint("StockAlertService: Alert already sent today ($today). Skipping.");
        return;
      }

      final productsAsync = await ref.read(productListProvider.future);
      final lowStockProducts = productsAsync
          .where((p) => p.isLowStock || p.isOutOfStock)
          .map((p) => {
                'name': p.name,
                'stock': p.quantity,
                'threshold': p.alertThreshold,
              })
          .toList();

      if (lowStockProducts.isEmpty) {
        debugPrint("StockAlertService: No low stock products found.");
        // We don't update the lastAlertDate because we didn't send anything.
        // This allows it to check again later if stock changes.
        return;
      }

      final emailService = ref.read(emailServiceProvider);
      final result = await emailService.sendLowStockAlert(
        recipient: settings.backupEmailRecipient,
        lowStockProducts: lowStockProducts,
      );

      if (result.success) {
        debugPrint("StockAlertService: Low stock report sent to ${settings.backupEmailRecipient}");
        await prefs.setString(_lastAlertDateKey, today);
      } else {
        debugPrint("StockAlertService: Failed to send low stock report. Error: ${result.errorMessage}");
      }
    } catch (e) {
      debugPrint("StockAlertService Error: $e");
    }
  }
}
