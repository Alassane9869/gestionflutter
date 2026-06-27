import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart'; // Pour DashColors

class LicenseSettingsSection extends StatelessWidget {
  final int? daysRemaining;
  final VoidCallback onRenew;
  final VoidCallback onViewTos;
  final VoidCallback onShowRecoveryKey;

  const LicenseSettingsSection({
    super.key,
    required this.daysRemaining,
    required this.onRenew,
    required this.onViewTos,
    required this.onShowRecoveryKey,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.key_24_filled, color: c.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("LICENCE PRO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c.blue, letterSpacing: 1.0)),
                    const SizedBox(height: 2),
                    Text("Actif • Danaya+ v6.4", style: TextStyle(fontSize: 13, color: c.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (daysRemaining != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(8)),
                  child: Text("$daysRemaining Jours", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onShowRecoveryKey,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.wrench_16_filled, size: 18, color: c.amber),
                        const SizedBox(width: 6),
                        Text("CLÉ DE SECOURS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c.amber)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumSettingsWidgets.buildGradientBtn(
                  onPressed: onRenew,
                  icon: FluentIcons.shopping_bag_16_filled,
                  label: "GÉRER",
                  colors: [c.blue, const Color(0xFF4A90E2)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: InkWell(
              onTap: onViewTos,
              child: Text(
                "Conditions d'Utilisation",
                style: TextStyle(fontSize: 12, color: c.textMuted, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
