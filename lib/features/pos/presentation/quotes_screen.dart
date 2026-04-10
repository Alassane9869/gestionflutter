import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/pos/providers/quote_providers.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/create_quote_dialog.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/sale_doc_viewer.dart';
import 'package:danaya_plus/features/pos/services/quote_service.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final quotesAsync = ref.watch(quoteListProvider);
    final settings = ref.watch(shopSettingsProvider).value;



    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER PREMIUM ──
            EnterpriseWidgets.buildPremiumHeader(
              context,
              title: "Gestion des Devis",
              subtitle: "Propositions commerciales et devis clients",
              icon: FluentIcons.document_pdf_24_regular,
              trailing: FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const CreateQuoteDialog(),
                ),
                icon: const Icon(FluentIcons.add_20_filled, size: 18),
                label: const Text(
                  "NOUVEAU DEVIS",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── KPI ROW (Ultra Compact) ──
            quotesAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => const SizedBox(height: 60),
              data: (quotes) {
                final totalValue = quotes.fold(
                  0.0,
                  (sum, q) => sum + (q['total_amount'] as num).toDouble(),
                );
                final pendingCount = quotes
                    .where((q) => q['status'] == 'PENDING')
                    .length;

                return SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      _CompactKpi(
                        label: "TOTAL",
                        value: "${quotes.length}",
                        icon: FluentIcons.document_copy_20_regular,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      _CompactKpi(
                        label: "VALEUR",
                        value: ref.fmt(totalValue),
                        icon: FluentIcons.money_20_regular,
                        color: AppTheme.successClr,
                      ),
                      const SizedBox(width: 8),
                      _CompactKpi(
                        label: "EN ATTENTE",
                        value: "$pendingCount",
                        icon: FluentIcons.clock_20_regular,
                        color: AppTheme.warningClr,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── SEARCH BAR ──
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: "Rechercher par numéro ou client...",
                  prefixIcon: const Icon(
                    FluentIcons.search_20_regular,
                    size: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),

            // ── QUOTES LIST (Compact Table) ──
            Expanded(
              child: quotesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text("Erreur : $e")),
                data: (quotes) {
                  final filtered = quotes.where((q) {
                    final numMatch = q['quote_number'].toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                    final clientMatch = (q['client']?['name'] ?? '')
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                    return numMatch || clientMatch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        "Aucun devis trouvé",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: theme.dividerColor.withValues(alpha: 0.05),
                        ),
                        itemBuilder: (ctx, i) {
                          final q = filtered[i];
                          final date = DateTime.parse(q['date']);
                          final status = q['status'] ?? 'PENDING';

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _previewQuote(context, q, settings!),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    _StatusBadge(status: status),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            q['quote_number'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            "${q['client']?['name'] ?? 'Client de passage'} · ${DateFormatter.formatDayMonthTime(date)}",
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      ref.fmt(q['total_amount']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Quick Actions
                                    if (status != 'CONVERTED') ...[
                                      IconButton(
                                        icon: const Icon(
                                          FluentIcons.edit_20_regular,
                                          size: 16,
                                        ),
                                        color: Colors.blue,
                                        onPressed: () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              CreateQuoteDialog(quote: q),
                                        ),
                                        tooltip: "Modifier",
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          FluentIcons.cart_20_regular,
                                          size: 16,
                                        ),
                                        color: Colors.green,
                                        onPressed: () =>
                                            _convertToSale(context, ref, q),
                                        tooltip: "Convertir en Vente",
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        FluentIcons.print_20_regular,
                                        size: 16,
                                      ),
                                      color: accent,
                                      onPressed: () =>
                                          _previewQuote(context, q, settings!),
                                      tooltip: "Imprimer",
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        FluentIcons.delete_20_regular,
                                        size: 16,
                                      ),
                                      color: AppTheme.errorClr,
                                      onPressed: () =>
                                          _confirmDelete(context, ref, q['id']),
                                      tooltip: "Supprimer",
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewQuote(
    BuildContext context,
    Map<String, dynamic> q,
    dynamic settings,
  ) {
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
      validUntil: q['valid_until'] != null
          ? DateTime.parse(q['valid_until'])
          : null,
      items: items,
      subtotal: (q['subtotal'] as num).toDouble(),
      totalAmount: (q['total_amount'] as num).toDouble(),
      clientName: q['client']?['name'],
      clientPhone: q['client']?['phone'],
      clientAddress: q['client']?['address'], // Added clientAddress
      clientEmail: q['client']?['email'],     // Added clientEmail
      cashierName: "Admin",
      settings: settings,
      taxRate: settings.useTax ? (settings.taxRate / 100) : 0,
    );

    showDialog(
      context: context,
      builder: (_) => SaleDocViewer(quoteData: data, initialType: "quote"),
    );
  }

  void _convertToSale(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> q,
  ) {
    EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Convertir en Vente ?",
      message:
          "Cela va charger tous les articles du devis dans le panier et vous rediriger vers la caisse.",
      confirmText: "Convertir",
      onConfirm: () async {
        // 1. Load cart
        ref.read(cartProvider.notifier).loadFromQuote(q['items']);

        // 2. Set status to CONVERTED (optional but good)
        await ref
            .read(quoteRepositoryProvider)
            .updateQuoteStatus(q['id'], 'CONVERTED');
        ref.invalidate(quoteListProvider);

        // 3. Navigate to POS (index 3)
        ref.read(navigationProvider.notifier).setPage(3, ref);
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer le devis ?",
      message:
          "Cette action est irréversible et supprimera le devis définitivement.",
      confirmText: "Supprimer",
      isDestructive: true,
      onConfirm: () async {
        await ref.read(quoteRepositoryProvider).deleteQuote(id);
        ref.invalidate(quoteListProvider);
      },
    );
  }
}

class _CompactKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactKpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'PENDING':
        color = AppTheme.warningClr;
        label = "ATTENTE";
        break;
      case 'ACCEPTED':
        color = AppTheme.successClr;
        label = "ACCEPTÉ";
        break;
      case 'CONVERTED':
        color = Colors.purple;
        label = "FACTURÉ";
        break;
      case 'REJECTED':
        color = AppTheme.errorClr;
        label = "REFUSÉ";
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      width: 65,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
