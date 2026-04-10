import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/shop_settings_provider.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';

class EmailSettingsSection extends StatefulWidget {
  final bool emailBackupEnabled;
  final ValueChanged<bool> onEmailBackupEnabledChanged;
  final EmailBackupFrequency emailBackupFrequency;
  final ValueChanged<EmailBackupFrequency> onEmailBackupFrequencyChanged;
  final int emailBackupHour;
  final ValueChanged<int> onEmailBackupHourChanged;
  
  final TextEditingController backupEmailRecipientCtrl;
  final TextEditingController smtpHostCtrl;
  final TextEditingController smtpPortCtrl;
  final TextEditingController smtpUserCtrl;
  final TextEditingController smtpPasswordCtrl;
  final VoidCallback onSaveDebounced;
  final VoidCallback onTestEmail;
  final VoidCallback onTestBackupEmail;

  final bool reportEmailEnabled;
  final ValueChanged<bool> onReportEmailEnabledChanged;
  final bool stockAlertsEnabled;
  final ValueChanged<bool> onStockAlertsEnabledChanged;
  final EmailBackupFrequency reportEmailFrequency;
  final ValueChanged<EmailBackupFrequency> onReportEmailFrequencyChanged;
  final int reportEmailHour;
  final ValueChanged<int> onReportEmailHourChanged;
  final int reportEmailDayOfWeek;
  final ValueChanged<int> onReportEmailDayOfWeekChanged;
  final VoidCallback onTestReportEmail;
  
  final bool marketingEmailsEnabled;
  final ValueChanged<bool> onMarketingEmailsEnabledChanged;
  final bool inactivityReminderEnabled;
  final ValueChanged<bool> onInactivityReminderEnabledChanged;
  final int inactivityDaysThreshold;
  final ValueChanged<int> onInactivityDaysThresholdChanged;
  final VoidCallback onTestMarketingNewProduct;
  final VoidCallback onTestMarketingInactivity;
  
  final bool isCompact;
  final bool showSmtp;
  final bool showReports;
  final bool showMarketing;

  const EmailSettingsSection({
    super.key,
    required this.emailBackupEnabled,
    required this.onEmailBackupEnabledChanged,
    required this.emailBackupFrequency,
    required this.onEmailBackupFrequencyChanged,
    required this.emailBackupHour,
    required this.onEmailBackupHourChanged,
    required this.backupEmailRecipientCtrl,
    required this.smtpHostCtrl,
    required this.smtpPortCtrl,
    required this.smtpUserCtrl,
    required this.smtpPasswordCtrl,
    required this.onSaveDebounced,
    required this.onTestEmail,
    required this.onTestBackupEmail,
    required this.reportEmailEnabled,
    required this.onReportEmailEnabledChanged,
    required this.stockAlertsEnabled,
    required this.onStockAlertsEnabledChanged,
    required this.reportEmailFrequency,
    required this.onReportEmailFrequencyChanged,
    required this.reportEmailHour,
    required this.onReportEmailHourChanged,
    required this.reportEmailDayOfWeek,
    required this.onReportEmailDayOfWeekChanged,
    required this.onTestReportEmail,
    required this.marketingEmailsEnabled,
    required this.onMarketingEmailsEnabledChanged,
    required this.inactivityReminderEnabled,
    required this.onInactivityReminderEnabledChanged,
    required this.inactivityDaysThreshold,
    required this.onInactivityDaysThresholdChanged,
    required this.onTestMarketingNewProduct,
    required this.onTestMarketingInactivity,
    this.isCompact = false,
    this.showSmtp = true,
    this.showReports = true,
    this.showMarketing = true,
  });

  @override
  State<EmailSettingsSection> createState() => _EmailSettingsSectionState();
}

class _EmailSettingsSectionState extends State<EmailSettingsSection> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    if (widget.isCompact) {
      return _buildCompactSmtpAndSchedule(c);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        
        return Column(
          children: [
            // ═══════════════════════════════════════
            // SECTION 1 : CONNEXION SMTP + DESTINATAIRE
            // ═══════════════════════════════════════
            if (widget.showSmtp) ...[
              PremiumSettingsWidgets.buildSectionHeader(context, 
                
                icon: FluentIcons.mail_24_filled,
                title: "Configuration du serveur de messagerie",
                subtitle: "Paramétrez votre serveur SMTP pour l'envoi d'emails depuis Danaya+",
                color: c.amber,
              ),
              const SizedBox(height: 12),
              _buildSmtpAndRecipientSection(c, isNarrow),
              const SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════
            // SECTION 2 : AUTOMATISATION
            // ═══════════════════════════════════════
            if (widget.showReports) ...[
              PremiumSettingsWidgets.buildSectionHeader(context, 
                
                icon: FluentIcons.timer_24_filled,
                title: "Automatisation & Planification",
                subtitle: "Sauvegardes automatiques et rapports financiers programmés",
                color: c.blue,
              ),
              const SizedBox(height: 12),
              _buildAutomationSection(c, isNarrow),
              const SizedBox(height: 24),
            ],

            // ═══════════════════════════════════════
            // SECTION 3 : MARKETING & CRM
            // ═══════════════════════════════════════
            if (widget.showMarketing) ...[
              PremiumSettingsWidgets.buildSectionHeader(context, 
                
                icon: FluentIcons.megaphone_24_filled,
                title: "Engagement Client",
                subtitle: "Newsletters, alertes et relances automatiques",
                color: c.violet,
              ),
              const SizedBox(height: 12),
              _buildMarketingSection(c, isNarrow),
            ],
          ],
        ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOutQuad);
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // SECTION 1 : SMTP + DESTINATAIRE
  // ═══════════════════════════════════════════════════

  Widget _buildSmtpAndRecipientSection(DashColors c, bool isNarrow) {
    final smtpContent = PremiumSettingsWidgets.buildCard(context, 
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête SMTP
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.server_20_filled, color: c.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SERVEUR SMTP", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: c.textPrimary, letterSpacing: 0.5)),
                    Text("Moteur d'expédition email", style: TextStyle(fontSize: 9, color: c.textMuted)),
                  ],
                ),
              ),
              // Indicateur de statut
              PremiumSettingsWidgets.buildStatusDot(
                active: widget.smtpUserCtrl.text.isNotEmpty && widget.smtpPasswordCtrl.text.isNotEmpty,
                activeLabel: "Configuré",
                inactiveLabel: "Non configuré",
                
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ligne 1 : Hôte + Port
          Row(
            children: [
              Expanded(
                flex: 7,
                child: PremiumSettingsWidgets.buildCompactField(
                  context,
                   label: "Serveur hôte", hint: "smtp.gmail.com",
                  icon: FluentIcons.globe_16_regular, controller: widget.smtpHostCtrl,
                  color: c.amber, onChanged: widget.onSaveDebounced,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: PremiumSettingsWidgets.buildCompactField(
                  context,
                   label: "Port", hint: "587",
                  icon: FluentIcons.plug_connected_16_regular, controller: widget.smtpPortCtrl,
                  color: c.amber, onChanged: widget.onSaveDebounced, isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Ligne 2 : Compte + Mot de passe
          Row(
            children: [
              Expanded(
                child: PremiumSettingsWidgets.buildCompactField(
                  context,
                   label: "Compte utilisateur", hint: "boutique@gmail.com",
                  icon: FluentIcons.person_16_regular, controller: widget.smtpUserCtrl,
                  color: c.amber, onChanged: widget.onSaveDebounced,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PremiumSettingsWidgets.buildCompactField(
                  context,
                   label: "Mot de passe d'application", hint: "••••••••••••",
                  icon: FluentIcons.key_16_regular, controller: widget.smtpPasswordCtrl,
                  color: c.amber, onChanged: widget.onSaveDebounced,
                  isPassword: true, showPassword: _showPassword,
                  onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Liens d'aide Google App Password
          _buildAppPasswordHelp(c),

          const SizedBox(height: 16),

          // Bouton test
          PremiumSettingsWidgets.buildGradientBtn(
            onPressed: widget.onTestEmail,
            icon: FluentIcons.mail_checkmark_16_filled,
            label: "TESTER LA CONNEXION SMTP",
            colors: [c.amber, Colors.orange.shade700],
          ),
        ],
      ),
    );

    final recipientContent = PremiumSettingsWidgets.buildCard(context, 
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.mail_read_20_filled, color: c.rose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ADMINISTRATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: c.textPrimary, letterSpacing: 0.5)),
                    Text("Réception & Alertes système", style: TextStyle(fontSize: 9, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          PremiumSettingsWidgets.buildCompactField(
                  context,
             label: "Email du magasin / gérant",
            hint: "admin@votre-boutique.com",
            icon: FluentIcons.send_16_regular, controller: widget.backupEmailRecipientCtrl,
            color: c.rose, onChanged: widget.onSaveDebounced,
          ),
          const SizedBox(height: 14),

          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            
            title: "Alerte de rupture de stock",
            subtitle: "Email immédiat si un produit passe sous le seuil d'alerte",
            value: widget.stockAlertsEnabled,
            onChanged: widget.onStockAlertsEnabledChanged,
            activeColor: c.rose,
            icon: FluentIcons.warning_16_filled,
          ),

          const SizedBox(height: 14),
          // Info box
PremiumSettingsWidgets.buildInfoBox(
            context,
            text: "Cet email recevra les sauvegardes, rapports et alertes système.",
            color: c.rose,
            icon: FluentIcons.info_16_regular,
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(children: [smtpContent, const SizedBox(height: 12), recipientContent]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: smtpContent),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: recipientContent),
      ],
    );
  }

  Widget _buildAppPasswordHelp(DashColors c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.amber.withValues(alpha: 0.08), c.amber.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.amber.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.shield_keyhole_16_filled, size: 14, color: c.amber),
              const SizedBox(width: 8),
              Text("COMMENT OBTENIR UN MOT DE PASSE D'APPLICATION ?", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.amber, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Gmail et d'autres fournisseurs exigent un « mot de passe d'application » au lieu de votre mot de passe habituel. Cliquez sur le lien correspondant à votre fournisseur :",
            style: TextStyle(fontSize: 9.5, color: c.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ProviderLink(
                label: "Google (Gmail)",
                url: "https://myaccount.google.com/apppasswords",
                color: const Color(0xFF4285F4),
                icon: FluentIcons.mail_16_regular,
                
              ),
              _ProviderLink(
                label: "Outlook / Hotmail",
                url: "https://account.live.com/proofs/AppPassword",
                color: const Color(0xFF0078D4),
                icon: FluentIcons.mail_16_regular,
                
              ),
              _ProviderLink(
                label: "Yahoo",
                url: "https://login.yahoo.com/account/security/app-passwords",
                color: const Color(0xFF6001D2),
                icon: FluentIcons.mail_16_regular,
                
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(FluentIcons.lightbulb_16_regular, size: 12, color: c.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Astuce : Activez d'abord la vérification en 2 étapes sur votre compte, puis créez un mot de passe d'application dédié à Danaya+.",
                  style: TextStyle(fontSize: 8.5, color: c.textMuted, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // SECTION 2 : AUTOMATISATION
  // ═══════════════════════════════════════════════════

  Widget _buildAutomationSection(DashColors c, bool isNarrow) {
    final backupCard = PremiumSettingsWidgets.buildCard(context, 
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.cloud_arrow_up_20_filled, color: c.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SAUVEGARDE CLOUD", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: c.textPrimary, letterSpacing: 0.5)),
                    Text("Archive GZ chiffrée de votre base de données", style: TextStyle(fontSize: 9, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            
            title: "Sauvegarde automatique par email",
            subtitle: "Envoi programmé de votre base de données",
            value: widget.emailBackupEnabled,
            onChanged: widget.onEmailBackupEnabledChanged,
            activeColor: c.blue,
            icon: FluentIcons.database_16_filled,
          ),

          if (widget.emailBackupEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactDropdown<EmailBackupFrequency>(context, 
                     label: "Fréquence", value: widget.emailBackupFrequency, color: c.blue,
                    items: [
                      DropdownMenuItem(value: EmailBackupFrequency.daily, child: Text("Quotidien", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: EmailBackupFrequency.weekly, child: Text("Hebdomadaire", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: EmailBackupFrequency.monthly, child: Text("Mensuel", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (v) => widget.onEmailBackupFrequencyChanged(v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactDropdown<int>(context, 
                     label: "Heure d'envoi", value: widget.emailBackupHour, color: c.blue,
                    items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text("${i.toString().padLeft(2, '0')}:00", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)))),
                    onChanged: (v) => widget.onEmailBackupHourChanged(v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PremiumSettingsWidgets.buildGradientBtn(
              onPressed: widget.onTestBackupEmail,
              icon: FluentIcons.cloud_arrow_up_16_filled,
              label: "TESTER LE BACKUP CLOUD",
              colors: [c.blue, Colors.indigo],
            ),
          ],
        ],
      ),
    );

    final reportCard = PremiumSettingsWidgets.buildCard(context, 
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.document_pdf_20_filled, color: c.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("RAPPORTS FINANCIERS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: c.textPrimary, letterSpacing: 0.5)),
                    Text("Envoi automatique de rapports PDF détaillés", style: TextStyle(fontSize: 9, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            
            title: "Rapports financiers automatiques",
            subtitle: "Envoi périodique du bilan des ventes en PDF",
            value: widget.reportEmailEnabled,
            onChanged: widget.onReportEmailEnabledChanged,
            activeColor: c.cyan,
            icon: FluentIcons.data_bar_vertical_16_filled,
          ),

          if (widget.reportEmailEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactDropdown<EmailBackupFrequency>(context, 
                     label: "Fréquence", value: widget.reportEmailFrequency, color: c.cyan,
                    items: [
                      DropdownMenuItem(value: EmailBackupFrequency.daily, child: Text("Quotidien", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: EmailBackupFrequency.weekly, child: Text("Hebdomadaire", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: EmailBackupFrequency.monthly, child: Text("Mensuel", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (v) => widget.onReportEmailFrequencyChanged(v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactDropdown<int>(context, 
                     label: "Heure", value: widget.reportEmailHour, color: c.cyan,
                    items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text("${i.toString().padLeft(2, '0')}:00", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)))),
                    onChanged: (v) => widget.onReportEmailHourChanged(v!),
                  ),
                ),
              ],
            ),
            if (widget.reportEmailFrequency == EmailBackupFrequency.weekly) ...[
              const SizedBox(height: 10),
              PremiumSettingsWidgets.buildCompactDropdown<int>(context, 
                 label: "Jour de la semaine", value: widget.reportEmailDayOfWeek, color: c.cyan,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Lundi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 2, child: Text("Mardi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 3, child: Text("Mercredi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 4, child: Text("Jeudi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 5, child: Text("Vendredi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 6, child: Text("Samedi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  DropdownMenuItem(value: 7, child: Text("Dimanche", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                ],
                onChanged: (v) => widget.onReportEmailDayOfWeekChanged(v!),
              ),
            ],
            const SizedBox(height: 14),
            PremiumSettingsWidgets.buildGradientBtn(
              onPressed: widget.onTestReportEmail,
              icon: FluentIcons.send_16_filled,
              label: "TESTER LE RAPPORT",
              colors: [c.cyan, Colors.lightBlue.shade700],
            ),
          ],
        ],
      ),
    );

    if (isNarrow) {
      return Column(children: [backupCard, const SizedBox(height: 12), reportCard]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: backupCard),
        const SizedBox(width: 12),
        Expanded(child: reportCard),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // SECTION 3 : MARKETING
  // ═══════════════════════════════════════════════════

  Widget _buildMarketingSection(DashColors c, bool isNarrow) {
    return PremiumSettingsWidgets.buildCard(context, 
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.megaphone_20_filled, color: c.violet),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("MARKETING & CRM", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: c.textPrimary, letterSpacing: 0.5)),
                    Text("Fidélisation et relance automatique des clients", style: TextStyle(fontSize: 9, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            
            title: "Newsletters magasin",
            subtitle: "Nouveautés envoyées automatiquement à vos clients ayant un email",
            value: widget.marketingEmailsEnabled,
            onChanged: widget.onMarketingEmailsEnabledChanged,
            activeColor: c.violet,
            icon: FluentIcons.mail_inbox_16_filled,
          ),

          if (widget.marketingEmailsEnabled) ...[
            const SizedBox(height: 12),
            PremiumSettingsWidgets.buildCompactSwitch(
            context,
              
              title: "Relance inactivité",
              subtitle: "Envoyer un email aux clients inactifs pour les réengager",
              value: widget.inactivityReminderEnabled,
              onChanged: widget.onInactivityReminderEnabledChanged,
              activeColor: c.violet,
              icon: FluentIcons.person_clock_16_regular,
            ),
            if (widget.inactivityReminderEnabled) ...[
              const SizedBox(height: 10),
              PremiumSettingsWidgets.buildCompactDropdown<int>(context, 
                 label: "Déclencher l'email après", value: widget.inactivityDaysThreshold, color: c.violet,
                items: [7, 14, 30, 60, 90].map((d) => DropdownMenuItem(value: d, child: Text("$d jours sans achat", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)))).toList(),
                onChanged: (v) => widget.onInactivityDaysThresholdChanged(v!),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PremiumSettingsWidgets.buildGradientBtn(
                    onPressed: widget.onTestMarketingNewProduct,
                    icon: FluentIcons.flash_16_filled,
                    label: "TEST NEWSLETTER",
                    colors: [c.violet, Colors.deepPurple],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PremiumSettingsWidgets.buildGradientBtn(
                    onPressed: widget.onTestMarketingInactivity,
                    icon: FluentIcons.history_16_filled,
                    label: "TEST RELANCE",
                    colors: [Colors.grey.shade600, Colors.grey.shade700],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // MODE COMPACT (utilisé dans d'autres sections)
  // ═══════════════════════════════════════════════════

  Widget _buildCompactSmtpAndSchedule(DashColors c) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: c.amber.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: c.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(FluentIcons.server_20_filled, color: c.amber, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text("FLUX SORTANTS (SMTP)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0)),
                ],
              ),
              const SizedBox(height: 20),
              PremiumSettingsWidgets.buildCompactField(
                  context, label: "SERVEUR HÔTE", hint: "smtp.gmail.com", icon: FluentIcons.desktop_20_regular, controller: widget.smtpHostCtrl, color: c.amber, onChanged: widget.onSaveDebounced),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: PremiumSettingsWidgets.buildCompactField(
                  context, label: "COMPTE", hint: "user@mail.com", icon: FluentIcons.person_20_regular, controller: widget.smtpUserCtrl, color: c.amber, onChanged: widget.onSaveDebounced)),
                  const SizedBox(width: 12),
                  Expanded(child: PremiumSettingsWidgets.buildCompactField(
                  context, label: "PASS APP", hint: "••••", icon: FluentIcons.key_20_regular, controller: widget.smtpPasswordCtrl, color: c.amber, isPassword: true, onChanged: widget.onSaveDebounced)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, thickness: 1),
              ),
              Row(
                children: [
                  Icon(FluentIcons.clock_20_filled, color: c.blue, size: 18),
                  const SizedBox(width: 10),
                  const Text("PLANIFICATION AUTO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0)),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(value: widget.emailBackupEnabled, onChanged: widget.onEmailBackupEnabledChanged, activeTrackColor: c.blue),
                  ),
                ],
              ),
              if (widget.emailBackupEnabled) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildEliteDropdown<EmailBackupFrequency>(c, widget.emailBackupFrequency, [EmailBackupFrequency.daily, EmailBackupFrequency.weekly], (v) => widget.onEmailBackupFrequencyChanged(v!))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildEliteDropdown<int>(c, widget.emailBackupHour, [0, 12, 18, 22], (v) => widget.onEmailBackupHourChanged(v!))),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              PremiumSettingsWidgets.buildGradientBtn(
                onPressed: widget.onTestEmail,
                icon: FluentIcons.mail_alert_20_filled,
                label: "TESTER LA CONNEXION",
                colors: [c.amber, Colors.orange.shade700],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEliteDropdown<T>(DashColors c, T val, List<T> items, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: val,
          isExpanded: true,
          iconSize: 18,
          iconEnabledColor: c.blue,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i is EmailBackupFrequency ? (i == EmailBackupFrequency.daily ? "Journalier" : "Hebdomadaire") : "$i:00", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// COMPOSANTS RÉUTILISABLES
// ═══════════════════════════════════════════════════

// Widgets supprimés car extraits dans PremiumSettingsWidgets

class _ProviderLink extends StatelessWidget {
  final String label;
  final String url;
  final Color color;
  final IconData icon;
  
  const _ProviderLink({required this.label, required this.url, required this.color, required this.icon, });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(FluentIcons.open_16_regular, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}
