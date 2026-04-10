import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/features/pos/presentation/return_sale_dialog.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

import 'package:flutter/services.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Barcode Scanning
  final _barcodeFocusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPressTime;

  @override
  void dispose() {
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _handleBarcode(String code) {
    if (code.isEmpty) return;
    
    String saleId = '';
    if (code.startsWith('verify:sale:')) {
      saleId = code.replaceFirst('verify:sale:', '');
    } else if (code.startsWith('SALE:')) {
      // Legacy support
      saleId = code.replaceFirst('SALE:', '');
    } else {
      // Maybe it's just the raw ID?
      saleId = code;
    }

    if (saleId.isEmpty) return;

    final salesAsync = ref.read(salesHistoryProvider);
    salesAsync.whenData((sales) {
      try {
        final sd = sales.firstWhere(
          (s) => s.sale.id.toLowerCase() == saleId.toLowerCase() || 
                 s.sale.id.toLowerCase().startsWith(saleId.toLowerCase()),
        );
        
        _showSaleDetail(context, sd, ref.fmt, Theme.of(context), Theme.of(context).brightness == Brightness.dark);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vente non trouvée ou non chargée dans l'historique."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      final elapsed = _lastKeyPressTime == null
          ? 0
          : now.difference(_lastKeyPressTime!).inMilliseconds;
      _lastKeyPressTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _handleBarcode(_barcodeBuffer);
          _barcodeBuffer = '';
        }
      } else {
        // A scanner is VERY fast (< 50ms per char).
        if (elapsed > 100 && _barcodeBuffer.isNotEmpty) {
          _barcodeBuffer = '';
        }

        final char = event.character;
        if (char != null && char.isNotEmpty) {
          // Allow alphanumeric and special chars for prefix
          if (RegExp(r'[a-zA-Z0-9:-]').hasMatch(char)) {
            _barcodeBuffer += char;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final salesAsync = ref.watch(salesHistoryProvider);
    final user = ref.watch(authServiceProvider).value;
    final isGlobalRole = user?.role == UserRole.admin || 
                         user?.role == UserRole.manager || 
                         user?.role == UserRole.adminPlus;
    

    return KeyboardListener(
      focusNode: _barcodeFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ── HEADER ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(FluentIcons.receipt_24_filled, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isGlobalRole ? "Historique des Ventes" : "Mes Ventes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                  Text(isGlobalRole ? "Consultez, filtrez et gérez toutes vos transactions" : "Consultez et gérez vos propres transactions de vente", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ]),
              ]),
            ])),
            // Refresh button
            IconButton.filled(
              onPressed: () => ref.invalidate(salesHistoryProvider),
              icon: const Icon(FluentIcons.arrow_sync_24_regular, size: 18),
              tooltip: "Actualiser",
              style: IconButton.styleFrom(backgroundColor: accent.withValues(alpha: 0.1), foregroundColor: accent),
            ),
          ]),
          const SizedBox(height: 20),

          // ── KPI CARDS ──
          salesAsync.when(
            loading: () => const SizedBox(height: 90),
            error: (_, __) => const SizedBox(height: 90),
            data: (sales) {
              final today = DateTime.now();
              final todaySales = sales.where((s) => s.sale.date.year == today.year && s.sale.date.month == today.month && s.sale.date.day == today.day && s.sale.status != 'REFUNDED').toList();
              final todayTotal = todaySales.fold(0.0, (s, e) => s + e.sale.totalAmount);
              final allCompleted = sales.where((s) => s.sale.status != 'REFUNDED').toList();
              final allTotal = allCompleted.fold(0.0, (s, e) => s + e.sale.totalAmount);
              final creditSales = sales.where((s) => s.sale.isCredit && s.sale.status != 'REFUNDED').toList();
              final creditTotal = creditSales.fold(0.0, (s, e) => s + e.sale.totalAmount);
              final avgTicket = allCompleted.isNotEmpty ? allTotal / allCompleted.length : 0.0;

              return SizedBox(
                height: 88,
                child: Row(children: [
                  _KpiCard(icon: FluentIcons.calendar_today_24_regular, label: "Aujourd'hui", value: ref.fmt(todayTotal), sub: "${todaySales.length} ventes", color: accent, isDark: isDark),
                  const SizedBox(width: 12),
                  _KpiCard(icon: FluentIcons.wallet_24_regular, label: "Total (100 dernières)", value: ref.fmt(allTotal), sub: "${allCompleted.length} ventes", color: const Color(0xFF10B981), isDark: isDark),
                  const SizedBox(width: 12),
                  _KpiCard(icon: FluentIcons.receipt_money_24_regular, label: "Panier moyen", value: ref.fmt(avgTicket), sub: "par vente", color: const Color(0xFF6366F1), isDark: isDark),
                  const SizedBox(width: 12),
                  _KpiCard(icon: FluentIcons.people_money_24_regular, label: "Crédits en cours", value: ref.fmt(creditTotal), sub: "${creditSales.length} clients", color: Colors.orange, isDark: isDark),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── FILTRES ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
            ),
            child: Row(children: [
              // Search
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Rechercher ou scanner (N° ticket, Client...)",
                    prefixIcon: const Icon(FluentIcons.qr_code_24_regular, size: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              _VertDivider(isDark: isDark),
              // Status chips
              ...[
                ('all', 'Tous', null),
                ('success', 'Complétés', const Color(0xFF10B981)),
                ('credit', 'Crédits', Colors.orange),
                ('refunded', 'Annulés', Colors.red),
              ].map((f) => _FilterPill(
                label: f.$2,
                isSelected: _statusFilter == f.$1,
                color: f.$3,
                onTap: () => setState(() => _statusFilter = f.$1),
              )),
              _VertDivider(isDark: isDark),
              // Payment filter
              PopupMenuButton<String>(
                tooltip: "Filtrer par méthode de paiement",
                onSelected: (v) => setState(() => _paymentFilter = v),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'all', child: Text("Toutes les méthodes")),
                  const PopupMenuItem(value: 'Espèces', child: Text("Espèces")),
                  const PopupMenuItem(value: 'Mobile Money', child: Text("Mobile Money")),
                  const PopupMenuItem(value: 'Wave', child: Text("Wave")),
                  const PopupMenuItem(value: 'Chèque', child: Text("Chèque")),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _paymentFilter != 'all' ? accent.withValues(alpha: 0.1) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(FluentIcons.payment_24_regular, size: 16, color: _paymentFilter != 'all' ? accent : Colors.grey),
                    const SizedBox(width: 6),
                    Text(_paymentFilter == 'all' ? "Paiement" : _paymentFilter,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _paymentFilter != 'all' ? accent : Colors.grey.shade600)),
                    const SizedBox(width: 4),
                    Icon(Icons.unfold_more_rounded, size: 14, color: Colors.grey.shade500),
                  ]),
                ),
              ),
              _VertDivider(isDark: isDark),
              // Date range
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateFrom != null && _dateTo != null
                        ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
                        : null,
                  );
                  if (range != null) {
                    setState(() {
                      _dateFrom = range.start;
                      _dateTo = range.end;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _dateFrom != null ? accent.withValues(alpha: 0.1) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(FluentIcons.calendar_24_regular, size: 16, color: _dateFrom != null ? accent : Colors.grey),
                    const SizedBox(width: 6),
                      Text(
                        _dateFrom != null
                            ? "${DateFormatter.formatShortDate(_dateFrom!)} – ${DateFormatter.formatShortDate(_dateTo!)}"
                            : "Période",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dateFrom != null ? accent : Colors.grey.shade600),
                      ),
                    if (_dateFrom != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() { _dateFrom = null; _dateTo = null; }),
                        child: Icon(Icons.close, size: 14, color: accent),
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── TABLE ──
          salesAsync.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => Expanded(child: Center(child: Text("Erreur : $err"))),
            data: (sales) {
              var filtered = sales.where((s) {
                final q = _searchQuery.toLowerCase();
                final matchQ = q.isEmpty ||
                    (s.clientName ?? 'Passager').toLowerCase().contains(q) ||
                    s.sale.id.toLowerCase().contains(q) ||
                    s.items.any((i) => i.productName.toLowerCase().contains(q));

                bool matchStatus = true;
                if (_statusFilter == 'success') matchStatus = s.sale.status == 'COMPLETED' && !s.sale.isCredit;
                if (_statusFilter == 'credit') matchStatus = s.sale.isCredit && s.sale.status != 'REFUNDED';
                if (_statusFilter == 'refunded') matchStatus = s.sale.status == 'REFUNDED' || s.sale.status == 'PARTIAL_REFUND';

                final matchPayment = _paymentFilter == 'all' || (s.sale.paymentMethod ?? '').toLowerCase().contains(_paymentFilter.toLowerCase());

                bool matchDate = true;
                if (_dateFrom != null && _dateTo != null) {
                  matchDate = s.sale.date.isAfter(_dateFrom!.subtract(const Duration(days: 1))) &&
                      s.sale.date.isBefore(_dateTo!.add(const Duration(days: 1)));
                }

                return matchQ && matchStatus && matchPayment && matchDate;
              }).toList();

              if (filtered.isEmpty) {
                return Expanded(
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(FluentIcons.receipt_24_regular, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Aucune vente correspondante", style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text("Modifiez vos filtres pour voir plus de résultats.", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ]),
                  ),
                );
              }

              // Group sales by date
              final grouped = <String, List<SaleWithDetails>>{};
              for (final s in filtered) {
                final key = DateFormatter.formatFullDate(s.sale.date);
                grouped.putIfAbsent(key, () => []).add(s);
              }

              return Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: grouped.length,
                  itemBuilder: (ctx, gi) {
                    final dateKey = grouped.keys.elementAt(gi);
                    final daySales = grouped[dateKey]!;
                    final dayTotal = daySales.where((s) => s.sale.status != 'REFUNDED').fold(0.0, (p, s) => p + s.sale.totalAmount);

                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Date group header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(dateKey, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
                          ),
                          const SizedBox(width: 10),
                          Text("${daySales.length} ventes", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          const Spacer(),
                          Text(ref.fmt(dayTotal), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: accent)),
                        ]),
                      ),
                      // Sales cards
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: daySales.asMap().entries.map((entry) {
                            final i = entry.key;
                            final sd = entry.value;
                            final sale = sd.sale;
                            final isRefunded = sale.status == 'REFUNDED';
                            final isPartial = sale.status == 'PARTIAL_REFUND';
                            final isCredit = sale.isCredit && !isRefunded;

                            final statusColor = isRefunded
                                ? theme.colorScheme.error
                                : (isPartial ? Colors.orange : (isCredit ? Colors.orange : const Color(0xFF10B981)));
                            final statusLabel = isRefunded ? "Annulé" : (isPartial ? "Retour partiel" : (isCredit ? "Crédit" : "Complété"));
                            final statusIcon = isRefunded
                                ? FluentIcons.arrow_hook_down_left_24_filled
                                : (isCredit ? FluentIcons.people_money_24_regular : FluentIcons.checkmark_circle_24_filled);

                            IconData pmIcon = FluentIcons.money_24_regular;
                            final pm = (sale.paymentMethod ?? '').toLowerCase();
                            if (pm.contains('mobile') || pm.contains('wave') || pm.contains('orange')) pmIcon = FluentIcons.phone_24_regular;
                            if (pm.contains('chèque') || pm.contains('cheque')) pmIcon = FluentIcons.document_24_regular;
                            if (pm.contains('carte') || pm.contains('card')) pmIcon = FluentIcons.payment_24_regular;

                            return Column(children: [
                              if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF3F4F6)),
                              InkWell(
                                onTap: () => _showSaleDetail(context, sd, ref.fmt, theme, isDark),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 14 : 0),
                    bottom: Radius.circular(i == daySales.length - 1 ? 14 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                                    // Time
                                    SizedBox(
                                      width: 50,
                                      child: Text(DateFormatter.formatTime(sale.date),
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                                    ),
                                    // Status icon
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                      child: Icon(statusIcon, color: statusColor, size: 18),
                                    ),
                                    const SizedBox(width: 14),
                                    // Info
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text(sd.clientName ?? 'Client passager', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
                                        ),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(
                                        sd.items.length <= 2
                                            ? sd.items.map((i) => "${DateFormatter.formatQuantity(i.item.quantity)}× ${i.productName}").join(", ")
                                            : "${sd.items.length} articles · ${sd.items.map((i) => i.productName).take(2).join(", ")}...",
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ])),
                                    // Payment method
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2128) : const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(pmIcon, size: 12, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Text(sale.paymentMethod ?? '–', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                      ]),
                                    ),
                                    const SizedBox(width: 16),
                                    // Amount
                                    SizedBox(
                                      width: 110,
                                      child: Text(ref.fmt(sale.totalAmount),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            color: isRefunded ? theme.colorScheme.error : (isDark ? Colors.white : const Color(0xFF1F2937)),
                                            decoration: isRefunded ? TextDecoration.lineThrough : null,
                                          )),
                                    ),
                                    // Actions
                                    const SizedBox(width: 8),
                                    if (!isRefunded)
                                      PopupMenuButton<String>(
                                        tooltip: '',
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        icon: Icon(FluentIcons.more_vertical_24_regular, size: 18, color: Colors.grey.shade500),
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(value: 'detail', child: Row(children: [
                                            Icon(FluentIcons.eye_24_regular, size: 18),
                                            SizedBox(width: 10),
                                            Text("Voir détails"),
                                          ])),
                                          PopupMenuItem(value: 'return', child: Row(children: [
                                            Icon(FluentIcons.arrow_hook_down_left_24_regular, size: 18, color: theme.colorScheme.error),
                                            const SizedBox(width: 10),
                                            Text("Retour / Annulation", style: TextStyle(color: theme.colorScheme.error)),
                                          ])),
                                        ],
                                        onSelected: (v) {
                                          if (v == 'detail') _showSaleDetail(context, sd, ref.fmt, theme, isDark);
                                          if (v == 'return') showDialog(context: context, builder: (_) => ReturnSaleDialog(saleData: sd));
                                        },
                                      )
                                    else
                                      const SizedBox(width: 40),
                                  ]),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ]);
                  },
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }

  void _showSaleDetail(BuildContext context, SaleWithDetails sd, String Function(double) fmt, ThemeData theme, bool isDark) {
    final sale = sd.sale;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 15))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(FluentIcons.receipt_24_filled, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Détails de la vente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  Text("#${sale.id.substring(0, 8).toUpperCase()} · ${DateFormatter.formatDateTime(sale.date)}", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Client
                Row(children: [
                  const Icon(FluentIcons.person_24_regular, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Client : ", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  Text(sd.clientName ?? 'Passager', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  Text(sale.paymentMethod ?? '–', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                // Items
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2128) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                  ),
                  child: Column(children: [
                    ...sd.items.asMap().entries.map((e) {
                      final item = e.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: e.key > 0 ? Border(top: BorderSide(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF0F0F0))) : null,
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(5)),
                            child: Text("×${DateFormatter.formatQuantity(item.item.quantity)}", style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                          Text(fmt(item.item.unitPrice), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          const SizedBox(width: 12),
                          SizedBox(width: 80, child: Text(fmt(item.item.unitPrice * item.item.quantity), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        ]),
                      );
                    }),
                  ]),
                ),
                const SizedBox(height: 16),
                // Total
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("TOTAL", style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.primary, fontSize: 14)),
                    Text(fmt(sale.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: theme.colorScheme.primary)),
                  ]),
                ),
                if (sale.status == 'REFUNDED' || sale.status == 'PARTIAL_REFUND') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text("Remboursé", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text("-${fmt(sale.refundedAmount)}", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w900, fontSize: 16)),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool isDark;

  const _KpiCard({required this.icon, required this.label, required this.value, required this.sub, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181D) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14), overflow: TextOverflow.ellipsis),
            Text(sub, style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterPill({required this.label, required this.isSelected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          )),
        ),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final bool isDark;
  const _VertDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
    );
  }
}
