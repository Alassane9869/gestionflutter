import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';

class SessionHistoryDialog extends ConsumerWidget {
  const SessionHistoryDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(shopSettingsProvider).value?.currency ?? 'FCFA';
    final sessionsAsync = ref.watch(closedSessionsProvider);

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Historique des Sessions",
      icon: FluentIcons.history_24_regular,
      width: 800,
      child: SizedBox(
        height: 500,
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Erreur: $e")),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.document_search_24_regular, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Aucune session fermée", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 100, child: Text("CAISSIER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey))),
                      SizedBox(width: 130, child: Text("OUVERTURE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey))),
                      SizedBox(width: 130, child: Text("FERMETURE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey))),
                      SizedBox(width: 90, child: Text("FOND", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey), textAlign: TextAlign.right)),
                      SizedBox(width: 90, child: Text("THÉORIQUE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey), textAlign: TextAlign.right)),
                      SizedBox(width: 90, child: Text("COMPTÉ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey), textAlign: TextAlign.right)),
                      Expanded(child: Text("ÉCART", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Table Body
                Expanded(
                  child: ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final username = s['username'] as String? ?? 'Inconnu';
                      final openDate = DateTime.parse(s['open_date'] as String);
                      final closeDate = s['close_date'] != null ? DateTime.parse(s['close_date'] as String) : null;
                      final opening = (s['opening_balance'] as num).toDouble();
                      final closingTheo = (s['closing_balance_theoretical'] as num?)?.toDouble();
                      final closingActual = (s['closing_balance_actual'] as num?)?.toDouble();
                      final difference = (s['difference'] as num?)?.toDouble() ?? 0.0;
                      
                      final isNegative = difference < 0;
                      final isPositive = difference > 0;
                      final diffColor = isNegative ? AppTheme.errorClr : (isPositive ? AppTheme.successClr : Colors.grey);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: isNegative ? AppTheme.errorClr.withValues(alpha: 0.03) : null,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', 
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 130,
                                child: Text(DateFormatter.formatCompact(openDate), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ),
                              SizedBox(
                                width: 130,
                                child: Text(closeDate != null ? DateFormatter.formatCompact(closeDate) : '—', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ),
                            SizedBox(
                              width: 90,
                                child: Text(DateFormatter.formatCurrency(opening, currency), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(closingTheo != null ? DateFormatter.formatCurrency(closingTheo, currency) : '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue), textAlign: TextAlign.right),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(closingActual != null ? DateFormatter.formatCurrency(closingActual, currency) : '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                              ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: diffColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    difference == 0 ? "OK" : "${difference > 0 ? '+' : ''}${DateFormatter.formatNumber(difference)}",
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: diffColor),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Fermer"),
        ),
      ],
    );
  }
}
