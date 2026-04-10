import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/clients/domain/models/client_payment.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/providers/client_payment_provider.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/database/database_service.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF9FAFB),
      body: clientsAsync.when(
        data: (clients) {
          final debtClients = clients.where((c) => c.credit > 0).toList();
          final totalDebt = debtClients.fold(0.0, (sum, c) => sum + c.credit);

          return Row(
            children: [
              // Client List Sidebar
              Container(
                width: 380,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                ),
                child: Column(
                  children: [
                    _buildHeader(context, ref, totalDebt, debtClients.length),
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
                        itemCount: debtClients.where((c) => c.name.toLowerCase().contains(_clientSearch.toLowerCase())).length,
                        itemBuilder: (context, index) {
                          final filtered = debtClients.where((c) => c.name.toLowerCase().contains(_clientSearch.toLowerCase())).toList();
                          final client = filtered[index];
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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref.read(navigationProvider.notifier).setPage(0, ref),
              ),
              const Text("Portefeuille Dettes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade900]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TOTAL DES CRÉDITS", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(
                  ref.fmt(totalDebt),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text("$count clients endettés", style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.person_money_24_regular, size: 80, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text("Sélectionnez un client", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("pour voir le détail de sa dette et ses paiements.", style: TextStyle(color: Colors.grey)),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50) : null,
          border: Border(left: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 4)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              child: Text(client.name[0].toUpperCase(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(client.phone ?? "Pas de téléphone", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Text(
              ref.fmt(client.credit),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientDebtDetail extends ConsumerWidget {
  final Client client;

  const _ClientDebtDetail({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(clientPaymentsProvider(client.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Top Banner
        Container(
          padding: const EdgeInsets.all(40),
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoChip(context, Icons.phone, client.phone ?? "N/A"),
                        const SizedBox(width: 12),
                        _infoChip(context, Icons.shopping_basket, "${client.totalPurchases} achats"),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(FluentIcons.money_hand_24_regular),
                label: const Text("ENREGISTRER UN PAIEMENT", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showPaymentDialog(context, ref),
              ),
            ],
          ),
        ),

        // History Table
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("HISTORIQUE DES PAIEMENTS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 24),
                Expanded(
                  child: paymentsAsync.when(
                    data: (payments) {
                      if (payments.isEmpty) {
                        return const Center(child: Text("Aucun remboursement enregistré pour ce client."));
                      }
                      return ListView.builder(
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final p = payments[index];
                          return _PaymentItem(payment: p);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Text("Erreur: $e"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedMethod = "CASH";

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
                  if (amount <= 0 || amount > client.credit) {
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
                    clientId: client.id,
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.info_24_regular, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SOLDE ACTUEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                            Text(ref.fmt(client.credit), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.orange)),
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
                  hint: "Ex: 5000",
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

class _PaymentItem extends ConsumerWidget {
  final ClientPayment payment;

  const _PaymentItem({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_downward, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormatter.formatDateTime(payment.date), 
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(payment.description ?? "Aucune description", 
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ref.fmt(payment.amount), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              Text(payment.paymentMethod, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
