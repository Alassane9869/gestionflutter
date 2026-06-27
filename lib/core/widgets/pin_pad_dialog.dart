import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PIN PAD DIALOG (SHARED)
// ─────────────────────────────────────────────────────────────────────────────

class PinPadDialog extends StatefulWidget {
  final String? correctPin;
  final Future<bool> Function(String pin)? onVerify;
  final String title;

  const PinPadDialog({
    super.key,
    this.correctPin,
    this.onVerify,
    this.title = "Autorisation Requise",
  }) : assert(correctPin != null || onVerify != null, "Either correctPin or onVerify must be provided");

  @override
  State<PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends State<PinPadDialog> {
  String _input = "";
  bool _isVerifying = false;

  void _add(String d) async {
    if (_isVerifying) return;
    
    if (_input.length < 4) {
      setState(() => _input += d);
      if (_input.length == 4) {
        setState(() => _isVerifying = true);
        
        bool success = false;
        if (widget.onVerify != null) {
          success = await widget.onVerify!(_input);
        } else if (widget.correctPin != null) {
          // Si le PIN stocké fait 64 caractères, c'est un hash. On hache l'entrée pour comparer.
          if (widget.correctPin!.length == 64) {
            final hashedInput = sha256.convert(utf8.encode("${_input}danaya_manager_pepper_2024")).toString();
            success = (hashedInput == widget.correctPin);
          } else {
            // Mode legacy : Comparaison en clair (sera migré au prochain save/build)
            success = (_input == widget.correctPin);
          }
        }

        if (!mounted) return;

        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() {
            _input = "";
            _isVerifying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Code PIN incorrect")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.lock_shield_24_regular, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _isVerifying ? "Vérification en cours..." : "Entrez le PIN Manager pour continuer",
                style: TextStyle(color: _isVerifying ? Colors.orange : Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final active = i < _input.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? Colors.orange : (isDark ? Colors.white10 : Colors.grey.shade200),
                      border: Border.all(
                        color: active ? Colors.orange : (isDark ? Colors.white10 : Colors.grey.shade300),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // Keypad
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...["1", "2", "3", "4", "5", "6", "7", "8", "9"].map((d) => _PinBtn(d, () => _add(d))),
                  const SizedBox(),
                  _PinBtn("0", () => _add("0")),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PinBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
