import 'package:flutter/foundation.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

void main() {
  final settings = ShopSettings();
  debugPrint('autoPrintLabelsOnStockIn: ${settings.autoPrintLabelsOnStockIn}');
}
