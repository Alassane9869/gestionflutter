import 'package:danaya_plus/core/services/marketing_email_service.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final marketingAutomationServiceProvider = Provider<MarketingAutomationService>((ref) {
  return MarketingAutomationService(ref);
});

class MarketingAuditResult {
  final int totalClients;
  final int clientsWithEmail;
  final int inactiveClientsFound;
  final int emailsSent;
  final int emailsFailed;
  final List<String> errorMessages;

  MarketingAuditResult({
    required this.totalClients,
    required this.clientsWithEmail,
    required this.inactiveClientsFound,
    required this.emailsSent,
    required this.emailsFailed,
    this.errorMessages = const [],
  });
}

class MarketingAutomationService {
  final Ref _ref;

  MarketingAutomationService(this._ref);

  /// Runs the daily marketing audit to check for inactive clients.
  Future<MarketingAuditResult> runDailyInactivityAudit({bool force = false}) async {
    final settings = _ref.read(shopSettingsProvider).value;
    
    // If not forced (scheduled run), check if enabled
    if (!force) {
      if (settings == null || !settings.inactivityReminderEnabled || !settings.marketingEmailsEnabled) {
        return MarketingAuditResult(
          totalClients: 0,
          clientsWithEmail: 0,
          inactiveClientsFound: 0,
          emailsSent: 0,
          emailsFailed: 0,
        );
      }
    }

    final now = DateTime.now();
    int totalClients = 0;
    int clientsWithEmail = 0;
    int inactiveFound = 0;
    int sentCount = 0;
    int failedCount = 0;
    List<String> errors = [];

    try {
      final clients = await _ref.read(clientListProvider.future);
      totalClients = clients.length;
      final marketingEmailService = _ref.read(marketingEmailServiceProvider);
      final thresholdDays = settings?.inactivityDaysThreshold ?? 30;

      for (var client in clients) {
        if (client.email == null || client.email!.isEmpty) continue;
        clientsWithEmail++;

        if (client.lastPurchaseDate == null) continue;

        final daysSinceLastPurchase = now.difference(client.lastPurchaseDate!).inDays;

        // Logic improvement: At least thresholdDays AND not reminded recently (e.g. within 7 days)
        bool shouldRemind = daysSinceLastPurchase >= thresholdDays;
        
        if (client.lastMarketingReminderDate != null) {
          final daysSinceLastReminder = now.difference(client.lastMarketingReminderDate!).inDays;
          if (daysSinceLastReminder < 7) { // Cooldown of 7 days
            shouldRemind = false;
          }
        }

        if (shouldRemind) {
          inactiveFound++;
          try {
            final result = await marketingEmailService.sendInactivityReminder(client);
            if (result.success) {
              sentCount++;
              // Mettre à jour la date de dernière relance dans la DB
              final db = await _ref.read(databaseServiceProvider).database;
              await db.update(
                'clients',
                {'last_marketing_reminder_date': now.toIso8601String()},
                where: 'id = ?',
                whereArgs: [client.id],
              );
            } else {
              failedCount++;
              if (result.errorMessage != null) errors.add(result.errorMessage!);
            }
          } catch (e) {
            failedCount++;
            errors.add(e.toString());
          }
        }
      }

      // ── Simulation Admin si test forcé et aucun client éligible ──
      if (force && inactiveFound == 0) {
        final adminEmail = settings?.backupEmailRecipient;
        if (adminEmail != null && adminEmail.isNotEmpty) {
          inactiveFound++; // Pour stat
          try {
            final dummyClient = Client(id: 'test', name: 'Administrateur (Test)', phone: '', email: adminEmail);
            final result = await marketingEmailService.sendInactivityReminder(dummyClient);
            if (result.success) {
              sentCount++;
            } else {
              failedCount++;
              if (result.errorMessage != null) errors.add("Test Admin : ${result.errorMessage}");
            }
          } catch (e) {
            failedCount++;
            errors.add("Test Admin : $e");
          }
        } else {
          errors.add("Aucun client n'est inactif (tous sont récents). Configurez l'email de secours pour recevoir un test au lieu des clients.");
        }
      }
    } catch (e) {
      debugPrint("MarketingAutomationService Error: $e");
      errors.add(e.toString());
    }

    return MarketingAuditResult(
      totalClients: totalClients,
      clientsWithEmail: clientsWithEmail,
      inactiveClientsFound: inactiveFound,
      emailsSent: sentCount,
      emailsFailed: failedCount,
      errorMessages: errors,
    );
  }
}
