import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/clients/domain/models/client_payment.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/providers/client_payment_provider.dart';
import 'package:danaya_plus/features/clients/providers/debt_reminder_provider.dart';
import 'package:danaya_plus/features/pos/domain/models/sale.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/services/whatsapp_service.dart';

class ClientDebtScreen extends ConsumerStatefulWidget {
  const ClientDebtScreen({super.key});

  @override
  ConsumerState<ClientDebtScreen> createState() => _ClientDebtScreenState();
}

class _ClientDebtScreenState extends ConsumerState<ClientDebtScreen> {
  Client? _selectedClient;
  String _clientSearch = "";
  final _sidebarSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _sidebarSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageCustomers) {
      return const AccessDeniedScreen(
        message: "Portefeuille Dettes Restreint",
        subtitle: "Vous n'avez pas l'autorisation de consulter le suivi des dettes.",
      );
    }

    // Log access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
            userId: user.id,
            actionType: 'VIEW_CLIENT_DEBTS',
            description: 'Consultation du portefeuille dettes par ${user.username}',
          );
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050507) : const Color(0xFFF7F9FC),
      body: clientsAsync.when(
        data: (clients) {
          final totalDebt = clients.where((c) => c.credit > 0).fold(0.0, (sum, c) => sum + c.credit);
          final debtClientsCount = clients.where((c) => c.credit > 0).length;

          final filteredClients = _clientSearch.isEmpty 
              ? clients.where((c) => c.credit > 0).toList()
              : clients.where((c) => c.name.toLowerCase().contains(_clientSearch.toLowerCase())).toList();

          return Row(
            children: [
              // Client List Sidebar
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(context, ref, totalDebt, debtClientsCount),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _sidebarSearchCtrl,
                        label: "Rechercher un client...",
                        onChanged: (v) => setState(() => _clientSearch = v),
                        icon: FluentIcons.search_24_regular,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];
                          final isSelected = _selectedClient?.id == client.id;
                          return _ClientDebtTile(
                            client: client,
                            isSelected: isSelected,
                            onTap: () => setState(() => _selectedClient = client),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Detail Area
              Expanded(
                child: _selectedClient == null
                    ? _buildEmptyState(context)
                    : _ClientDebtDetail(
                        client: _selectedClient!,
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Erreur: $e")),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, double totalDebt, int count) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.arrow_left_24_regular),
                onPressed: () => ref.read(navigationProvider.notifier).setPage(0, ref),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Portefeuille Dettes",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF2D1418), // Deep burgundy red
                        const Color(0xFF1E0A0D),
                      ]
                    : [
                        const Color(0xFFFEE2E2), // Soft red
                        const Color(0xFFFEF2F2),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.1),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TOTAL DES CRÉDITS",
                  style: TextStyle(
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ref.fmt(totalDebt),
                  style: TextStyle(
                    color: isDark ? Colors.red.shade100 : Colors.red.shade900,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "$count clients endettés",
                  style: TextStyle(
                    color: isDark ? Colors.red.shade300.withValues(alpha: 0.7) : Colors.red.shade700.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.person_money_24_regular,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Sélectionnez un client",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "pour voir le détail de sa dette et l'historique des remboursements.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientDebtTile extends ConsumerWidget {
  final Client client;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClientDebtTile({
    required this.client,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                : (isDark ? const Color(0xFF0A0B0E) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : (isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.2)
                    : (isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F4F6)),
                child: Text(
                  client.name[0].toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.phone ?? "Pas de téléphone",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ref.fmt(client.credit),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientDebtDetail extends ConsumerStatefulWidget {
  final Client client;

  const _ClientDebtDetail({required this.client});

  @override
  ConsumerState<_ClientDebtDetail> createState() => _ClientDebtDetailState();
}

class _ClientDebtDetailState extends ConsumerState<_ClientDebtDetail> {
  bool _showAllCreditSales = false;

  Future<void> _sendWhatsAppReminder(BuildContext context, Client client) async {
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
              content: Text("Erreur : Les identifiants API WhatsApp ne sont pas configurés dans vos paramètres."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final whatsappService = ref.read(whatsappServiceProvider);
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
          const SnackBar(content: Text("Erreur d'envoi API Meta WhatsApp."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final paymentsAsync = ref.watch(clientPaymentsProvider(client.id));
    final salesAsync = ref.watch(_showAllCreditSales
        ? clientAllCreditSalesProvider(client.id)
        : clientActiveDebtsProvider(client.id));
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final payments = paymentsAsync.value ?? [];
    final sales = salesAsync.value ?? [];
    
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    final unpaidCount = sales.where((s) => (s.totalAmount - s.amountPaid) > 0).length;

    int maxDelayDays = 0;
    for (final s in sales) {
      if (s.dueDate != null && (s.totalAmount - s.amountPaid) > 0) {
        final diff = DateTime.now().difference(s.dueDate!).inDays;
        if (diff > maxDelayDays) {
          maxDelayDays = diff;
        }
      }
    }

    return Column(
      children: [
        // Top Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoChip(context, FluentIcons.phone_20_regular, client.phone ?? "N/A"),
                        const SizedBox(width: 12),
                        _infoChip(context, FluentIcons.cart_20_regular, "${client.totalPurchases} achats"),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                ),
                icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 18),
                label: const Text("RAPPEL WHATSAPP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                onPressed: () => _sendWhatsAppReminder(context, client),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(FluentIcons.money_hand_24_regular, size: 20),
                label: const Text("ENREGISTRER UN PAIEMENT", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showPaymentDialog(context, ref),
              ),
            ],
          ),
        ),

        // Financial Telemetry HUD row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Row(
            children: [
              _buildMetricCard(
                title: "SOLDE DE LA DETTE",
                value: ref.fmt(client.credit),
                icon: FluentIcons.money_off_24_regular,
                color: theme.colorScheme.error,
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                title: "TOTAL RECOUVREMENTS",
                value: ref.fmt(totalPaid),
                icon: FluentIcons.money_hand_24_regular,
                color: Colors.green,
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                title: "FACTURES IMPAYÉES",
                value: "$unpaidCount en attente",
                icon: FluentIcons.clipboard_text_edit_24_regular,
                color: Colors.orange,
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                title: "RETARD MAXIMAL",
                value: maxDelayDays > 0 ? "$maxDelayDays jours" : "Aucun",
                icon: FluentIcons.timer_24_regular,
                color: maxDelayDays > 0 ? Colors.red : Colors.blue,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Active Debts & History Area
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            color: isDark ? const Color(0xFF050507) : const Color(0xFFF7F9FC),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Active Debts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(FluentIcons.clipboard_text_edit_24_regular, 
                              size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _showAllCreditSales ? "HISTORIQUE CRÉDITS" : "FACTURES IMPAYÉES DETTES",
                              style: theme.textTheme.labelLarge?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(
                              _showAllCreditSales ? FluentIcons.checkbox_checked_24_regular : FluentIcons.checkbox_unchecked_24_regular,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            label: Text(
                              "Afficher l'historique réglé",
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _showAllCreditSales = !_showAllCreditSales;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: salesAsync.when(
                          data: (sales) {
                            if (sales.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.checkmark_circle_24_regular,
                                      size: 56,
                                      color: Colors.green.withValues(alpha: 0.2),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _showAllCreditSales 
                                          ? "Aucune vente à crédit enregistrée."
                                          : "Aucune dette en cours pour ce client.",
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              itemCount: sales.length,
                              itemBuilder: (context, index) {
                                return _DebtItem(sale: sales[index]);
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text("Erreur : $e")),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                // Right Column: Payment History
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(FluentIcons.history_24_regular, 
                              size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            "HISTORIQUE DES REMBOURSEMENTS",
                            style: theme.textTheme.labelLarge?.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: paymentsAsync.when(
                          data: (payments) {
                            if (payments.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.history_24_regular,
                                      size: 56,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Aucun remboursement enregistré.",
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.builder(
                              itemCount: payments.length,
                              itemBuilder: (context, index) {
                                return _PaymentItem(payment: payments[index]);
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text("Erreur : $e")),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1115) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedMethod = "CASH";
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return EnterpriseWidgets.buildPremiumDialog(
            context,
            title: "Remboursement de Dette",
            icon: FluentIcons.money_hand_24_regular,
            width: 450,
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                  if (amount <= 0 || amount > widget.client.credit) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Montant invalide")));
                    return;
                  }

                  final allAccounts = await ref.read(treasuryProvider.future);
                  final user = await ref.read(authServiceProvider.future);
                  final accounts = allAccounts.where((a) => user?.canAccessAccount(a.id) ?? false).toList();
                  
                  if (accounts.isEmpty) {
                     if (!context.mounted) return;
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune caisse assignée pour ce paiement.")));
                     return;
                  }
                  final defaultAccount = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);

                  final payment = ClientPayment(
                    id: const Uuid().v4(),
                    clientId: widget.client.id,
                    accountId: defaultAccount.id,
                    amount: amount,
                    date: DateTime.now(),
                    paymentMethod: selectedMethod,
                    description: descCtrl.text,
                    userId: user?.id ?? "unknown",
                  );

                  await ref.read(clientPaymentActionsProvider).addPayment(payment);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text("VALIDER LE PAIEMENT"),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(FluentIcons.info_24_regular, color: colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SOLDE ACTUEL",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.error,
                              ),
                            ),
                            Text(
                              ref.fmt(widget.client.credit),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: amountCtrl,
                  label: "MONTANT À REMBOURSER",
                  icon: FluentIcons.money_24_regular,
                  keyboardType: TextInputType.number,
                  hint: "Ex : 5000",
                ),
                const SizedBox(height: 16),
                EnterpriseWidgets.buildPremiumDropdown<String>(
                  label: "MODE DE PAIEMENT",
                  value: selectedMethod,
                  icon: FluentIcons.payment_24_regular,
                  items: const ["CASH", "MOBILE", "BANK"],
                  itemLabel: (v) {
                    if (v == "CASH") return "Espèces (CASH)";
                    if (v == "MOBILE") return "Mobile Money";
                    if (v == "BANK") return "Banque / Chèque";
                    return v;
                  },
                  onChanged: (val) => setDialogState(() => selectedMethod = val ?? "CASH"),
                ),
                const SizedBox(height: 16),
                EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: descCtrl,
                  label: "NOTE / DESCRIPTION",
                  icon: FluentIcons.note_24_regular,
                  hint: "Remboursement partiel...",
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

class _DebtItem extends ConsumerWidget {
  final Sale sale;

  const _DebtItem({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final remainingAmount = sale.totalAmount - sale.amountPaid;
    final progress = sale.totalAmount > 0 ? (sale.amountPaid / sale.totalAmount) : 0.0;
    final now = DateTime.now();
    
    int daysRemaining = 0;
    bool isOverdue = false;
    String dateLabel = "Non définie";
    Color statusColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    if (sale.dueDate != null) {
      final difference = sale.dueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
      daysRemaining = difference;
      isOverdue = difference < 0;
      dateLabel = DateFormatter.formatDate(sale.dueDate!);
      
      if (isOverdue) {
        statusColor = colorScheme.error;
      } else if (difference <= 3) {
        statusColor = Colors.orange;
      } else {
        statusColor = HSLColor.fromColor(colorScheme.primary).withHue(142).withSaturation(0.6).toColor();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(FluentIcons.receipt_20_regular, color: colorScheme.error, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Facture du ${DateFormatter.formatDate(sale.date)}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Reste à payer : ${ref.fmt(remainingAmount)}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ref.fmt(sale.totalAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress of payments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Progression de paiement : ${(progress * 100).toStringAsFixed(0)}%",
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                "${ref.fmt(sale.amountPaid)} payés sur ${ref.fmt(sale.totalAmount)}",
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? const Color(0xFF1E2129) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(progress >= 1.0 
                  ? Colors.green 
                  : (progress >= 0.5 ? Colors.blue : Colors.orange)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(FluentIcons.calendar_clock_20_regular, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      "Échéance : $dateLabel",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (sale.dueDate != null)
                  Text(
                    isOverdue ? "En retard de ${daysRemaining.abs()} jours" : "Dans $daysRemaining jours",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentItem extends ConsumerWidget {
  final ClientPayment payment;

  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final successColor = HSLColor.fromColor(colorScheme.primary)
        .withHue(142) // green hue
        .withSaturation(0.6)
        .withLightness(theme.brightness == Brightness.dark ? 0.45 : 0.38)
        .toColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(FluentIcons.arrow_down_24_regular, color: successColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormatter.formatDateTime(payment.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  payment.description ?? "Aucune description",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ref.fmt(payment.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: successColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  payment.paymentMethod == "CASH"
                      ? "Espèces"
                      : (payment.paymentMethod == "MOBILE" ? "Mobile Money" : "Banque"),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
