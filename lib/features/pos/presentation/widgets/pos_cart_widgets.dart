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
              : (isDark ? theme.colorScheme.surface : const Color(0xFFF9FAFB)),
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
              onQtyDirect: (val) => onQtyChange(val),
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
  final ValueChanged<double>? onQtyDirect;

  const PosQtyBox({
    super.key,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
    this.onQtyDirect,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        PosQtyBtn(icon: Icons.remove, color: color, onTap: onDecrement),
        GestureDetector(
          onTap: () => _showQtyDialog(context),
          child: Container(
            width: 30,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              DateFormatter.formatQuantity(qty),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ),
        PosQtyBtn(icon: Icons.add, color: color, onTap: onIncrement),
      ],
    );
  }

  void _showQtyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumQtyDialog(
        initialQty: qty,
        onConfirm: (val) => onQtyDirect?.call(val),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Quantity Input Dialog (Numpad Style)
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumQtyDialog extends StatefulWidget {
  final double initialQty;
  final ValueChanged<double> onConfirm;

  const _PremiumQtyDialog({required this.initialQty, required this.onConfirm});

  @override
  State<_PremiumQtyDialog> createState() => _PremiumQtyDialogState();
}

class _PremiumQtyDialogState extends State<_PremiumQtyDialog>
    with SingleTickerProviderStateMixin {
  late String _display;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _display = DateFormatter.formatQuantity(widget.initialQty);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    setState(() {
      if (_display == '0') {
        _display = digit;
      } else {
        _display += digit;
      }
    });
    _pulseCtrl.forward(from: 0);
  }

  void _onDot() {
    if (_display.contains('.') || _display.contains(',')) return;
    setState(() => _display += '.');
    _pulseCtrl.forward(from: 0);
  }

  void _onBackspace() {
    setState(() {
      if (_display.length <= 1) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
    _pulseCtrl.forward(from: 0);
  }

  void _onClear() {
    setState(() => _display = '0');
    _pulseCtrl.forward(from: 0);
  }

  void _onQuick(double val) {
    setState(() => _display = DateFormatter.formatQuantity(val));
    _pulseCtrl.forward(from: 0);
  }

  void _confirm() {
    final parsed = double.tryParse(_display.replaceAll(',', '.'));
    if (parsed != null && parsed > 0) {
      widget.onConfirm(parsed);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    final parsedVal = double.tryParse(_display.replaceAll(',', '.')) ?? 0;
    final isValid = parsedVal > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calculate_rounded, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "QUANTITÉ",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          "Saisissez la quantité souhaitée",
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // DISPLAY AREA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF0A0A0C), const Color(0xFF101014)]
                          : [Colors.grey.shade50, Colors.grey.shade100],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isValid
                          ? accent.withValues(alpha: 0.4)
                          : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200),
                      width: isValid ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _display,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: isValid
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // QUICK SHORTCUTS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [1.0, 5.0, 10.0, 25.0, 50.0, 100.0].map((v) {
                  final isSelected = parsedVal == v;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => _onQuick(v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent.withValues(alpha: 0.15)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            DateFormatter.formatQuantity(v),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? accent
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // NUMPAD GRID
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _numRow(isDark, ['7', '8', '9']),
                  const SizedBox(height: 6),
                  _numRow(isDark, ['4', '5', '6']),
                  const SizedBox(height: 6),
                  _numRow(isDark, ['1', '2', '3']),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _numKey(isDark, '.', onTap: _onDot),
                      const SizedBox(width: 6),
                      _numKey(isDark, '0', onTap: () => _onDigit('0')),
                      const SizedBox(width: 6),
                      _numKey(isDark, '⌫', onTap: _onBackspace, isAction: true),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ACTIONS
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _onClear,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        "EFFACER",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isValid ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "VALIDER",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: isValid ? Colors.white : Colors.grey.shade500,
                        ),
                      ),
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

  Row _numRow(bool isDark, List<String> digits) {
    return Row(
      children: digits
          .expand((d) => [
                _numKey(isDark, d, onTap: () => _onDigit(d)),
                if (d != digits.last) const SizedBox(width: 6),
              ])
          .toList(),
    );
  }

  Widget _numKey(bool isDark, String label, {required VoidCallback onTap, bool isAction = false}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 48,
            decoration: BoxDecoration(
              color: isAction
                  ? (isDark ? Colors.red.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.06))
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: label == '⌫' ? 18 : 20,
                fontWeight: FontWeight.w800,
                color: isAction
                    ? (isDark ? Colors.red.shade300 : Colors.red.shade400)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ),
      ),
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
