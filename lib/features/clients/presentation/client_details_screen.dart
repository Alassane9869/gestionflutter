import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/clients/presentation/client_form_dialog.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/clients/services/debt_statement_service.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/providers/client_analytics_providers.dart';
import 'package:danaya_plus/core/services/whatsapp_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/widgets/map_viewer_dialog.dart';

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

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Envoyer le rappel WhatsApp", style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text("Veuillez choisir la méthode d'envoi pour ce rappel de dette :"),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton.icon(
            icon: const Icon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.green),
            label: const Text("Application WhatsApp (Manuel)"),
            onPressed: () => Navigator.pop(ctx, 'MANUAL'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(FluentIcons.cloud_24_regular, size: 16),
            label: const Text("Envoi Silencieux (API Meta)"),
            onPressed: () => Navigator.pop(ctx, 'API'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'MANUAL') {
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
    } else if (choice == 'API') {
      final token = settings?.whatsappToken;
      final phoneId = settings?.whatsappPhoneNumberId;

      if (token == null || token.isEmpty || phoneId == null || phoneId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Erreur: Les identifiants API WhatsApp ne sont pas configurés dans vos paramètres."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      // LOADING DIALOG
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final whatsappService = ref.read(whatsappServiceProvider);
      
      // Note : On utilise l'envoi de texte simple. Si la session 24h avec le client est expirée, Meta refusera.
      // Il faudra utiliser un sendTemplateViaApi avec un template approuvé pour forcer l'ouverture.
      final success = await whatsappService.sendMessageViaApi(
        to: phone,
        message: message,
        phoneNumberId: phoneId,
        accessToken: token,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rappel API envoyé avec succès !"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Échec de l'envoi API (Probablement dû à la règle des 24h de Meta). Utilisez l'envoi manuel ou configurez un Template."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _sendDebtReminder(BuildContext context, WidgetRef ref, Client client) async {
    final emailCtrl = TextEditingController(text: client.email);
    
    final targetEmail = await showDialog<String>(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Relance par Email",
        icon: FluentIcons.mail_alert_24_regular,
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Envoyer un rappel de dette à ce client ? Veuillez confirmer son adresse e-mail :",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: emailCtrl,
              label: "ADRESSE E-MAIL DU DESTINATAIRE",
              hint: "Ex: client@domain.com",
              icon: FluentIcons.mail_24_regular,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
            child: const Text("Confirmer & Relancer"),
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
    final salesAsync = ref.watch(clientSalesProvider(client.id));
    final settings = ref.watch(shopSettingsProvider).value;
    final loyaltyEnabled = settings?.loyaltyEnabled ?? false;
    final threshold = settings?.vipThreshold ?? 1000000.0;
    final bool isVip = client.totalSpent > threshold;
    final hasDebt = client.credit > 0;

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
          "Fiche Profil Client",
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
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. HEADER COMPACT (Avatar + Name + Status Badges) ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        client.name.substring(0, client.name.length > 1 ? 2 : 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildStatusBadge(
                                label: hasDebt ? "SOLDE DÛ" : "À JOUR",
                                icon: hasDebt
                                    ? FluentIcons.warning_16_regular
                                    : FluentIcons.checkmark_circle_16_regular,
                                color: hasDebt ? AppTheme.errorClr : const Color(0xFF10B981),
                                isDark: isDark,
                              ),
                              _buildStatusBadge(
                                label: isVip ? "CLIENT VIP" : "CLIENT RÉGULIER",
                                icon: isVip ? FluentIcons.star_16_filled : FluentIcons.person_16_regular,
                                color: isVip ? Colors.amber.shade700 : Colors.blue,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- 2. ACTION BUTTONS ROW ---
                Row(
                  children: [
                    if (client.phone != null && client.phone!.isNotEmpty) ...[
                      _buildActionBtn(
                        FluentIcons.call_16_regular,
                        "Appeler",
                        () async {
                          final uri = Uri.parse("tel:${client.phone}");
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        isDark,
                        theme,
                      ),
                      const SizedBox(width: 8),
                      _buildActionBtn(
                        FluentIcons.chat_16_regular,
                        "WhatsApp",
                        () => _sendWhatsAppReminder(context, ref, client),
                        isDark,
                        theme,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (client.email != null && client.email!.isNotEmpty) ...[
                      _buildActionBtn(
                        FluentIcons.mail_16_regular,
                        "Email",
                        () async {
                          final uri = Uri.parse("mailto:${client.email}");
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                        isDark,
                        theme,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // --- 3. UNIFORM SCORECARD (Style Dashboard) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildUniformKpiCard(
                        "Achats Totaux",
                        ref.fmt(client.totalSpent),
                        FluentIcons.cart_24_regular,
                        accent,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUniformKpiCard(
                        "Solde En Cours",
                        ref.fmt(client.credit),
                        FluentIcons.money_off_24_regular,
                        hasDebt ? AppTheme.errorClr : const Color(0xFF10B981),
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (loyaltyEnabled) ...[
                      Expanded(
                        child: _buildUniformKpiCard(
                          "Points Fidélité",
                          "${client.loyaltyPoints} pts",
                          FluentIcons.star_24_regular,
                          Colors.amber.shade700,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _buildUniformKpiCard(
                        "Visites / Achats",
                        "${client.totalPurchases} Fois",
                        FluentIcons.arrow_trending_lines_24_regular,
                        Colors.blue,
                        isDark,
                      ),
                    ),
                    if (user.canAccessReports) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ref.watch(clientProfitProvider(client.id)).when(
                              data: (profit) => _buildUniformKpiCard(
                                "Profit Net",
                                ref.fmt(profit),
                                FluentIcons.presence_available_24_regular,
                                const Color(0xFF10B981),
                                isDark,
                              ),
                              loading: () => _buildUniformKpiCard(
                                "Profit Net",
                                "...",
                                FluentIcons.presence_available_24_regular,
                                Colors.grey,
                                isDark,
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // --- 4. DEDICATED DEBT PROGRESS & ACTIONS BANNER ---
                if (hasDebt) ...[
                  _buildDebtGaugeBanner(context, ref, isDark, theme, accent),
                  const SizedBox(height: 24),
                ],

                // --- 5. INFORMATIONS COMPLÈTES CARD (Style Grille) ---
                const Text(
                  "INFORMATIONS PERSONNELLES & DE LIVRAISON",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildGridInfoRow("Téléphone", client.phone ?? "Non renseigné", FluentIcons.phone_20_regular, isDark, theme),
                      _buildDivider(isDark),
                      _buildGridInfoRow("Adresse Email", client.email ?? "Non renseigné", FluentIcons.mail_20_regular, isDark, theme),
                      _buildDivider(isDark),
                      _buildGridInfoRow("Plafond de Crédit", "${ref.fmt(client.maxCredit)} Max", FluentIcons.money_hand_20_regular, isDark, theme),
                      _buildDivider(isDark),
                      _buildGridInfoRow(
                        "Adresse de Livraison",
                        (client.address != null && client.address!.isNotEmpty)
                            ? client.address!
                            : "Aucune adresse enregistrée",
                        FluentIcons.location_20_regular,
                        isDark,
                        theme,
                        trailing: (client.address != null && client.address!.isNotEmpty)
                            ? OutlinedButton.icon(
                                onPressed: () {
                                  final shopAddress = settings?.address ?? 'Dakar, Senegal';
                                  MapViewerDialog.show(
                                    context,
                                    originAddress: shopAddress,
                                    destinationAddress: client.address!,
                                    originLabel: settings?.name ?? 'Ma Boutique',
                                    destinationLabel: client.name,
                                  );
                                },
                                icon: const Icon(FluentIcons.map_16_regular, size: 14),
                                label: const Text("Carte", style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () async {
                                  final updated = await showDialog<Client>(
                                    context: context,
                                    builder: (ctx) => ClientFormDialog(client: client),
                                  );
                                  if (updated != null && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(FluentIcons.edit_16_regular, size: 14),
                                label: const Text("Ajouter", style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- 6. HISTORIQUE DES ACHATS ---
                Row(
                  children: [
                    _buildSectionTitle("HISTORIQUE DES ACHATS", isDark),
                    const Spacer(),
                    Icon(FluentIcons.filter_20_regular, size: 16, color: Colors.grey.shade400),
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
        ),
      ),
    );
  }

  Widget _buildUniformKpiCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtGaugeBanner(BuildContext context, WidgetRef ref, bool isDark, ThemeData theme, Color accent) {
    final double debtRatio = client.maxCredit > 0
        ? (client.credit / client.maxCredit).clamp(0.0, 1.0)
        : 0.0;
    final int debtPercent = (debtRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.errorClr.withValues(alpha: 0.04),
            AppTheme.errorClr.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.errorClr.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorClr.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(FluentIcons.warning_20_regular, color: AppTheme.errorClr, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ALERTE DE CRÉDIT",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: AppTheme.errorClr),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Dépassement de plafond : $debtPercent% utilisé",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                "${ref.fmt(client.credit)} / ${ref.fmt(client.maxCredit)}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.errorClr),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: debtRatio,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.errorClr),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showSettleDebtDialog(context, ref, accent),
                  icon: const Icon(FluentIcons.money_20_regular, size: 14),
                  label: const Text("RÉGLER LA DETTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorClr,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendWhatsAppReminder(context, ref, client),
                  icon: const Icon(FontAwesomeIcons.whatsapp, size: 14, color: Colors.green),
                  label: const Text("RAPPEL WHATSAPP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendDebtReminder(context, ref, client),
                  icon: const Icon(FluentIcons.mail_alert_20_regular, size: 14, color: Colors.orange),
                  label: const Text("RAPPEL EMAIL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    bool isDark,
    ThemeData theme,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
          ),
          child: Icon(icon, size: 18, color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildGridInfoRow(
    String label,
    String value,
    IconData icon,
    bool isDark,
    ThemeData theme, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 24,
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
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
        color: isDark ? const Color(0xFF0D0E12) : Colors.white,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0E12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue 
              ? Colors.red.withValues(alpha: 0.3) 
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isOverdue ? Colors.red : (isDark ? Colors.white : Colors.black)).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOverdue ? FluentIcons.warning_20_regular : FluentIcons.receipt_20_regular, 
              size: 18, 
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
