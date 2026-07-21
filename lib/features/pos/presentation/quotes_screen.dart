import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:danaya_plus/features/pos/providers/quote_providers.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/create_quote_dialog.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/sale_doc_viewer.dart';
import 'package:danaya_plus/features/pos/services/quote_service.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final quotesAsync = ref.watch(quoteListProvider);
    final settings = ref.watch(shopSettingsProvider).value;

    final w = MediaQuery.of(context).size.width;

    return Container(
      color: c.bg,
      child: Column(
        children: [
          // ═══════════════════════════════════════════════════
          // TOP BAR
          // ═══════════════════════════════════════════════════
          _buildTopBar(c),

          // ═══════════════════════════════════════════════════
          // SCROLLABLE CONTENT
          // ═══════════════════════════════════════════════════
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPI GRID ──
                  quotesAsync.when(
                    loading: () => SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(c.primary)),
                      ),
                    ),
                    error: (_, __) => const SizedBox(height: 80),
                    data: (quotes) {
                      final totalValue = quotes.fold(0.0, (sum, q) => sum + (q['total_amount'] as num).toDouble());
                      final pendingCount = quotes.where((q) => (q['status'] ?? 'PENDING') == 'PENDING').length;
                      final acceptedCount = quotes.where((q) => q['status'] == 'ACCEPTED').length;
                      final convertedCount = quotes.where((q) => q['status'] == 'CONVERTED').length;

                      final cols = w > 1200 ? 4 : (w > 800 ? 2 : 1);
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: cols >= 4 ? 2.8 : 3.2,
                        children: [
                          UltraKpiCard(
                            label: "Total Devis",
                            value: "${quotes.length}",
                            icon: FluentIcons.document_copy_24_regular,
                            accent: c.blue,
                            change: "Tous statuts",
                            positive: true,
                          ),
                          UltraKpiCard(
                            label: "Valeur Totale",
                            value: ref.fmt(totalValue),
                            icon: FluentIcons.wallet_24_regular,
                            accent: c.emerald,
                            change: "${quotes.length} devis",
                            positive: true,
                          ),
                          UltraKpiCard(
                            label: "En attente",
                            value: "$pendingCount",
                            icon: FluentIcons.clock_24_regular,
                            accent: c.amber,
                            change: "À traiter",
                            positive: pendingCount == 0,
                          ),
                          UltraKpiCard(
                            label: "Facturés",
                            value: "$convertedCount",
                            icon: FluentIcons.checkmark_circle_24_regular,
                            accent: c.violet,
                            change: "$acceptedCount acceptés",
                            positive: convertedCount > 0,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── FILTERS & LIST ──
                  _buildSectionLabel("Liste des Devis", FluentIcons.document_text_24_regular, c),
                  const SizedBox(height: 16),
                  
                  // Filter Bar
                  _buildFilterBar(c),
                  const SizedBox(height: 12),

                  // Table/List
                  quotesAsync.when(
                    loading: () => SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(c.primary))),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text("Erreur: $err", style: TextStyle(color: c.rose)),
                    ),
                    data: (quotes) {
                      final filtered = quotes.where((q) {
                        final numMatch = q['quote_number'].toLowerCase().contains(_searchQuery.toLowerCase());
                        final clientMatch = (q['client']?['name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
                        final matchSearch = _searchQuery.isEmpty || numMatch || clientMatch;
                        final status = q['status'] ?? 'PENDING';
                        final matchStatus = _statusFilter == 'ALL' || status == _statusFilter;
                        return matchSearch && matchStatus;
                      }).toList();

                      if (filtered.isEmpty) {
                        return SectionCard(
                          title: "Aucun devis",
                          subtitle: "Modifiez vos filtres",
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(FluentIcons.document_search_24_regular, size: 48, color: c.textMuted),
                                  const SizedBox(height: 16),
                                  Text("Aucun devis correspondant", style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      filtered.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

                      return Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: c.surfaceElev,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                border: Border(bottom: BorderSide(color: c.border)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: _colHeader(c, "N° DEVIS")),
                                  Expanded(flex: 2, child: _colHeader(c, "DATE")),
                                  Expanded(flex: 3, child: _colHeader(c, "CLIENT")),
                                  Expanded(flex: 2, child: _colHeader(c, "MONTANT")),
                                  Expanded(flex: 2, child: _colHeader(c, "STATUT")),
                                  const SizedBox(width: 48), // Actions
                                ],
                              ),
                            ),
                            // Table Body
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: c.border, indent: 20, endIndent: 20),
                              itemBuilder: (context, index) {
                                final q = filtered[index];
                                return _buildQuoteRow(c, q, settings);
                              },
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildTopBar(DashColors c) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          // Animated dot
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle))
              .animate(onPlay: (ctrl) => ctrl.repeat())
              .custom(
                duration: 1500.ms,
                builder: (ctx, v, child) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primary,
                    boxShadow: [
                      BoxShadow(color: c.primary.withValues(alpha: v * 0.7), blurRadius: v * 14, spreadRadius: v * 2),
                    ],
                  ),
                ),
              ),
          const SizedBox(width: 12),
          Text(
            'Devis & Propositions',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Spacer(),
          // Action Buttons
          _buildActionBtn(c, FluentIcons.arrow_sync_24_regular, null, () => ref.invalidate(quoteListProvider), isIconOnly: true),
          const SizedBox(width: 8),
          _buildActionBtn(c, FluentIcons.add_24_filled, "Nouveau devis", () => showDialog(context: context, builder: (_) => const CreateQuoteDialog()), isPrimary: true),
        ],
      ),
    );
  }

  Widget _buildActionBtn(DashColors c, IconData icon, String? label, VoidCallback onTap, {bool isPrimary = false, bool isIconOnly = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: isIconOnly ? 8 : 12),
          decoration: BoxDecoration(
            color: isPrimary ? c.primary : c.surfaceElev,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isPrimary ? c.primary : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isPrimary ? Colors.white : c.textSecondary),
              if (!isIconOnly && label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPrimary ? Colors.white : c.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // SECTION LABEL
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildSectionLabel(String title, IconData icon, DashColors c) {
    return Row(
      children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(color: c.blue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: c.border)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // FILTER BAR
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildFilterBar(DashColors c) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // Search Box
          Expanded(
            flex: 3,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(fontSize: 13, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: "Rechercher (N° devis, Client...)",
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  prefixIcon: Icon(FluentIcons.search_24_regular, size: 16, color: c.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
          // Filter Chips
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(c, 'ALL', 'Tous', null),
                  _filterChip(c, 'PENDING', 'En attente', c.amber),
                  _filterChip(c, 'ACCEPTED', 'Acceptés', c.emerald),
                  _filterChip(c, 'CONVERTED', 'Facturés', c.violet),
                  _filterChip(c, 'REJECTED', 'Refusés', c.rose),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(DashColors c, String val, String label, Color? accent) {
    final sel = _statusFilter == val;
    final color = accent ?? c.blue;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = val),
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? color : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TABLE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _colHeader(DashColors c, String label) {
    return Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: c.textMuted, letterSpacing: 0.5),
    );
  }

  Widget _buildQuoteRow(DashColors c, Map<String, dynamic> q, dynamic settings) {
    final status = q['status'] ?? 'PENDING';
    final date = DateTime.parse(q['date']);
    
    final statusColor = status == 'REJECTED'
        ? c.rose
        : (status == 'CONVERTED' ? c.violet : (status == 'ACCEPTED' ? c.emerald : c.amber));
    
    final statusLabel = status == 'REJECTED'
        ? "Refusé"
        : (status == 'CONVERTED' ? "Facturé" : (status == 'ACCEPTED' ? "Accepté" : "En attente"));

    return InkWell(
      onTap: () => _previewQuote(context, q, settings),
      hoverColor: c.surfaceElev,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Devis #
            Expanded(
              flex: 2,
              child: Row(children: [
                Icon(FluentIcons.document_text_24_regular, size: 16, color: c.blue),
                const SizedBox(width: 8),
                Text(q['quote_number'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.textPrimary)),
              ]),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Text(DateFormatter.formatFullDate(date), style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ),
            // Client
            Expanded(
              flex: 3,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c.surfaceElev, shape: BoxShape.circle, border: Border.all(color: c.border)),
                  child: Icon(FluentIcons.person_16_regular, size: 14, color: c.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q['client']?['name'] ?? 'Client de passage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c.textPrimary), overflow: TextOverflow.ellipsis),
                      if (q['items'] != null) Text("${(q['items'] as List).length} articles", style: TextStyle(color: c.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
            ),
            // Montant
            Expanded(
              flex: 2,
              child: Text(
                ref.fmt(q['total_amount']),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: status == 'REJECTED' ? c.textMuted : c.textPrimary,
                  decoration: status == 'REJECTED' ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            // Statut
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 48,
              child: PopupMenuButton<String>(
                tooltip: 'Options',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                color: c.surface,
                icon: Icon(FluentIcons.more_horizontal_24_regular, size: 18, color: c.textSecondary),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'preview', child: Row(children: [
                    Icon(FluentIcons.eye_24_regular, size: 16, color: c.textSecondary),
                    const SizedBox(width: 10),
                    Text("Aperçu / Imprimer", style: TextStyle(color: c.textPrimary, fontSize: 13)),
                  ])),
                  if (status != 'CONVERTED') ...[
                    PopupMenuItem(value: 'edit', child: Row(children: [
                      Icon(FluentIcons.edit_24_regular, size: 16, color: c.textSecondary),
                      const SizedBox(width: 10),
                      Text("Modifier", style: TextStyle(color: c.textPrimary, fontSize: 13)),
                    ])),
                    PopupMenuItem(value: 'convert', child: Row(children: [
                      Icon(FluentIcons.cart_24_regular, size: 16, color: c.violet),
                      const SizedBox(width: 10),
                      Text("Convertir en vente", style: TextStyle(color: c.violet, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                    PopupMenuItem(value: 'accept', child: Row(children: [
                      Icon(FluentIcons.checkmark_circle_24_regular, size: 16, color: c.emerald),
                      const SizedBox(width: 10),
                      Text("Marquer Accepté", style: TextStyle(color: c.textPrimary, fontSize: 13)),
                    ])),
                    PopupMenuItem(value: 'reject', child: Row(children: [
                      Icon(FluentIcons.dismiss_circle_24_regular, size: 16, color: c.amber),
                      const SizedBox(width: 10),
                      Text("Marquer Refusé", style: TextStyle(color: c.textPrimary, fontSize: 13)),
                    ])),
                  ],
                  PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(FluentIcons.delete_24_regular, size: 16, color: c.rose),
                    const SizedBox(width: 10),
                    Text("Supprimer", style: TextStyle(color: c.rose, fontSize: 13)),
                  ])),
                ],
                onSelected: (v) {
                  if (v == 'preview') _previewQuote(context, q, settings);
                  if (v == 'edit') showDialog(context: context, builder: (_) => CreateQuoteDialog(quote: q));
                  if (v == 'convert') _convertToSale(context, ref, q);
                  if (v == 'accept') _changeStatus(ref, q['id'], 'ACCEPTED');
                  if (v == 'reject') _changeStatus(ref, q['id'], 'REJECTED');
                  if (v == 'delete') _confirmDelete(context, ref, q['id']);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // LOGIC
  // ═══════════════════════════════════════════════════════════════════════════════
  void _changeStatus(WidgetRef ref, String id, String newStatus) async {
    await ref.read(quoteRepositoryProvider).updateQuoteStatus(id, newStatus);
    ref.invalidate(quoteListProvider);
  }

  void _previewQuote(BuildContext context, Map<String, dynamic> q, dynamic settings) {
    final items = (q['items'] as List)
        .map(
          (i) => QuoteItem(
            name: i['custom_name'] ?? 'Article',
            qty: (i['quantity'] as num).toDouble(),
            unitPrice: (i['unit_price'] as num).toDouble(),
            unit: i['unit']?.toString(),
            description: i['description']?.toString(),
            discountAmount: (i['discount_amount'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();

    final data = QuoteData(
      quoteNumber: q['quote_number'],
      date: DateTime.parse(q['date']),
      validUntil: q['valid_until'] != null ? DateTime.parse(q['valid_until']) : null,
      items: items,
      subtotal: (q['subtotal'] as num).toDouble(),
      totalAmount: (q['total_amount'] as num).toDouble(),
      clientName: q['client']?['name'],
      clientPhone: q['client']?['phone'],
      clientAddress: q['client']?['address'],
      clientEmail: q['client']?['email'],
      cashierName: "Admin",
      settings: settings,
      taxRate: settings.useTax ? (settings.taxRate / 100) : 0,
    );

    showDialog(
      context: context,
      builder: (_) => SaleDocViewer(quoteData: data, initialType: "quote"),
    );
  }

  void _convertToSale(BuildContext context, WidgetRef ref, Map<String, dynamic> q) {
    EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Convertir en Vente ?",
      message: "Cela va charger tous les articles du devis dans le panier et vous rediriger vers la caisse.",
      confirmText: "Convertir",
      onConfirm: () async {
        ref.read(cartProvider.notifier).loadFromQuote(q['items']);
        await ref.read(quoteRepositoryProvider).updateQuoteStatus(q['id'], 'CONVERTED');
        ref.invalidate(quoteListProvider);
        ref.read(navigationProvider.notifier).setPage(3, ref);
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer le devis",
      message: "Êtes-vous sûr de vouloir supprimer définitivement ce devis ?",
      confirmText: "Supprimer",
      isDestructive: true,
      onConfirm: () async {
        await ref.read(quoteRepositoryProvider).deleteQuote(id);
        ref.invalidate(quoteListProvider);
      },
    );
  }
}
