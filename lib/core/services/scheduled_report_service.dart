import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/reports/providers/report_providers.dart';
import 'package:danaya_plus/features/reports/services/pdf_report_service.dart';
import 'package:danaya_plus/features/reports/services/excel_export_service.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:intl/date_symbol_data_local.dart';

final scheduledReportServiceProvider = Provider<ScheduledReportService>((ref) {
  return ScheduledReportService(ref);
});

class ScheduledReportService {
  final Ref ref;

  ScheduledReportService(this.ref);

  /// Checks if a scheduled report needs to be sent based on settings.
  Future<void> checkAndSendReport() async {
    // Defensive: ensure locale is ready (isolates/early startup edge case)
    await initializeDateFormatting('fr_FR', null);

    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null || !settings.reportEmailEnabled || settings.backupEmailRecipient.isEmpty) {
      return;
    }

    final now = DateTime.now();
    
    // 1. Vérifier l'heure
    if (now.hour < settings.reportEmailHour) {
      return;
    }

    // 2. Vérifier si déjà envoyé aujourd'hui (pour éviter les envois multiples si l'app redémarre)
    final todayStr = DateFormatter.formatDateDb(now);
    final lastSentStr = settings.lastReportEmailDate != null 
        ? DateFormatter.formatDateDb(settings.lastReportEmailDate!) 
        : '';
        
    if (todayStr == lastSentStr) {
      return;
    }

    // 3. Vérifier la fréquence
    bool shouldSend = false;
    DateTimeRange range = DateTimeRange(
      start: now.copyWith(hour: 0, minute: 0, second: 0),
      end: now.copyWith(hour: 23, minute: 59, second: 59),
    );

    switch (settings.reportEmailFrequency) {
      case EmailBackupFrequency.daily:
        shouldSend = true;
        // Rapport pour la journée d'hier (ou aujourd'hui jusqu'à présent)
        // Généralement, un rapport quotidien à 20h porte sur "Aujourd'hui"
        range = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case EmailBackupFrequency.weekly:
        // Vérifier le jour de la semaine (1=Lundi, ..., 7=Dimanche)
        if (now.weekday == settings.reportEmailDayOfWeek) {
          shouldSend = true;
          // Les 7 derniers jours
          range = DateTimeRange(
            start: now.subtract(const Duration(days: 6)).copyWith(hour: 0, minute: 0, second: 0),
            end: now.copyWith(hour: 23, minute: 59, second: 59),
          );
        }
        break;
      case EmailBackupFrequency.monthly:
        // Premier jour du mois ou dernier jour ?
        // On va dire le dernier jour du mois ou le 1er (si 1er, on regarde le mois dernier)
        if (now.day == 1) {
          shouldSend = true;
          final lastMonth = now.subtract(const Duration(days: 1));
          range = DateTimeRange(
            start: DateTime(lastMonth.year, lastMonth.month, 1),
            end: DateTime(lastMonth.year, lastMonth.month, lastMonth.day, 23, 59, 59),
          );
        }
        break;
    }

    if (!shouldSend) return;

    try {
      debugPrint("ScheduledReportService: Generating scheduled report ($todayStr)...");
      
      // Fetch required data
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final userSales = await ref.read(userSalesSummaryProvider(range).future);
      final user = await ref.read(authServiceProvider.future);
      
      // Generate files
      final pdfPath = await PdfReportService.generateReportFile(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        username: user?.username ?? "Système",
      );

      final db = await ref.read(databaseServiceProvider).database;
      final excelPath = await ExcelExportService.exportToExcel(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        db: db,
        currency: settings.currency,
        openFile: false, // Ne pas ouvrir si c'est un envoi automatique
      );

      // Send Email
      final emailService = ref.read(emailServiceProvider);
      final result = await emailService.sendSalesReport(
        recipient: settings.backupEmailRecipient,
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        attachments: [File(pdfPath), File(excelPath)],
      );

      if (result.success) {
        debugPrint("ScheduledReportService: Report successfully sent.");
        // Mettre à jour la date de dernier envoi
        final newSettings = settings.copyWith(lastReportEmailDate: now);
        await ref.read(shopSettingsProvider.notifier).save(newSettings);
      }
    } catch (e) {
      debugPrint("ScheduledReportService Error: $e");
    }
  }

  /// Manually sends a report for testing.
  Future<EmailSendResult> sendManualReport(String recipient, DateTimeRange range) async {
    try {
      // Defensive: ensure locale is ready
      await initializeDateFormatting('fr_FR', null);

      // Fetch required data
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final userSales = await ref.read(userSalesSummaryProvider(range).future);
      final user = await ref.read(authServiceProvider.future);
      
      // Generate files
      final pdfPath = await PdfReportService.generateReportFile(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        username: user?.username ?? "Système",
      );

      final db = await ref.read(databaseServiceProvider).database;
      final settings = ref.read(shopSettingsProvider).value;
      final excelPath = await ExcelExportService.exportToExcel(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        db: db,
        currency: settings?.currency ?? 'FCFA',
        openFile: false, // Ne pas ouvrir pour un simple test d'email
      );

      // Send Email
      final emailService = ref.read(emailServiceProvider);
      return await emailService.sendSalesReport(
        recipient: recipient,
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        attachments: [File(pdfPath), File(excelPath)],
      );
    } catch (e) {
      debugPrint("ScheduledReportService Manual Error: $e");
      return EmailSendResult(success: false, errorMessage: e.toString());
    }
  }
}
