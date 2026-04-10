import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:danaya_plus/features/settings/presentation/widgets/database_section.dart';
import 'package:danaya_plus/features/settings/presentation/widgets/email_section.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

class BackupCloudDashboard extends ConsumerWidget {
  // DB Props
  final Map<String, dynamic> dbStats;
  final bool autoBackupEnabled;
  final ValueChanged<bool> onAutoBackupEnabledChanged;
  final List<FileSystemEntity> autoBackups;
  final VoidCallback onBackupDatabase;
  final VoidCallback onRestoreDatabase;
  final Function(FileSystemEntity) onRestoreSpecificBackup;
  final VoidCallback onConfirmResetDb;
  final VoidCallback onRecalculateWac;
  final VoidCallback onCleanupImages;
  
  // Cloud Mirror Props
  final String? cloudBackupPath;
  final ValueChanged<String?> onCloudBackupPathChanged;

  // Email/SMTP/Automation Props
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

  const BackupCloudDashboard({
    super.key,
    required this.dbStats,
    required this.autoBackupEnabled,
    required this.onAutoBackupEnabledChanged,
    required this.autoBackups,
    required this.onBackupDatabase,
    required this.onRestoreDatabase,
    required this.onRestoreSpecificBackup,
    required this.onConfirmResetDb,
    required this.onRecalculateWac,
    required this.onCleanupImages,
    required this.cloudBackupPath,
    required this.onCloudBackupPathChanged,
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======= HEADER PRESTIGE =======
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.security_update_good_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CENTRE DE CONTRÔLE DONNÉES",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                        Text(
                          "Protection Danaya Vault • Sauvegardes & Synchronisation Cloud",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.05, end: 0),

          // ======= LIGNE 1 : CORE DATA (Grid 2 colonnes) =======
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne 1 : État Database & Miroir
              Expanded(
                flex: 3,
                child: DatabaseSettingsSection(
                  dbStats: dbStats,
                  autoBackupEnabled: autoBackupEnabled,
                  onAutoBackupEnabledChanged: onAutoBackupEnabledChanged,
                  autoBackups: autoBackups,
                  onBackupDatabase: onBackupDatabase,
                  onRestoreDatabase: onRestoreDatabase,
                  onRestoreSpecificBackup: onRestoreSpecificBackup,
                  onConfirmResetDb: onConfirmResetDb,
                  onRecalculateWac: onRecalculateWac,
                  onCleanupImages: onCleanupImages,
                  cloudBackupPath: cloudBackupPath,
                  onCloudBackupPathChanged: onCloudBackupPathChanged,
                  onSaveDebounced: onSaveDebounced,
                  isCompact: true,
                ),
              ),
              const SizedBox(width: 16),
              
              // Colonne 2 : SMTP & Planification Backup (COMPACT)
              Expanded(
                flex: 2,
                child: EmailSettingsSection(
                  emailBackupEnabled: emailBackupEnabled,
                  onEmailBackupEnabledChanged: onEmailBackupEnabledChanged,
                  emailBackupFrequency: emailBackupFrequency,
                  onEmailBackupFrequencyChanged: onEmailBackupFrequencyChanged,
                  emailBackupHour: emailBackupHour,
                  onEmailBackupHourChanged: onEmailBackupHourChanged,
                  backupEmailRecipientCtrl: backupEmailRecipientCtrl,
                  smtpHostCtrl: smtpHostCtrl,
                  smtpPortCtrl: smtpPortCtrl,
                  smtpUserCtrl: smtpUserCtrl,
                  smtpPasswordCtrl: smtpPasswordCtrl,
                  onSaveDebounced: onSaveDebounced,
                  onTestEmail: onTestEmail,
                  onTestBackupEmail: onTestBackupEmail,
                  
                  // Hidden props
                  reportEmailEnabled: false,
                  onReportEmailEnabledChanged: (_) {},
                  stockAlertsEnabled: false,
                  onStockAlertsEnabledChanged: (_) {},
                  reportEmailFrequency: EmailBackupFrequency.daily,
                  onReportEmailFrequencyChanged: (_) {},
                  reportEmailHour: 0,
                  onReportEmailHourChanged: (_) {},
                  reportEmailDayOfWeek: 0,
                  onReportEmailDayOfWeekChanged: (_) {},
                  onTestReportEmail: () {},
                  marketingEmailsEnabled: false,
                  onMarketingEmailsEnabledChanged: (_) {},
                  inactivityReminderEnabled: false,
                  onInactivityReminderEnabledChanged: (_) {},
                  inactivityDaysThreshold: 30,
                  onInactivityDaysThresholdChanged: (_) {},
                  onTestMarketingNewProduct: () {},
                  onTestMarketingInactivity: () {},
                  
                  isCompact: true,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // ======= LIGNE 2 : RAPPORT & MARKETING (Bento Row) =======
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Rapports & Automations
               Expanded(
                 child: EmailSettingsSection(
                    showSmtp: false, // Hidden since already in Compact mode above
                    showReports: true,
                    showMarketing: false,
                    
                    reportEmailEnabled: reportEmailEnabled,
                    onReportEmailEnabledChanged: onReportEmailEnabledChanged,
                    stockAlertsEnabled: stockAlertsEnabled,
                    onStockAlertsEnabledChanged: onStockAlertsEnabledChanged,
                    reportEmailFrequency: reportEmailFrequency,
                    onReportEmailFrequencyChanged: onReportEmailFrequencyChanged,
                    reportEmailHour: reportEmailHour,
                    onReportEmailHourChanged: onReportEmailHourChanged,
                    reportEmailDayOfWeek: reportEmailDayOfWeek,
                    onReportEmailDayOfWeekChanged: onReportEmailDayOfWeekChanged,
                    onTestReportEmail: onTestReportEmail,
                    backupEmailRecipientCtrl: backupEmailRecipientCtrl,
                    onSaveDebounced: onSaveDebounced,

                    // Placeholders
                    emailBackupEnabled: false,
                    onEmailBackupEnabledChanged: (_) {},
                    emailBackupFrequency: EmailBackupFrequency.daily,
                    onEmailBackupFrequencyChanged: (_) {},
                    emailBackupHour: 0,
                    onEmailBackupHourChanged: (_) {},
                    smtpHostCtrl: TextEditingController(),
                    smtpPortCtrl: TextEditingController(),
                    smtpUserCtrl: TextEditingController(),
                    smtpPasswordCtrl: TextEditingController(),
                    onTestEmail: () {},
                    onTestBackupEmail: () {},
                    marketingEmailsEnabled: false,
                    onMarketingEmailsEnabledChanged: (_) {},
                    inactivityReminderEnabled: false,
                    onInactivityReminderEnabledChanged: (_) {},
                    inactivityDaysThreshold: 30,
                    onInactivityDaysThresholdChanged: (_) {},
                    onTestMarketingNewProduct: () {},
                    onTestMarketingInactivity: () {},
                 ),
               ),
               const SizedBox(width: 16),
               // Engagement Client
               Expanded(
                 child: EmailSettingsSection(
                    showSmtp: false,
                    showReports: false,
                    showMarketing: true,
                    
                    marketingEmailsEnabled: marketingEmailsEnabled,
                    onMarketingEmailsEnabledChanged: onMarketingEmailsEnabledChanged,
                    inactivityReminderEnabled: inactivityReminderEnabled,
                    onInactivityReminderEnabledChanged: onInactivityReminderEnabledChanged,
                    inactivityDaysThreshold: inactivityDaysThreshold,
                    onInactivityDaysThresholdChanged: onInactivityDaysThresholdChanged,
                    onTestMarketingNewProduct: onTestMarketingNewProduct,
                    onTestMarketingInactivity: onTestMarketingInactivity,
                    onSaveDebounced: onSaveDebounced,

                    // Placeholders
                    reportEmailEnabled: false,
                    onReportEmailEnabledChanged: (_) {},
                    stockAlertsEnabled: false,
                    onStockAlertsEnabledChanged: (_) {},
                    reportEmailFrequency: EmailBackupFrequency.daily,
                    onReportEmailFrequencyChanged: (_) {},
                    reportEmailHour: 0,
                    onReportEmailHourChanged: (_) {},
                    reportEmailDayOfWeek: 0,
                    onReportEmailDayOfWeekChanged: (_) {},
                    onTestReportEmail: () {},
                    emailBackupEnabled: false,
                    onEmailBackupEnabledChanged: (_) {},
                    emailBackupFrequency: EmailBackupFrequency.daily,
                    onEmailBackupFrequencyChanged: (_) {},
                    emailBackupHour: 0,
                    onEmailBackupHourChanged: (_) {},
                    backupEmailRecipientCtrl: TextEditingController(),
                    smtpHostCtrl: TextEditingController(),
                    smtpPortCtrl: TextEditingController(),
                    smtpUserCtrl: TextEditingController(),
                    smtpPasswordCtrl: TextEditingController(),
                    onTestEmail: () {},
                    onTestBackupEmail: () {},
                 ),
               ),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
