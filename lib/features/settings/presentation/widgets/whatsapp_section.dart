import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';

class WhatsappSettingsSection extends StatefulWidget {
  final TextEditingController whatsappTokenCtrl;
  final TextEditingController whatsappPhoneNumberIdCtrl;
  final VoidCallback onSaveDebounced;

  const WhatsappSettingsSection({
    super.key,
    required this.whatsappTokenCtrl,
    required this.whatsappPhoneNumberIdCtrl,
    required this.onSaveDebounced,
  });

  @override
  State<WhatsappSettingsSection> createState() => _WhatsappSettingsSectionState();
}

class _WhatsappSettingsSectionState extends State<WhatsappSettingsSection> {
  bool _showToken = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.chat_24_filled, color: Colors.green),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("API WHATSAPP CLOUD (META)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c.textPrimary, letterSpacing: 0.5)),
                          Text("Connexion officielle pour l'envoi de factures et alertes", style: TextStyle(fontSize: 12, color: c.textMuted)),
                        ],
                      ),
                    ),
                    PremiumSettingsWidgets.buildStatusDot(
                      active: widget.whatsappTokenCtrl.text.isNotEmpty && widget.whatsappPhoneNumberIdCtrl.text.isNotEmpty,
                      activeLabel: "CONNECTÉ",
                      inactiveLabel: "HORS LIGNE",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Inputs
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: PremiumSettingsWidgets.buildCompactField(
                      context,
                      label: "Phone Number ID (ID du Numéro)",
                      hint: "Ex: 104857395837492",
                      icon: FluentIcons.phone_24_regular,
                      controller: widget.whatsappPhoneNumberIdCtrl,
                      color: Colors.green,
                      onChanged: widget.onSaveDebounced,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: PremiumSettingsWidgets.buildCompactField(
                      context,
                      label: "Access Token (Jeton Meta)",
                      hint: "EAAI...",
                      icon: FluentIcons.key_24_regular,
                      controller: widget.whatsappTokenCtrl,
                      color: Colors.green,
                      isPassword: true,
                      showPassword: _showToken,
                      onTogglePassword: () => setState(() => _showToken = !_showToken),
                      onChanged: widget.onSaveDebounced,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Helper Box
              PremiumSettingsWidgets.buildInfoBox(
                context,
                text: "Ces identifiants sont fournis par votre tableau de bord Meta for Developers. Ils sont obligatoires si vous souhaitez que les envois se fassent automatiquement en arrière-plan sans ouvrir l'application WhatsApp.",
                color: Colors.green,
                icon: FluentIcons.info_16_regular,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
