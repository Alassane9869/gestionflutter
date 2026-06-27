import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

extension CurrencyRefExtension on WidgetRef {
  /// Formatte un montant numérique en utilisant les paramètres de la boutique (devise, décimales).
  /// Utilise [shopSettingsProvider] en interne via [watch].
  String fmt(num val) {
    final settings = watch(shopSettingsProvider).value;
    return DateFormatter.formatCurrency(
      val.toDouble(),
      settings?.currency ?? 'FCFA',
      removeDecimals: settings?.removeDecimals ?? true,
    );
  }

  /// Formatte une quantité : enlève le .0 si c'est un entier, sinon garde les décimales.
  String qty(double val) {
    return DateFormatter.formatQuantity(val);
  }
}
