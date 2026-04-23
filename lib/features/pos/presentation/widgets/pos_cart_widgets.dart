import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pos Cart Header
// ─────────────────────────────────────────────────────────────────────────────

class PosCartHeader extends ConsumerWidget {
  final double itemCount;
  final VoidCallback? onClear;

  const PosCartHeader({super.key, required this.itemCount, this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          Icon(
            FluentIcons.cart_24_filled,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            "Panier",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (itemCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ref.qty(itemCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onClear != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: onClear,
              icon: const Icon(FluentIcons.delete_24_regular, size: 16),
              label: const Text("Vider", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pos Empty Cart
// ─────────────────────────────────────────────────────────────────────────────

class PosEmptyCart extends StatelessWidget {
  const PosEmptyCart({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.cart_24_regular,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Panier vide",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Cliquez sur un produit\npour l'ajouter",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pos Cart Line Item
// ─────────────────────────────────────────────────────────────────────────────

class PosCartLine extends ConsumerWidget {
  final PosCartItem item;
  final bool isActive;
  final VoidCallback onTap;
  final ValueChanged<double> onQtyChange;
  final VoidCallback onRemove;

  const PosCartLine({
    super.key,
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.onQtyChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1A1D24) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Qty stepper
            PosQtyBox(
              qty: item.qty,
              onDecrement: () => onQtyChange(item.qty - 1.0),
              onIncrement: () => onQtyChange(item.qty + 1.0),
            ),
            const SizedBox(width: 10),

            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${ref.fmt(item.unitPrice)} × ${ref.qty(item.qty)}",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Line total + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ref.fmt(item.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      FluentIcons.delete_16_regular,
                      size: 16,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pos Qty Box & Buttons
// ─────────────────────────────────────────────────────────────────────────────

class PosQtyBox extends StatelessWidget {
  final double qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const PosQtyBox({
    super.key,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        PosQtyBtn(icon: Icons.remove, color: color, onTap: onDecrement),
        SizedBox(
          width: 26,
          child: Text(
            DateFormatter.formatQuantity(qty),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        PosQtyBtn(icon: Icons.add, color: color, onTap: onIncrement),
      ],
    );
  }
}

class PosQtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const PosQtyBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pos Mode Toggle (Comptant / Crédit)
// ─────────────────────────────────────────────────────────────────────────────

class PosPaymentModeToggle extends StatelessWidget {
  final bool isCredit;
  final ValueChanged<bool> onChanged;

  const PosPaymentModeToggle({
    super.key,
    required this.isCredit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          PosModeBtn(
            label: "Comptant",
            active: !isCredit,
            color: theme.colorScheme.primary,
            onTap: () => onChanged(false),
          ),
          PosModeBtn(
            label: "Crédit",
            active: isCredit,
            color: theme.colorScheme.error,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class PosModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const PosModeBtn({
    super.key,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}
