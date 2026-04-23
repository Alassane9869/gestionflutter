import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';

class GeneralSettingsSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController sloganCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController whatsappCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController addressCtrl;
  final String? logoPath;
  final VoidCallback onPickLogo;
  final VoidCallback onRemoveLogo;
  final VoidCallback onSaveDebounced;

  const GeneralSettingsSection({
    super.key,
    required this.nameCtrl,
    required this.sloganCtrl,
    required this.phoneCtrl,
    required this.whatsappCtrl,
    required this.emailCtrl,
    required this.addressCtrl,
    required this.logoPath,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.onSaveDebounced,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION 1 : IDENTITÉ
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.building_shop_24_filled,
          title: "Identité de l'entreprise",
          subtitle: "Ces informations apparaîtront sur vos documents officiels",
          color: c.blue,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: isNarrow 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Center(child: _buildLogoPicker(context, c)),
                   const SizedBox(height: 20),
                   ..._buildIdentityFields(context, c),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogoPicker(context, c),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildIdentityFields(context, c),
                    ),
                  ),
                ],
              ),
        ),

        const SizedBox(height: 24),

        // SECTION 2 : CONTACT & LOCALISATION
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.contact_card_24_filled,
          title: "Contact & Localisation",
          subtitle: "Coordonnées pour vos clients et fournisseurs",
          color: c.rose,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context,
                      label: "Ligne directe",
                      hint: "+223 00 00 00 00",
                      icon: FluentIcons.call_20_regular,
                      controller: phoneCtrl,
                      color: c.rose,
                      onChanged: onSaveDebounced,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PremiumSettingsWidgets.buildCompactField(
                      context,
                      label: "WhatsApp Business",
                      hint: "+223 00 00 00 00",
                      icon: FluentIcons.chat_20_regular,
                      controller: whatsappCtrl,
                      color: c.rose,
                      onChanged: onSaveDebounced,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildCompactField(
                context,
                label: "Adresse E-mail",
                hint: "contact@entreprise.com",
                icon: FluentIcons.mail_20_regular,
                controller: emailCtrl,
                color: c.rose,
                onChanged: onSaveDebounced,
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildCompactField(
                context,
                label: "Siège Social & Adresse",
                hint: "Bamako, Mali - Rue 123, Porte 45",
                icon: FluentIcons.location_20_regular,
                controller: addressCtrl,
                color: c.rose,
                maxLines: 2,
                onChanged: onSaveDebounced,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // SECTION 3 : ÉTAT DU SYSTÈME
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.shield_24_filled,
          title: "Système & Sécurité",
          subtitle: "Informations techniques sur votre moteur Danaya+ Pro",
          color: c.emerald,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusRow(
                context,
                label: "VERSION DU LOGICIEL",
                value: "1.0.1+SupremeAudit",
                icon: FluentIcons.star_24_regular,
                color: c.violet,
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _buildStatusRow(
                context,
                label: "MOTEUR DE RECHERCHE",
                value: "SQLite FTS5 (Ultra Performance)",
                icon: FluentIcons.flash_24_regular,
                color: c.emerald,
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _buildStatusRow(
                context,
                label: "AUDIT D'INTÉGRITÉ",
                value: "Activé (Balance Snapshots)",
                icon: FluentIcons.history_24_regular,
                color: c.blue,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  List<Widget> _buildIdentityFields(BuildContext context, DashColors c) {
    return [
      PremiumSettingsWidgets.buildCompactField(
        context,
        label: "Nom commercial",
        hint: "Ex: Danaya Boutique",
        icon: FluentIcons.building_20_regular,
        controller: nameCtrl,
        color: c.blue,
        onChanged: onSaveDebounced,
      ),
      const SizedBox(height: 14),
      PremiumSettingsWidgets.buildCompactField(
        context,
        label: "Slogan / Accroche",
        hint: "L'excellence à votre service",
        icon: FluentIcons.text_quote_20_regular,
        controller: sloganCtrl,
        color: c.blue,
        onChanged: onSaveDebounced,
      ),
    ];
  }

  Widget _buildStatusRow(BuildContext context, {required String label, required String value, required IconData icon, required Color color}) {
    final c = DashColors.of(context);
    return Row(
      children: [
        PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary)),
            ],
          ),
        ),
        PremiumSettingsWidgets.buildStatusDot(
          active: true,
          activeLabel: "En ligne",
          inactiveLabel: "Hors ligne",
        ),
      ],
    );
  }

  Widget _buildLogoPicker(BuildContext context, DashColors c) {
    final hasLogo = logoPath != null && File(logoPath!).existsSync();
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            onPickLogo();
            onSaveDebounced();
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: c.surfaceElev,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1), width: 1.5),
              boxShadow: [
                BoxShadow(color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
              image: hasLogo
                  ? DecorationImage(
                      image: FileImage(File(logoPath!)),
                      fit: BoxFit.contain,
                    )
                  : null,
            ),
            child: !hasLogo
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.image_add_24_regular, size: 32, color: c.blue.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text("LOGO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c.textMuted, letterSpacing: 1)),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallActionBtn(
                icon: FluentIcons.camera_edit_20_regular,
                onTap: () {
                  onPickLogo();
                  onSaveDebounced();
                },
                c: c,
                tooltip: "Modifier"),
            if (hasLogo) ...[
              const SizedBox(width: 8),
              _SmallActionBtn(
                  icon: FluentIcons.delete_20_regular,
                  onTap: () {
                    onRemoveLogo();
                    onSaveDebounced();
                  },
                  c: c,
                  color: c.rose,
                  tooltip: "Supprimer"),
            ],
          ],
        ),
      ],
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final DashColors c;
  final Color? color;
  final String tooltip;
  const _SmallActionBtn({required this.icon, required this.onTap, required this.c, this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? c.blue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color ?? c.blue),
        ),
      ),
    );
  }
}
