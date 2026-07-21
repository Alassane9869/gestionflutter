import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/srm/providers/srm_service.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/srm/presentation/supplier_form_dialog.dart';
import 'package:danaya_plus/core/widgets/map_viewer_dialog.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/srm/presentation/purchase_screen.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/srm/presentation/widgets/purchase_detail_dialog.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterTab = 'ALL';
  String _sortBy = 'NAME';
  Supplier? _selectedSupplier;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ==========================================
  // UTILITY LAUNCHERS
  // ==========================================

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse("tel:$cleanPhone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, String name, double debt) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final settings = ref.read(shopSettingsProvider).value;
    final shopName = settings?.name ?? "Danaya+";

    String message = "Bonjour $name, c'est l'établissement $shopName. ";
    if (debt > 0) {
      message +=
          "Nous vous contactons concernant notre solde de factures restant dû de ${ref.fmt(debt)}. Pouvez-vous nous confirmer sa bonne réception ? Bonne journée !";
    } else {
      message +=
          "Nous vous contactons concernant le suivi de nos approvisionnements. Bonne journée !";
    }

    final whatsappUrl = Uri.parse(
        "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email, String name) async {
    final settings = ref.read(shopSettingsProvider).value;
    final shopName = settings?.name ?? "Danaya+";
    final uri = Uri.parse(
        "mailto:$email?subject=${Uri.encodeComponent('Suivi Approvisionnement - $shopName')}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final asyncSuppliers = ref.watch(supplierListProvider);

    _searchQuery = ref.watch(suppliersSearchQueryProvider);
    _filterTab = ref.watch(suppliersFilterTabProvider);
    _sortBy = ref.watch(suppliersSortByProvider);

    if (_searchController.text != _searchQuery) {
      _searchController.text = _searchQuery;
    }

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageSuppliers) {
      return const AccessDeniedScreen(
        message: "Module SRM Restreint",
        subtitle:
            "Vous n'avez pas l'autorisation de gérer les fournisseurs.",
      );
    }

    // Log access once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
            userId: user.id,
            actionType: 'VIEW_SUPPLIERS',
            description:
                'Consultation du réseau fournisseurs par ${user.username}',
          );
    });

    final c = DashColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // PREMIUM HEADER WITH GRADIENT ACCENT
              // ==========================================
              _buildPremiumHeader(theme, isDark, accent),
              const SizedBox(height: 14),

              // ==========================================
              // ANIMATED STATS ROW
              // ==========================================
              asyncSuppliers.when(
                loading: () => const SizedBox(
                    height: 90,
                    child: Center(child: CircularProgressIndicator())),
                error: (err, _) => const SizedBox.shrink(),
                data: (suppliers) => _buildStatsRow(
                    suppliers, isDark, theme, accent),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // MASTER-DETAIL SPLIT
              // ==========================================
              Expanded(
                child: asyncSuppliers.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) =>
                      Center(child: Text("Erreur: $err")),
                  data: (suppliers) =>
                      _buildMasterDetail(suppliers, isDark, theme, accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PREMIUM HEADER
  // ==========================================

  Widget _buildPremiumHeader(ThemeData theme, bool isDark, Color accent) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (Navigator.canPop(context)) ...[
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(FluentIcons.arrow_left_20_regular, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
          ),
        ),
        const SizedBox(width: 12),
      ],
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(FluentIcons.building_24_filled, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Réseau Fournisseurs", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
        Text("Gestion de l'approvisionnement & suivi fournisseurs", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ])),
      FilledButton.icon(
        onPressed: () => _showAddSupplierDialog(context),
        icon: const Icon(FluentIcons.person_add_24_regular, size: 18),
        label: const Text("Nouveau fournisseur", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3)),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: accent.withValues(alpha: 0.3),
        ),
      ),
    ]);
  }

  // ==========================================
  // ANIMATED STATS ROW
  // ==========================================

  Widget _buildStatsRow(
      List<Supplier> suppliers, bool isDark, ThemeData theme, Color accent) {
    final totalDebt =
        suppliers.fold(0.0, (sum, s) => sum + s.outstandingDebt);
    final totalPurchases =
        suppliers.fold(0.0, (sum, s) => sum + s.totalPurchases);
    final debtCount = suppliers.where((s) => s.outstandingDebt > 0).length;
    final healthyCount = suppliers.where((s) => s.outstandingDebt == 0).length;
    final debtRatio = suppliers.isNotEmpty
        ? (debtCount / suppliers.length * 100).round()
        : 0;

    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: _PremiumKpiCard(
              label: "Partenaires Actifs",
              value: "${suppliers.length}",
              icon: FluentIcons.building_retail_more_24_regular,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PremiumKpiCard(
              label: "Volume d'Achats",
              value: ref.fmt(totalPurchases),
              icon: FluentIcons.receipt_24_regular,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PremiumKpiCard(
              label: "Encours Fournisseurs",
              value: ref.fmt(totalDebt),
              icon: FluentIcons.money_hand_24_regular,
              color: totalDebt > 0 ? AppTheme.errorClr : Colors.grey,
              sub: "$debtRatio% du réseau",
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PremiumKpiCard(
              label: "Santé du Réseau",
              value: "${100 - debtRatio}%",
              icon: FluentIcons.heart_pulse_24_regular,
              color: debtRatio < 30 ? const Color(0xFF10B981) : AppTheme.errorClr,
              sub: "$healthyCount à jour",
            ),
          ),
        ],
      ),
    );
  }



  // ==========================================
  // MASTER-DETAIL LAYOUT
  // ==========================================

  Widget _buildMasterDetail(
      List<Supplier> suppliers, bool isDark, ThemeData theme, Color accent) {
    if (suppliers.isEmpty) {
      return _buildEmptyState(isDark, accent);
    }

    // 1. Filter
    List<Supplier> filtered = suppliers.where((s) {
      final nameMatch =
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (s.contactName ?? '')
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (s.phone ?? '').contains(_searchQuery);
      if (!nameMatch) return false;

      if (_filterTab == 'DEBT') return s.outstandingDebt > 0;
      if (_filterTab == 'OK') return s.outstandingDebt == 0;
      return true;
    }).toList();

    // 2. Sort
    if (_filterTab == 'TOP' || _sortBy == 'PURCHASES') {
      filtered.sort((a, b) => b.totalPurchases.compareTo(a.totalPurchases));
    } else if (_sortBy == 'DEBT') {
      filtered.sort(
          (a, b) => b.outstandingDebt.compareTo(a.outstandingDebt));
    } else {
      filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    // Auto-select
    if (_selectedSupplier == null && filtered.isNotEmpty) {
      _selectedSupplier = filtered.first;
    } else if (_selectedSupplier != null) {
      final updatedIdx =
          suppliers.indexWhere((s) => s.id == _selectedSupplier!.id);
      if (updatedIdx != -1) {
        _selectedSupplier = suppliers[updatedIdx];
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT PANE: Master List
        Expanded(
          flex: 4,
          child: _buildSupplierListPanel(
            filtered,
            isDark,
            theme,
            accent,
            onTap: (s) => setState(() => _selectedSupplier = s),
          ),
        ),
        
        // Divider
        Container(
          width: 1,
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        
        // RIGHT PANE: Details Panel
        Expanded(
          flex: 6,
          child: _selectedSupplier != null
              ? _buildDetailPanel(_selectedSupplier!, isDark, theme, accent)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.building_retail_24_regular, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        "Sélectionnez un fournisseur pour voir ses détails",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ==========================================
  // LEFT PANEL: SUPPLIER LIST
  // ==========================================

  Widget _buildSupplierListPanel(
      List<Supplier> filtered, bool isDark, ThemeData theme, Color accent,
      {ValueChanged<Supplier>? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search + sort header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (v) => ref.read(suppliersSearchQueryProvider.notifier).update(v),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "Rechercher un fournisseur...",
                    prefixIcon:
                        const Icon(FluentIcons.search_16_regular, size: 16),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(suppliersSearchQueryProvider.notifier).update('');
                            },
                            icon: const Icon(FluentIcons.dismiss_12_regular,
                                size: 14),
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                // Sort + filter tabs
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPillTab("Tous", 'ALL', isDark, theme,
                                count: filtered.length),
                            _buildPillTab("Dettes", 'DEBT', isDark, theme,
                                color: AppTheme.errorClr),
                            _buildPillTab("À Jour", 'OK', isDark, theme,
                                color: const Color(0xFF10B981)),
                            _buildPillTab("Top Achats", 'TOP', isDark, theme,
                                color: const Color(0xFFF97316)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(FluentIcons.arrow_sort_20_regular,
                          size: 16,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                      tooltip: "Trier",
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      color: isDark
                          ? const Color(0xFF0F0F14)
                          : Colors.white,
                      onSelected: (val) =>
                          ref.read(suppliersSortByProvider.notifier).update(val),
                      itemBuilder: (ctx) => [
                        _buildSortItem('NAME', 'Nom (A-Z)',
                            FluentIcons.text_sort_ascending_20_regular),
                        _buildSortItem('PURCHASES', 'Volume d\'Achat',
                            FluentIcons.arrow_trending_20_regular),
                        _buildSortItem('DEBT', 'Dettes impayées',
                            FluentIcons.money_hand_20_regular),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade200,
          ),
          // Results count
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "${filtered.length} fournisseur${filtered.length > 1 ? 's' : ''}",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500),
            ),
          ),
          // Supplier list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.search_24_regular,
                            size: 36,
                            color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        Text("Aucun résultat",
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final s = filtered[i];
                      final isSelected =
                          _selectedSupplier?.id == s.id;
                      return _buildSupplierCard(
                          s, isSelected, isDark, theme, onTap);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(Supplier s, bool isSelected, bool isDark,
      ThemeData theme, ValueChanged<Supplier>? onTap) {
    final hasDebt = s.outstandingDebt > 0;
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap(s);
            } else {
              setState(() => _selectedSupplier = s);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.06)
                  : (isDark ? const Color(0xFF141620) : const Color(0xFFF9FAFB)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.35)
                    : (isDark ? const Color(0xFF1A1D24) : const Color(0xFFE5E7EB)),
                width: 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
              ],
            ),
              child: Row(
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s.name
                        .substring(0, s.name.length > 1 ? 2 : 1)
                        .toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isDark
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasDebt) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppTheme.errorClr,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.errorClr
                                        .withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(FluentIcons.person_12_regular,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              s.contactName ?? s.phone ?? 'Aucun contact',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Financial summary
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ref.fmt(s.totalPurchases),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF10B981)),
                    ),
                    if (hasDebt)
                      Text(
                        ref.fmt(s.outstandingDebt),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: AppTheme.errorClr.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  FluentIcons.chevron_right_16_regular,
                  size: 14,
                  color: isSelected ? accent : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RIGHT PANEL: DETAIL DASHBOARD
  // ==========================================

  Widget _buildDetailPanel(
      Supplier s, bool isDark, ThemeData theme, Color accent,
      {Key? key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: _buildSupplierDetailsDashboard(s, isDark, theme, accent),
    );
  }

  Widget _buildSupplierDetailsDashboard(
      Supplier s, bool isDark, ThemeData theme, Color accent) {
    final purchasesAsync = ref.watch(purchaseListProvider);
    final hasDebt = s.outstandingDebt > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ──── PREMIUM HERO HEADER ────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.06),
                  accent.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        image: s.logoPath != null && File(s.logoPath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(s.logoPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: s.logoPath == null || !File(s.logoPath!).existsSync()
                          ? Text(
                              s.name.substring(0, s.name.length > 1 ? 2 : 1).toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                  fontSize: 24),
                            )
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildStatusBadge(
                                label: hasDebt ? "SOLDE DÛ" : "À JOUR",
                                icon: hasDebt
                                    ? FluentIcons.warning_16_regular
                                    : FluentIcons.checkmark_circle_16_regular,
                                color: hasDebt
                                    ? AppTheme.errorClr
                                    : const Color(0xFF10B981),
                                isDark: isDark,
                              ),
                              if (s.contactName != null && s.contactName!.isNotEmpty)
                                _buildStatusBadge(
                                  label: s.contactName!,
                                  icon: FluentIcons.person_16_regular,
                                  color: Colors.blue,
                                  isDark: isDark,
                                ),
                              if (s.phone != null && s.phone!.isNotEmpty)
                                _buildStatusBadge(
                                  label: s.phone!,
                                  icon: FluentIcons.phone_16_regular,
                                  color: Colors.grey,
                                  isDark: isDark,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildSupplierMoreMenu(s, isDark, accent),
                  ],
                ),
                const SizedBox(height: 16),
                // ──── INLINE ACTION BUTTONS ────
                Row(
                  children: [
                    if (s.phone != null && s.phone!.isNotEmpty) ...[
                      _buildActionBtn(FluentIcons.call_16_regular, "Appeler", () => _launchCall(s.phone!), isDark),
                      const SizedBox(width: 8),
                      _buildActionBtn(FluentIcons.chat_16_regular, "WhatsApp", () => _launchWhatsApp(s.phone!, s.name, s.outstandingDebt), isDark),
                      const SizedBox(width: 8),
                    ],
                    if (s.email != null && s.email!.isNotEmpty) ...[
                      _buildActionBtn(FluentIcons.mail_16_regular, "Email", () => _launchEmail(s.email!, s.name), isDark),
                      const SizedBox(width: 8),
                    ],
                    if (s.address != null && s.address!.isNotEmpty)
                      _buildActionBtn(FluentIcons.location_16_regular, "Carte", () {
                        final settings = ref.read(shopSettingsProvider).value;
                        final shopAddress = settings?.address ?? 'Dakar, Senegal';
                        MapViewerDialog.show(
                          context,
                          originAddress: s.address!,
                          destinationAddress: shopAddress,
                          originLabel: s.name,
                          destinationLabel: settings?.name ?? 'Ma Boutique',
                        );
                      }, isDark),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PurchaseScreen(supplier: s))),
                      icon: const Icon(FluentIcons.cart_16_regular, size: 16),
                      label: const Text("Nouvel achat",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ──── FINANCIAL TELEMETRY ROW ────
          _buildFinancialKPIs(s, isDark, theme, accent, hasDebt),

          const SizedBox(height: 20),

          // ──── DEBT GAUGE ────
          if (hasDebt) ...[
            _buildDebtGauge(s, isDark, theme, accent),
            const SizedBox(height: 20),
          ],

          // ──── DETAILS GRID ────
          const Text(
            "INFORMATIONS DÉTAILLÉES",
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
                _buildGridInfoRow("Téléphone", s.phone ?? "Non renseigné", FluentIcons.phone_20_regular, isDark, theme),
                _buildDivider(isDark),
                _buildGridInfoRow("Adresse Email", s.email ?? "Non renseigné", FluentIcons.mail_20_regular, isDark, theme),
                _buildDivider(isDark),
                _buildGridInfoRow("Contact Principal", s.contactName ?? "Non renseigné", FluentIcons.person_20_regular, isDark, theme),
                if (s.address != null && s.address!.isNotEmpty) ...[
                  _buildDivider(isDark),
                  _buildGridInfoRow("Adresse Géographique", s.address!, FluentIcons.location_20_regular, isDark, theme),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ──── ORDER HISTORY ────
          _buildOrderHistorySection(s, isDark, theme, purchasesAsync),
        ],
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


  Widget _buildSupplierMoreMenu(Supplier s, bool isDark, Color accent) {
    return PopupMenuButton<String>(
      icon: const Icon(FluentIcons.more_vertical_20_regular, color: Colors.grey, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF0F0F14) : Colors.white,
      onSelected: (val) {
        if (val == 'edit') {
          showDialog(
              context: context,
              builder: (_) => SupplierFormDialog(supplier: s));
        }
        if (val == 'delete') _confirmSupplierDelete(context, ref, s);
        if (val == 'purchase') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PurchaseScreen(supplier: s)));
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(FluentIcons.edit_20_regular,
                size: 16, color: isDark ? Colors.white70 : Colors.black54),
            const SizedBox(width: 12),
            const Text("Modifier le profil", style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          value: 'purchase',
          child: Row(children: [
            Icon(FluentIcons.cart_20_regular, size: 16, color: accent),
            const SizedBox(width: 12),
            Text("Nouvel achat", style: TextStyle(fontSize: 13, color: accent)),
          ]),
        ),
        if (ref.read(authServiceProvider).value?.isAdmin == true) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(FluentIcons.delete_20_regular, size: 16, color: Colors.red),
              SizedBox(width: 12),
              Text("Supprimer", style: TextStyle(color: Colors.red, fontSize: 13)),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(
      {required String label,
      required IconData icon,
      required Color color,
      required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }


  Widget _buildActionBtn(IconData icon, String tooltip, VoidCallback onTap, bool isDark) {
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

  Widget _buildFinancialKPIs(
      Supplier s, bool isDark, ThemeData theme, Color accent, bool hasDebt) {
    final paidRatio = s.totalPurchases > 0
        ? ((s.totalPurchases - s.outstandingDebt) / s.totalPurchases).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildCompactKPI("ACHATS TOTAUX", ref.fmt(s.totalPurchases), isDark, null),
            ),
            VerticalDivider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300, width: 32),
            Expanded(
              child: _buildCompactKPI("DETTE EXPLOIT.", ref.fmt(s.outstandingDebt), isDark, hasDebt ? AppTheme.errorClr : null),
            ),
            VerticalDivider(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300, width: 32),
            Expanded(
              child: _buildCompactKPI("TAUX PAIEMENT", "${(paidRatio * 100).toStringAsFixed(0)}%", isDark, paidRatio > 0.8 ? const Color(0xFF10B981) : AppTheme.warningClr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactKPI(String label, String value, bool isDark, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color ?? (isDark ? Colors.white : Colors.black87))),
        ),
      ],
    );
  }

  Widget _buildDebtGauge(
      Supplier s, bool isDark, ThemeData theme, Color accent) {
    final paidAmount = s.totalPurchases - s.outstandingDebt;
    final debtPercent = s.totalPurchases > 0
        ? (s.outstandingDebt / s.totalPurchases * 100).round()
        : 0;

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
        border: Border.all(
            color: AppTheme.errorClr.withValues(alpha: 0.12)),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(FluentIcons.warning_24_regular,
                        size: 16, color: AppTheme.errorClr),
                  ),
                  const SizedBox(width: 12),
                  const Text("SITUATION DÉBITRICE",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppTheme.errorClr)),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _showPayDebtDialog(context, s),
                icon: const Icon(FluentIcons.money_hand_20_regular,
                    size: 14),
                label: const Text("Régler la dette",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorClr,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Gauge bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 10,
                        child: Stack(
                          children: [
                            Container(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey.shade200,
                            ),
                            FractionallySizedBox(
                              widthFactor: s.totalPurchases > 0
                                  ? (paidAmount / s.totalPurchases)
                                      .clamp(0.0, 1.0)
                                  : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF10B981),
                                      Color(0xFF0D9488),
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius:
                                    BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                                "Payé: ${ref.fmt(paidAmount)}",
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981))),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.errorClr,
                                borderRadius:
                                    BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                                "Reste: ${ref.fmt(s.outstandingDebt)} ($debtPercent%)",
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.errorClr)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildOrderHistorySection(Supplier s, bool isDark, ThemeData theme,
      AsyncValue<List<PurchaseOrder>> purchasesAsync) {
    return SectionCard(
      title: "HISTORIQUE DES COMMANDES",
      subtitle: "Suivi des 5 dernières commandes d'approvisionnement",
      action: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text("5 dernières",
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500)),
      ),
      child: purchasesAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator())),
        error: (err, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
                child:
                    Text("Erreur historique : $err"))),
        data: (orders) {
          final filteredOrders = orders
              .where((o) => o.supplierId == s.id)
              .take(5)
              .toList();
          if (filteredOrders.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.receipt_24_regular,
                        size: 40,
                        color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                        "Aucun achat enregistré",
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                        "Les commandes d'approvisionnement pour ce fournisseur s'afficheront ici.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredOrders.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade200),
            itemBuilder: (ctx, idx) {
              final o = filteredOrders[idx];
              return _buildOrderRow(o, isDark, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderRow(
      PurchaseOrder o, bool isDark, ThemeData theme) {
    final orderDebt = o.totalAmount - o.amountPaid;
    final isPaid = orderDebt <= 0;
    final paymentPercent = o.totalAmount > 0
        ? (o.amountPaid / o.totalAmount).clamp(0.0, 1.0)
        : 1.0;

    // Status config
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (o.status) {
      case OrderStatus.DELIVERED:
        statusColor = const Color(0xFF10B981);
        statusLabel = "Livré";
        statusIcon = FluentIcons.checkmark_circle_16_regular;
        break;
      case OrderStatus.CANCELLED:
        statusColor = Colors.grey;
        statusLabel = "Annulé";
        statusIcon = FluentIcons.dismiss_circle_16_regular;
        break;
      default:
        statusColor = AppTheme.warningClr;
        statusLabel = "En cours";
        statusIcon = FluentIcons.clock_16_regular;
    }

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => PurchaseDetailDialog(order: o),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, size: 16, color: statusColor),
            ),
            const SizedBox(width: 14),
            // Reference + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(o.reference,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusColor)),
                      ),
                      if (o.paymentMethod != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(o.paymentMethod!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(DateFormatter.formatDateTime(o.date),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Payment progress mini
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text("${(paymentPercent * 100).round()}%",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isPaid
                              ? const Color(0xFF10B981)
                              : AppTheme.warningClr)),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: paymentPercent,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(isPaid
                          ? const Color(0xFF10B981)
                          : AppTheme.warningClr),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(ref.fmt(o.totalAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13)),
                if (!isPaid)
                  Text(
                    "Reste : ${ref.fmt(orderDebt)}",
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.errorClr,
                        fontWeight: FontWeight.w700),
                  )
                else
                  const Text(
                    "Payé",
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(FluentIcons.chevron_right_16_regular,
                size: 14, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PILL TAB + SORT ITEMS
  // ==========================================

  Widget _buildPillTab(
      String label, String type, bool isDark, ThemeData theme,
      {Color? color, int? count}) {
    final selected = _filterTab == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => ref.read(suppliersFilterTabProvider.notifier).update(type),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (color ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? (color ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected
                      ? (color ?? theme.colorScheme.primary)
                      : (isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                ),
              ),
              if (count != null && selected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (color ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text("$count",
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color:
                              color ?? theme.colorScheme.primary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(
      String value, String label, IconData icon) {
    final isActive = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : null)),
          if (isActive) ...[
            const Spacer(),
            Icon(FluentIcons.checkmark_12_regular,
                size: 14,
                color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _buildEmptyState(bool isDark, Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.06),
                  accent.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                  color: accent.withValues(alpha: 0.1)),
            ),
            child: Icon(FluentIcons.people_add_24_regular,
                size: 48,
                color: accent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            "Aucun fournisseur enregistré",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark
                    ? Colors.grey.shade300
                    : Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            "Commencez par ajouter votre premier partenaire\npour suivre vos approvisionnements",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _showAddSupplierDialog(context),
            icon: const Icon(FluentIcons.person_add_20_filled, size: 16),
            label: const Text("Ajouter un fournisseur",
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOG: MOBILE DETAILS
  // ==========================================


  // ==========================================
  // ACTIONS
  // ==========================================

  void _showAddSupplierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const SupplierFormDialog(),
    ).then((_) {
      ref.invalidate(supplierListProvider);
    });
  }

  void _confirmSupplierDelete(
      BuildContext context, WidgetRef ref, Supplier s) async {
    if (s.outstandingDebt > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Impossible de supprimer un fournisseur avec une dette active (${ref.fmt(s.outstandingDebt)})"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer le fournisseur",
      message:
          "Voulez-vous vraiment supprimer ${s.name} ? Cette action est irréversible et supprimera tout l'historique associé.",
      confirmText: "SUPPRIMER",
      isDestructive: true,
      onConfirm: () async {
        try {
          await ref
              .read(supplierListProvider.notifier)
              .deleteSupplier(s.id);
          setState(() {
            _selectedSupplier = null;
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text("Fournisseur supprimé avec succès"),
                  backgroundColor: Color(0xFF10B981)),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    e.toString().replaceAll('Exception: ', '')),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
    );
  }

  // ==========================================
  // PAY DEBT DIALOG
  // ==========================================

  void _showPayDebtDialog(BuildContext context, Supplier s) {
    final amountCtrl = TextEditingController(
        text: s.outstandingDebt.toStringAsFixed(0));
    final descCtrl = TextEditingController(
        text: "Règlement dette - ${s.name}");
    FinancialAccount? selectedAccount;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final accounts =
              ref.watch(myTreasuryAccountsProvider).value ?? [];
          if (selectedAccount == null && accounts.isNotEmpty) {
            selectedAccount = accounts.first;
          }

          return EnterpriseWidgets.buildPremiumDialog(
            ctx,
            title: "Régler la dette",
            icon: FluentIcons.money_hand_24_regular,
            width: 480,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Annuler"),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: selectedAccount == null
                    ? null
                    : () async {
                        final amountToPay =
                            double.tryParse(amountCtrl.text) ?? 0.0;
                        if (amountToPay <= 0 ||
                            amountToPay > s.outstandingDebt) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Montant invalide. Il doit être supérieur à 0 et inférieur ou égal à la dette."),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (selectedAccount!.balance < amountToPay) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Solde insuffisant sur '${selectedAccount!.name}' (Solde actuel : ${ref.fmt(selectedAccount!.balance)})."),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          final db = await ref
                              .read(databaseServiceProvider)
                              .database;
                          final activeSession = await ref
                              .read(activeSessionProvider.future);
                          final user = ref
                              .read(authServiceProvider)
                              .value;

                          await db.transaction((txn) async {
                            await txn.execute(
                              'UPDATE financial_accounts SET balance = balance - ? WHERE id = ?',
                              [
                                amountToPay,
                                selectedAccount!.id
                              ],
                            );

                            await txn.execute(
                              'UPDATE suppliers SET outstanding_debt = outstanding_debt - ? WHERE id = ?',
                              [amountToPay, s.id],
                            );

                            await txn.insert(
                                'financial_transactions', {
                              'id':
                                  'TX-PAY-${const Uuid().v4()}',
                              'account_id':
                                  selectedAccount!.id,
                              'type': 'OUT',
                              'amount': amountToPay,
                              'category': 'EXPENSE',
                              'description':
                                  descCtrl.text.trim(),
                              'date': DateTime.now()
                                  .toIso8601String(),
                              'reference_id': s.id,
                              'session_id':
                                  activeSession?.id,
                              'user_id':
                                  user?.id ?? 'system',
                            });
                          });

                          ref.invalidate(supplierListProvider);
                          ref
                              .read(treasuryProvider.notifier)
                              .refresh();

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Paiement de la dette enregistré avec succès !"),
                                backgroundColor:
                                    Color(0xFF10B981),
                                behavior:
                                    SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      "Erreur lors du paiement : $e"),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: const Text("Enregistrer le paiement"),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Debt summary header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.errorClr.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.errorClr
                            .withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(FluentIcons.warning_16_regular,
                          size: 16, color: AppTheme.errorClr),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Solde restant dû : ${ref.fmt(s.outstandingDebt)}",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.errorClr),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Enregistrez un versement effectué auprès de ${s.name} pour réduire son solde restant dû.",
                  style:
                      const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                EnterpriseWidgets
                    .buildPremiumDropdown<FinancialAccount>(
                  label: "COMPTE FINANCIER ÉMETTEUR",
                  value: selectedAccount,
                  icon: FluentIcons.wallet_24_regular,
                  items: accounts,
                  itemLabel: (acc) =>
                      "${acc.name} (${ref.fmt(acc.balance)})",
                  onChanged: (acc) =>
                      setState(() => selectedAccount = acc),
                ),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumTextField(
                  ctx,
                  ctrl: amountCtrl,
                  label: "MONTANT VERSÉ",
                  hint: "0",
                  icon: FluentIcons.money_24_regular,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumTextField(
                  ctx,
                  ctrl: descCtrl,
                  label: "DESCRIPTION DE L'OPÉRATION",
                  hint: "Ex: Règlement d'acompte...",
                  icon: FluentIcons.text_description_20_regular,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PremiumKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;

  const _PremiumKpiCard({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
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

