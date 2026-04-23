import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';
import 'package:danaya_plus/core/widgets/glass_widgets.dart';
import 'package:danaya_plus/core/utils/image_resolver.dart';

class PosProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;

  const PosProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cartQty = ref.watch(cartProvider.select((cart) =>
        cart.where((item) => item.productId == product.id).firstOrNull?.qty ?? 0));

    final settings = ref.watch(shopSettingsProvider).value;

    final out = product.isOutOfStock;
    final low = product.isLowStock && !out;
    final inCart = cartQty > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: out ? null : onTap,
        onDoubleTap: out ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AbsorbPointer(
          absorbing: out,
          child: GlassContainer(
            borderRadius: 16,
            blur: 15,
            opacity: inCart ? (isDark ? 0.25 : 0.6) : (isDark ? 0.1 : 0.3),
            padding: EdgeInsets.zero,
            border: Border.all(
              color: inCart
                  ? theme.colorScheme.primary
                  : low
                      ? Colors.orange.withValues(alpha: 0.3)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.05)),
              width: inCart ? 1.5 : 0.5,
            ),
            child: Stack(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: out ? 0.4 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Section
                      Expanded(
                        flex: 11,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: ColorFiltered(
                            colorFilter: out
                                ? const ColorFilter.mode(
                                    Colors.grey, BlendMode.saturation)
                                : const ColorFilter.mode(
                                    Colors.transparent, BlendMode.multiply),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: (product.imagePath != null &&
                                      product.imagePath!.isNotEmpty)
                                  ? Opacity(
                                      opacity: out ? 0.5 : 1.0,
                                      child: Image(
                                        image: ImageResolver.getProductImage(
                                            product.imagePath, settings),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _buildPlaceholderIcon(
                                                    theme, out),
                                      ),
                                    )
                                  : _buildPlaceholderIcon(theme, out),
                            ),
                          ),
                        ),
                      ),

                      // Content Section
                      Expanded(
                        flex: 10,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: out
                                      ? Colors.grey.shade600
                                      : (isDark ? Colors.white : Colors.black87),
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ref.fmt(product.sellingPrice),
                                      style: TextStyle(
                                        color: out
                                            ? Colors.grey
                                            : (inCart
                                                ? theme.colorScheme.primary
                                                : (isDark
                                                    ? Colors.white
                                                    : theme.colorScheme.primary)),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Tiny stock indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (out
                                              ? Colors.red
                                              : (low
                                                  ? Colors.orange
                                                  : Colors.green))
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      out ? "OUT" : ref.qty(product.quantity),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: out
                                            ? Colors.red
                                            : (low
                                                ? Colors.orange
                                                : Colors.green),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // "ÉPUISÉ" Overlay
                if (out)
                  Positioned.fill(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.15,
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          blur: 10,
                          opacity: 0.8,
                          borderRadius: 8,
                          color: Colors.red.shade900,
                          border: Border.all(color: Colors.white24, width: 1),
                          child: const Text(
                            "ÉPUISÉ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Selection Badge
                if (inCart)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      height: 24,
                      width: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          ref.qty(cartQty),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(ThemeData theme, bool out) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Icon(
        out ? FluentIcons.prohibited_24_regular : FluentIcons.box_24_regular,
        size: 26,
        color: out
            ? Colors.grey.withValues(alpha: 0.5)
            : (isDark
                ? Colors.white.withValues(alpha: 0.2)
                : theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
    );
  }
}
