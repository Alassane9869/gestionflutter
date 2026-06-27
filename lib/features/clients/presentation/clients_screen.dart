import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/presentation/client_form_dialog.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/clients/presentation/client_details_screen.dart';
import 'package:danaya_plus/features/inventory/providers/global_search_provider.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyGlobalSearch(String query) {
    _searchController.text = query;
    ref.read(clientsSearchQueryProvider.notifier).update(query);
    Future.microtask(() => ref.read(searchSelectionProvider.notifier).set(null));
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse("tel:$cleanPhone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, String clientName, double? debtAmount) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final settings = ref.read(shopSettingsProvider).value;
    final shopName = settings?.name ?? "Danaya+";
    
    String message = "Bonjour $clientName, c'est l'établissement $shopName. ";
    if (debtAmount != null && debtAmount > 0) {
      message += "Nous vous contactons pour vous rappeler votre solde restant de ${ref.fmt(debtAmount)}. Merci de régulariser votre situation dès que possible. Bonne journée !";
    } else {
      message += "Nous espérons que vous allez bien. Merci pour votre fidélité !";
    }
    
    final whatsappUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email, String clientName) async {
    showDialog(
      context: context,
      builder: (ctx) => EmailComposeDialog(email: email, clientName: clientName),
    );
  }

  Widget _buildTabPill(String id, String label, IconData icon, Color activeColor, int count, String currentFilterTab) {
    final isSelected = currentFilterTab == id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => ref.read(clientsFilterTabProvider.notifier).update(id),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? activeColor.withValues(alpha: 0.12)
                : (isDark ? theme.colorScheme.surface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? activeColor.withValues(alpha: 0.8)
                  : (isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? activeColor : Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected 
                      ? (isDark ? Colors.white : activeColor) 
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? activeColor.withValues(alpha: 0.2) 
                      : (isDark ? const Color(0xFF2D3039) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? (isDark ? Colors.white : activeColor) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final asyncClients = ref.watch(clientListProvider);

    final sortBy = ref.watch(clientsSortByProvider);
    final filterTab = ref.watch(clientsFilterTabProvider);
    final searchQuery = ref.watch(clientsSearchQueryProvider);

    ref.listen<String>(clientsSearchQueryProvider, (prev, next) {
      if (next != _searchController.text) {
        _searchController.text = next;
      }
    });

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageCustomers) {
      return const AccessDeniedScreen(
        message: "Module Clients Restreint",
        subtitle: "Vous n'avez pas l'autorisation de gérer la base clients.",
      );
    }

    // Log access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
            userId: user.id,
            actionType: 'VIEW_CLIENTS',
            description: 'Consultation de la base clients par ${user.username}',
          );
    });

    // Écouter la sélection de recherche globale
    ref.listen<String?>(searchSelectionProvider, (previous, next) {
      if (next != null) {
        _applyGlobalSearch(next);
      }
    });

    // Sélection initiale (navigation directe)
    final pendingSearch = ref.read(searchSelectionProvider);
    if (pendingSearch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyGlobalSearch(pendingSearch);
      });
    }

    final settings = ref.watch(shopSettingsProvider).value;
    final vipThreshold = settings?.vipThreshold ?? 1000000.0;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FluentIcons.people_community_24_filled, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Fidélité & Clients", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
              Text("Gérez vos relations clients, le suivi des crédits et la fidélisation", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])),
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const ClientFormDialog()),
              icon: const Icon(FluentIcons.person_add_24_regular, size: 18),
              label: const Text("Nouveau client", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3)),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                shadowColor: accent.withValues(alpha: 0.3),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── KPI ROW ──
          asyncClients.when(
            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => const SizedBox(height: 100),
            data: (clients) {
              final totalCredit = clients.fold(0.0, (sum, c) => sum + c.credit);
              final debtorsCount = clients.where((c) => c.credit > 0).length;
              final topClient = clients.isNotEmpty 
                  ? clients.reduce((a, b) => a.totalSpent > b.totalSpent ? a : b)
                  : null;

              return SizedBox(
                height: 100,
                child: Row(children: [
                  Expanded(
                    child: _PremiumKpiCard(
                      icon: FluentIcons.people_24_regular,
                      label: "Total Clients",
                      value: "${clients.length}",
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PremiumKpiCard(
                      icon: FluentIcons.money_24_regular,
                      label: "Encours Crédits",
                      value: ref.fmt(totalCredit),
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PremiumKpiCard(
                      icon: FluentIcons.warning_24_regular,
                      label: "Débiteurs Actifs",
                      value: "$debtorsCount",
                      sub: "sur ${clients.length} clients",
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PremiumKpiCard(
                      icon: FluentIcons.star_24_regular,
                      label: "Meilleur Client",
                      value: topClient?.name ?? "–",
                      sub: topClient != null ? "CA: ${ref.fmt(topClient.totalSpent)}" : null,
                      color: AppTheme.successClr,
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── SEARCH & FILTERS ──
          asyncClients.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (clients) {
              final countAll = clients.length;
              final countDebtors = clients.where((c) => c.credit > 0).length;
              final countVips = clients.where((c) => c.totalSpent > vipThreshold).length;
              final countBirthdays = clients.where((c) => c.birthDate != null && c.birthDate!.month == DateTime.now().month).length;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB), width: 1.2),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF050507) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => ref.read(clientsSearchQueryProvider.notifier).update(v),
                              decoration: InputDecoration(
                                hintText: "Rechercher par nom, téléphone, email ou adresse...",
                                prefixIcon: Icon(
                                  FluentIcons.search_20_regular, 
                                  size: 18, 
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, 
                                  fontSize: 13,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sort dropdown
                        PopupMenuButton<String>(
                          onSelected: (v) => ref.read(clientsSortByProvider.notifier).update(v),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'name', child: Text("Trier par Nom")),
                            const PopupMenuItem(value: 'credit', child: Text("Trier par Dette")),
                            const PopupMenuItem(value: 'spent', child: Text("Trier par CA total")),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF050507) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  FluentIcons.arrow_sort_20_regular, 
                                  size: 16, 
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sortBy == 'name' ? "Nom" : (sortBy == 'credit' ? "Dette" : "CA Total"),
                                  style: TextStyle(
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w700, 
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  FluentIcons.chevron_down_16_regular,
                                  size: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabPill('all', "Tous les clients", FluentIcons.people_24_regular, accent, countAll, filterTab),
                          _buildTabPill('debtors', "Débiteurs", FluentIcons.money_off_24_regular, theme.colorScheme.error, countDebtors, filterTab),
                          _buildTabPill('vips', "VIPs ⭐", FluentIcons.star_24_regular, Colors.amber, countVips, filterTab),
                          _buildTabPill('birthdays', "Anniversaires du mois 🎂", FluentIcons.balloon_24_regular, Colors.pink, countBirthdays, filterTab),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 16),

          // ── CLIENT LIST ──
          asyncClients.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => Expanded(child: Center(child: Text('Erreur: $err'))),
            data: (clients) {
              var filtered = clients.where((c) {
                final matchQ = c.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
                              (c.phone?.contains(searchQuery) ?? false) ||
                              (c.email?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
                              (c.address?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
                
                bool matchTab = true;
                if (filterTab == 'debtors') {
                  matchTab = c.credit > 0;
                } else if (filterTab == 'vips') {
                  matchTab = c.totalSpent > vipThreshold;
                } else if (filterTab == 'birthdays') {
                  matchTab = c.birthDate != null && c.birthDate!.month == DateTime.now().month;
                }
                
                return matchQ && matchTab;
              }).toList();

              // Sorting
              if (sortBy == 'name') filtered.sort((a, b) => a.name.compareTo(b.name));
              if (sortBy == 'credit') filtered.sort((a, b) => b.credit.compareTo(a.credit));
              if (sortBy == 'spent') filtered.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

              if (filtered.isEmpty) {
                String emptyMsg = "Aucun client trouvé";
                if (filterTab == 'debtors') emptyMsg = "Aucun débiteur actif. Félicitations !";
                if (filterTab == 'vips') emptyMsg = "Aucun client VIP dans cette catégorie";
                if (filterTab == 'birthdays') emptyMsg = "Aucun anniversaire enregistré ce mois-ci";

                return Expanded(
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      filterTab == 'birthdays' 
                          ? FluentIcons.balloon_24_regular 
                          : (filterTab == 'vips' ? FluentIcons.star_24_regular : FluentIcons.people_24_regular), 
                      size: 56, 
                      color: Colors.grey.shade300
                    ),
                    const SizedBox(height: 16),
                    Text(emptyMsg, style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                  ])),
                );
              }

              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        final hasCredit = c.credit > 0;
                        final isVip = c.totalSpent > vipThreshold;
                        
                        final today = DateTime.now();
                        final isBirthdayToday = c.birthDate != null && 
                            c.birthDate!.day == today.day && 
                            c.birthDate!.month == today.month;

                        return Column(
                          children: [
                            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF3F4F6)),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Avatar squircle
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isVip 
                                                ? [Colors.amber.shade600, Colors.amber.shade400]
                                                : [accent, accent.withValues(alpha: 0.6)],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          c.name.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      
                                      // Name and Contact info
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    c.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 14,
                                                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isVip) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(FluentIcons.star_16_filled, size: 12, color: Colors.amber),
                                                ],
                                                if ((ref.watch(shopSettingsProvider).value?.loyaltyEnabled ?? false) && c.loyaltyPoints > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "• ${c.loyaltyPoints} pts",
                                                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w800),
                                                  ),
                                                ],
                                                if (isBirthdayToday) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(FluentIcons.balloon_16_regular, size: 12, color: Colors.pink),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                if (c.phone != null && c.phone!.isNotEmpty)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(FluentIcons.phone_16_regular, size: 12, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Text(c.phone!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                                    ],
                                                  ),
                                                if (c.email != null && c.email!.isNotEmpty)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(FluentIcons.mail_16_regular, size: 12, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Text(c.email!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                                    ],
                                                  ),
                                                if (c.address != null && c.address!.isNotEmpty)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(FluentIcons.location_16_regular, size: 12, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Text(c.address!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // CA Total & purchases
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              ref.fmt(c.totalSpent),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${c.totalPurchases} achat${c.totalPurchases > 1 ? 's' : ''}",
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        width: 1,
                                        height: 28,
                                        color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Debt Status
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: hasCredit ? theme.colorScheme.error : const Color(0xFF10B981),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            hasCredit ? "Dette: ${ref.fmt(c.credit)}" : "À jour",
                                            style: TextStyle(
                                              color: hasCredit ? theme.colorScheme.error : const Color(0xFF10B981),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 20),
                                      
                                      // Quick Action Buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (c.phone != null && c.phone!.isNotEmpty) ...[
                                            Tooltip(
                                              message: "Appeler",
                                              child: IconButton(
                                                icon: const Icon(FluentIcons.call_16_regular, size: 16, color: Colors.green),
                                                onPressed: () => _launchCall(c.phone!),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                splashRadius: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Tooltip(
                                              message: "WhatsApp",
                                              child: IconButton(
                                                icon: const Icon(FluentIcons.chat_16_regular, size: 16, color: Color(0xFF25D366)),
                                                onPressed: () => _launchWhatsApp(c.phone!, c.name, hasCredit ? c.credit : null),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                splashRadius: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          PopupMenuButton<String>(
                                            tooltip: 'Actions',
                                            icon: Icon(FluentIcons.more_vertical_20_regular, size: 16, color: Colors.grey.shade500),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'details',
                                                child: Row(
                                                  children: [
                                                    Icon(FluentIcons.eye_20_regular, size: 16),
                                                    SizedBox(width: 8),
                                                    Text("Voir détails"),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(FluentIcons.edit_20_regular, size: 16),
                                                    SizedBox(width: 8),
                                                    Text("Modifier"),
                                                  ],
                                                ),
                                              ),
                                              if (c.email != null && c.email!.isNotEmpty)
                                                const PopupMenuItem(
                                                  value: 'email',
                                                  child: Row(
                                                    children: [
                                                      Icon(FluentIcons.mail_20_regular, size: 16),
                                                      SizedBox(width: 8),
                                                      Text("Envoyer Email"),
                                                    ],
                                                  ),
                                                ),
                                              if (ref.watch(authServiceProvider).value?.isAdmin == true)
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(FluentIcons.delete_20_regular, size: 16, color: Colors.red),
                                                      const SizedBox(width: 8),
                                                      Text("Supprimer", style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                            onSelected: (v) {
                                              if (v == 'details') {
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c)));
                                              } else if (v == 'edit') {
                                                showDialog(context: context, builder: (_) => ClientFormDialog(client: c));
                                              } else if (v == 'email') {
                                                _launchEmail(c.email!, c.name);
                                              } else if (v == 'delete') {
                                                _confirmDelete(context, ref, c);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le client"),
        content: Text("Voulez-vous vraiment supprimer la fiche de ${client.name} ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirm == true) {
      if (client.credit > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible de supprimer un client avec une dette active (${ref.fmt(client.credit)})"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ref.read(clientListProvider.notifier).deleteClient(client.id);
    }
  }
}


class EmailComposeDialog extends ConsumerStatefulWidget {
  final String email;
  final String clientName;
  const EmailComposeDialog({super.key, required this.email, required this.clientName});

  @override
  ConsumerState<EmailComposeDialog> createState() => EmailComposeDialogState();
}

class EmailComposeDialogState extends ConsumerState<EmailComposeDialog> {
  late TextEditingController _subjectCtrl;
  late TextEditingController _messageCtrl;
  bool _isSending = false;
  
  String? _selectedTemplate;
  final Map<String, Map<String, String>> _templates = {
    "Contact direct": {
      "subject": "Contact direct",
      "message": "Bonjour [CLIENT],\n\n"
    },
    "Relance de paiement": {
      "subject": "Rappel de solde en attente",
      "message": "Bonjour [CLIENT],\n\nSauf erreur ou omission de notre part, nous constatons que votre compte présente un solde débiteur. Nous vous invitons à régulariser votre situation dans les meilleurs délais.\n\nMerci de votre confiance et bonne journée !"
    },
    "Remerciement d'achat": {
      "subject": "Merci pour votre fidélité",
      "message": "Bonjour [CLIENT],\n\nNous tenions à vous remercier chaleureusement pour votre récent achat. Votre confiance est notre plus belle récompense.\n\nÀ très bientôt !"
    },
    "Information Promo": {
      "subject": "Nouvelles offres pour vous",
      "message": "Bonjour [CLIENT],\n\nNous avons le plaisir de vous informer de nos dernières nouveautés et promotions qui pourraient vous intéresser.\n\nN'hésitez pas à nous contacter pour plus d'informations !"
    }
  };

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController(text: "Contact direct");
    _messageCtrl = TextEditingController(text: "Bonjour ${widget.clientName},\n\n");
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }
  
  void _applyTemplate(String templateName) {
    setState(() {
      _selectedTemplate = templateName;
      final t = _templates[templateName]!;
      _subjectCtrl.text = t["subject"]!;
      _messageCtrl.text = t["message"]!.replaceAll("[CLIENT]", widget.clientName);
    });
  }

  Future<void> _send() async {
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    
    final result = await ref.read(emailServiceProvider).sendProfessionalEmail(
      recipient: widget.email,
      subject: _subjectCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Email envoyé avec succès !"), 
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'envoi : ${result.errorMessage}"), 
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Nouveau Message Pro",
      icon: FluentIcons.mail_24_regular,
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.person_mail_24_regular, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Destinataire", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("${widget.clientName} (${widget.email})", style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          EnterpriseWidgets.buildPremiumDropdown<String>(
            label: "MODÈLE DE MESSAGE RAPIDE",
            value: _selectedTemplate,
            icon: FluentIcons.document_copy_24_regular,
            items: _templates.keys.toList(),
            itemLabel: (s) => s,
            onChanged: (val) {
              if (val != null) _applyTemplate(val);
            },
          ),
          const SizedBox(height: 16),
          EnterpriseWidgets.buildPremiumTextField(
            context,
            ctrl: _subjectCtrl,
            label: "OBJET DU MESSAGE",
            hint: "Saisissez l'objet...",
            icon: FluentIcons.text_font_16_regular,
          ),
          const SizedBox(height: 16),
          EnterpriseWidgets.buildPremiumTextField(
            context,
            ctrl: _messageCtrl,
            label: "CONTENU DU MESSAGE",
            hint: "Rédigez votre message ici...",
            icon: FluentIcons.text_description_24_regular,
            maxLines: 7,
          ),
          const SizedBox(height: 8),
          const Text(
            "💡 Astuce : Le message sera automatiquement formaté avec votre logo, vos couleurs et vos coordonnées professionnelles.",
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        FilledButton.icon(
          onPressed: _isSending ? null : _send,
          icon: _isSending 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(FluentIcons.send_20_regular, size: 18),
          label: Text(_isSending ? "Envoi en cours..." : "Envoyer l'e-mail"),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _PremiumKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;

  const _PremiumKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sub!,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
