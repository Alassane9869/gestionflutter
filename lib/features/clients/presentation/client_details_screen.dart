import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/clients/presentation/widgets/client_form_dialog.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/clients/services/debt_statement_service.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/providers/client_analytics_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  void _showSettleDebtDialog(BuildContext context, WidgetRef ref, Color accent) {
    final treasuryAsync = ref.watch(myTreasuryAccountsProvider);
    double amount = client.credit;
    String? selectedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDS) {
          final accounts = treasuryAsync.value ?? [];
          if (selectedAccountId == null && accounts.isNotEmpty) {
            selectedAccountId = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first).id;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Régler la dette", style: TextStyle(fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Le client doit encore ${ref.fmt(client.credit)}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Montant Versé",
                    prefixText: "${ref.fmt(0).replaceAll(RegExp(r'\d'), '').trim()} ",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => amount = double.tryParse(v) ?? 0,
                  controller: TextEditingController(text: amount.toStringAsFixed(0)),
                ),
                const SizedBox(height: 16),
                const Text("Compte de destination", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setDS(() => selectedAccountId = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              FilledButton(
                onPressed: selectedAccountId == null ? null : () async {
                  if (amount <= 0) return;
                  await ref.read(clientListProvider.notifier).settleDebt(
                    clientId: client.id,
                    amount: amount,
                    accountId: selectedAccountId!,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Paiement de ${ref.fmt(amount)} enregistré"), backgroundColor: Colors.green),
                  );
                },
                child: const Text("Confirmer"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(BuildContext context, WidgetRef ref, Client client) async {
    final phone = client.phone?.replaceAll(RegExp(r'\D'), '');
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Le client n'a pas de numéro de téléphone.")),
        );
      }
      return;
    }

    final settings = ref.read(shopSettingsProvider).value;
    final String shopName = settings?.name ?? "Danaya+";

    final String message = "Bonjour ${client.name}, c'est l'établissement $shopName. "
        "Nous vous contactons pour vous rappeler votre solde restant de ${ref.fmt(client.credit)}. "
        "Merci de régulariser votre situation dès que possible. Bonne journée !";

    final Uri whatsappUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
        );
      }
    }
  }

  Future<void> _sendDebtReminder(BuildContext context, WidgetRef ref, Client client) async {
    final emailCtrl = TextEditingController(text: client.email);
    
    final targetEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Relance par Email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Envoyer un rappel de dette à ce client ?"),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: "Email du destinataire",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
            child: const Text("ENVOYER LE RAPPEL"),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (targetEmail == null || targetEmail.isEmpty) return;

    // --- LOADING INDICATOR DIALOG ---
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final debtService = ref.read(debtStatementServiceProvider);
      if (!context.mounted) return;
      final pdfFile = await debtService.generateStatement(client);

      if (!context.mounted) return;
      final emailService = ref.read(emailServiceProvider);
      final result = await emailService.sendDebtReminder(
        recipient: targetEmail,
        clientName: client.name,
        totalDebt: client.credit,
        statementFile: pdfFile,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? "Relance envoyée avec Relevé PDF à $targetEmail" : "Échec : ${result.errorMessage}"),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (await pdfFile.exists()) await pdfFile.delete();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageCustomers) {
      return const AccessDeniedScreen(
        message: "Détails Client Restreints",
        subtitle: "Vous n'avez pas l'autorisation de consulter cette fiche client.",
      );
    }

    // Log access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
            userId: user.id,
            actionType: 'VIEW_CLIENT_DETAILS',
            description: 'Consultation du profil de ${client.name} par ${user.username}',
          );
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final salesAsync = ref.watch(salesHistoryProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(FluentIcons.arrow_left_24_regular, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Détail Client",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.edit_24_regular),
            onPressed: () async {
              final updated = await showDialog<Client>(
                context: context,
                builder: (ctx) => ClientFormDialog(client: client),
              );
              if (updated != null && context.mounted) {
                // Return to previous screen or refresh? 
                // Since it's a detail screen, it's better to pop and reopen or use a provider for the specific client.
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PROFILE HEADER ---
            _buildProfileHeader(theme, isDark, accent, ref),
            const SizedBox(height: 24),

            // --- SCORECARD ---
            _buildScorecard(context, ref, accent, isDark, user),
            const SizedBox(height: 32),

            // --- TABS / CONTENT ---
            Row(
              children: [
                _buildSectionTitle("HISTORIQUE DES ACHATS", isDark),
                const Spacer(),
                const Icon(FluentIcons.filter_20_regular, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            
            salesAsync.when(
              data: (sales) {
                final clientSales = sales.where((s) => s.sale.clientId == client.id).toList();
                if (clientSales.isEmpty) return _buildEmptyState(isDark);
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: clientSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildSaleCard(ctx, clientSales[i], ref, isDark),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text("Erreur : $err")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, bool isDark, Color accent, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            client.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(FluentIcons.phone_20_regular, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(client.phone ?? 'Aucun numéro', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600)),
                  if (client.phone != null && client.phone!.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    _buildContactAction(FluentIcons.call_20_regular, Colors.green),
                    const SizedBox(width: 8),
                    _buildContactAction(FluentIcons.chat_20_regular, Colors.blue),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (client.email != null && client.email!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(FluentIcons.mail_16_regular, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(client.email!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
              if (client.address != null && client.address!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(FluentIcons.location_16_regular, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(child: Text(client.address!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                    ],
                  ),
                ),
              _buildRankingBadge(accent, ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactAction(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }

  Widget _buildRankingBadge(Color accent, WidgetRef ref) {
    final settings = ref.watch(shopSettingsProvider).value;
    final threshold = settings?.vipThreshold ?? 1000000.0;
    final bool isVip = client.totalSpent > threshold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isVip ? Colors.amber : accent).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isVip ? Colors.amber : accent).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVip ? FluentIcons.star_16_filled : FluentIcons.person_16_regular, color: isVip ? Colors.amber : accent, size: 12),
          const SizedBox(width: 6),
          Text(
            isVip ? "CLIENT VIP" : "CLIENT RÉGULIER",
            style: TextStyle(color: isVip ? Colors.amber : accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildScorecard(BuildContext context, WidgetRef ref, Color accent, bool isDark, User user) {
    final settings = ref.watch(shopSettingsProvider).value;
    final loyaltyEnabled = settings?.loyaltyEnabled ?? false;
    
    return Row(
      children: [
        _buildStatCard("Total Achats", ref.fmt(client.totalSpent), FluentIcons.cart_24_regular, accent, isDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildStatCard("Dette Actuelle", ref.fmt(client.credit), FluentIcons.money_off_24_regular, client.credit > 0 ? Colors.red : Colors.green, isDark),
              if (client.credit > 0) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showSettleDebtDialog(context, ref, accent),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("RÉGLER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _sendWhatsAppReminder(context, ref, client),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _sendDebtReminder(context, ref, client),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("RELANCER", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (loyaltyEnabled)
          _buildStatCard("Points Fidélité", "${client.loyaltyPoints} pts", FluentIcons.star_24_regular, Colors.amber, isDark),
        if (loyaltyEnabled)
          const SizedBox(width: 12),
        _buildStatCard("Fréquence", "${client.totalPurchases} Visites", FluentIcons.arrow_trending_lines_24_regular, Colors.orange, isDark),
        if (user.canAccessReports) ...[
          const SizedBox(width: 12),
          ref.watch(clientProfitProvider(client.id)).when(
            data: (profit) => _buildStatCard("Profit Net", ref.fmt(profit), FluentIcons.presence_available_24_regular, Colors.green, isDark),
            loading: () => _buildStatCard("Profit Net", "...", FluentIcons.presence_available_24_regular, Colors.grey, isDark),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark, {Widget? extra}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              if (extra != null) extra,
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(FluentIcons.receipt_24_regular, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("Aucun achat enregistré", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSaleCard(BuildContext context, SaleWithDetails detail, WidgetRef ref, bool isDark) {
    final dateStr = DateFormatter.formatDateTime(detail.sale.date);
    final rest = detail.sale.totalAmount - detail.sale.amountPaid;
    final isCredit = detail.sale.isCredit && rest > 0;
    final isOverdue = isCredit && detail.sale.dueDate != null && detail.sale.dueDate!.isBefore(DateTime.now());
    final dueDateStr = detail.sale.dueDate != null ? DateFormatter.formatDate(detail.sale.dueDate!) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue 
              ? Colors.red.withValues(alpha: 0.3) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isOverdue ? Colors.red : (isDark ? Colors.white : Colors.black)).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOverdue ? FluentIcons.warning_20_regular : FluentIcons.receipt_20_regular, 
              size: 20, 
              color: isOverdue ? Colors.red : null
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Vente #${detail.sale.id.substring(detail.sale.id.length - 6).toUpperCase()}", 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                if (isCredit && dueDateStr != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(FluentIcons.calendar_clock_20_regular, size: 12, color: isOverdue ? Colors.red : Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        "Échéance: $dueDateStr", 
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.orange, 
                          fontSize: 11, 
                          fontWeight: FontWeight.w700
                        )
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ref.fmt(detail.sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isCredit ? (isOverdue ? Colors.red : Colors.orange) : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCredit ? (isOverdue ? "EN RETARD" : "À CRÉDIT") : "PAYÉ", 
                  style: TextStyle(
                    color: isCredit ? (isOverdue ? Colors.red : Colors.orange) : Colors.green, 
                    fontSize: 9, 
                    fontWeight: FontWeight.w900
                  )
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
