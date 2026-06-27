import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/theme/theme_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_content.dart';
import 'package:danaya_plus/features/inventory/presentation/cashier_dashboard_content.dart';

import 'package:danaya_plus/features/inventory/presentation/product_list_screen.dart';
import 'package:danaya_plus/features/pos/presentation/pos_screen.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';
import 'package:danaya_plus/features/finance/presentation/finance_screen.dart';
import 'package:danaya_plus/features/clients/presentation/clients_screen.dart';
import 'package:danaya_plus/features/srm/presentation/suppliers_screen.dart';
import 'package:danaya_plus/features/settings/presentation/settings_screen.dart';
import 'package:danaya_plus/features/inventory/presentation/stock_movement_screen.dart';
import 'package:danaya_plus/features/pos/presentation/sales_history_screen.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/features/pos/presentation/return_sale_dialog.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/pos/presentation/quotes_screen.dart';
import 'package:danaya_plus/features/reports/presentation/reports_screen.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/finance/presentation/open_session_screen.dart';
import 'package:danaya_plus/features/finance/presentation/close_session_dialog.dart';
import 'package:danaya_plus/features/finance/presentation/session_history_dialog.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/inventory/presentation/warehouses_screen.dart';
import 'package:danaya_plus/features/clients/presentation/client_debt_screen.dart';
import 'package:danaya_plus/features/finance/presentation/expenses_screen.dart';
import 'package:danaya_plus/features/hr/presentation/hr_screen.dart';
import 'package:danaya_plus/features/inventory/presentation/stock_alerts_screen.dart';
import 'package:danaya_plus/features/inventory/presentation/stock_audit_screen.dart';
import 'package:danaya_plus/features/srm/presentation/purchase_screen.dart';
import 'package:danaya_plus/features/auth/presentation/login_screen.dart';
import 'package:danaya_plus/features/assistant/presentation/virtual_assistant_widget.dart';
import 'package:danaya_plus/features/assistant/application/assistant_service.dart';
import 'package:danaya_plus/features/inventory/providers/global_search_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/global_search_overlay.dart';
import 'package:danaya_plus/features/help/presentation/help_screen.dart';
import 'package:danaya_plus/features/assistant/presentation/proactive_alert_overlay.dart';
import 'package:danaya_plus/core/network/network_service.dart';
import 'package:danaya_plus/core/network/cloud_sync_service.dart';
import 'package:danaya_plus/core/network/display_launcher_service.dart';
import 'package:danaya_plus/features/assistant/presentation/widgets/assistant_notification_dropdown.dart';
import 'package:danaya_plus/features/assistant/application/assistant_notification_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'dart:async';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/pos/services/receipt_service.dart';
import 'package:danaya_plus/features/pos/services/invoice_service.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/core/services/sound_service.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/payment_success_overlay.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/sale_doc_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

final navigationProvider = NotifierProvider<NavigationNotifier, int>(
  NavigationNotifier.new,
);

class NavigationNotifier extends Notifier<int> {
  @override
  int build() {
    final user = ref.watch(authServiceProvider).value;
    if (user != null && !user.canViewDashboard) {
      return 3; // POS is the default page for those who can't view the dashboard
    }
    return 0; // Dashboard
  }

  void setPage(int page, WidgetRef ref) {
    final user = ref.read(authServiceProvider).value;
    if (page == 0 && user != null && !user.canViewDashboard) {
      return;
    }
    state = page;
    _updateAssistantContext(page, ref);
  }

  void _updateAssistantContext(int index, WidgetRef ref) {
    final notifier = ref.read(assistantProvider.notifier);
    switch (index) {
      case 0: notifier.setContext(AssistantContext.dashboard); break;
      case 1: 
      case 2: 
      case 11:
      case 14:
      case 15: notifier.setContext(AssistantContext.inventory); break;
      case 3: notifier.setContext(AssistantContext.pos); break;
      case 4: 
      case 10: notifier.setContext(AssistantContext.pos); break; // Shared sales context
      case 5: notifier.setContext(AssistantContext.reports); break;
      case 6: 
      case 13: notifier.setContext(AssistantContext.finance); break;
      case 7: 
      case 12: notifier.setContext(AssistantContext.clients); break;
      case 8: 
      case 16: notifier.setContext(AssistantContext.suppliers); break;
      case 9: notifier.setContext(AssistantContext.settings); break;
      case 19: notifier.setContext(AssistantContext.general); break; // HR Context (General for now)
      case 18: notifier.setContext(AssistantContext.general); break; // Help Center
      default: notifier.setContext(AssistantContext.general);
    }
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isSidebarCollapsed = false;
  int _sessionRetryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Connect Assistant Actions to Navigation and Autonomous Checkout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assistantProvider.notifier).setActionCallback((action, {payload}) {
        if (action == "navigate" && payload is int) {
          ref.read(navigationProvider.notifier).setPage(payload, ref);
        } else if (action == "checkout") {
          _executeAutonomousCheckout(payload);
        } else if (action == "send_client_message" && payload is Map) {
          _handleSendClientMessage(payload);
        } else if (action == "manage_sale" && payload is Map) {
          _handleManageSale(payload);
        }
      });
    });
  }

  Future<void> _handleSendClientMessage(Map payload) async {
    final method = payload['method'] as String;
    final phone = payload['phone'] as String;
    final email = payload['email'] as String;
    final name = payload['name'] as String;
    final credit = (payload['credit'] as num?)?.toDouble() ?? 0.0;

    if (method == 'call') {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final uri = Uri.parse("tel:$cleanPhone");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } else if (method == 'whatsapp') {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final settings = ref.read(shopSettingsProvider).value;
      final shopName = settings?.name ?? "Danaya+";
      
      String message = "Bonjour $name, c'est l'établissement $shopName. ";
      if (credit > 0) {
        final formattedCredit = DateFormatter.formatCurrency(
          credit,
          settings?.currency ?? 'FCFA',
          removeDecimals: settings?.removeDecimals ?? true,
        );
        message += "Nous vous contactons pour vous rappeler votre solde restant de $formattedCredit. Merci de régulariser votre situation dès que possible. Bonne journée !";
      } else {
        message += "Nous espérons que vous allez bien. Merci pour votre fidélité !";
      }
      
      final whatsappUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } else if (method == 'email') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => EmailComposeDialog(email: email, clientName: name),
        );
      }
    }
  }

  void _handleManageSale(Map payload) {
    final saleId = payload['saleId'] as String;
    final action = payload['action'] as String;
    final user = ref.read(authServiceProvider).value;

    // Navigation
    ref.read(navigationProvider.notifier).setPage(4, ref);

    // Defer to allow navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salesAsync = ref.read(salesHistoryProvider);
      salesAsync.whenData((sales) {
        try {
          final sd = sales.firstWhere((s) => s.sale.id == saleId);
          if (!mounted) return;

          if (action == 'show_detail') {
            _showSaleDetail(context, sd, ref.fmt, Theme.of(context), Theme.of(context).brightness == Brightness.dark);
          } else if (action == 'print_ticket') {
            _printSaleDocument(context, sd, 'ticket');
          } else if (action == 'print_invoice') {
            _printSaleDocument(context, sd, 'invoice');
          } else if (action == 'refund') {
            if (user == null || !user.canRefund) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Permission refusée : Retour/Annulation non autorisé."),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            showDialog(
              context: context,
              builder: (_) => ReturnSaleDialog(saleData: sd),
            );
          }
        } catch (e) {
          ref.invalidate(salesHistoryProvider);
        }
      });
    });
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(FluentIcons.person_24_regular, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text("Client : ", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  Text(sd.clientName ?? 'Passager', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  Text(sale.paymentMethod ?? '–', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
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
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("Remboursé", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text("-${fmt(sale.refundedAmount)}", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w900, fontSize: 16)),
                      ]),
                      if (sale.refundedAt != null || sd.refundedByUserName != null) ...[
                        const SizedBox(height: 8),
                        Divider(height: 1, color: theme.colorScheme.error.withValues(alpha: 0.15)),
                        const SizedBox(height: 8),
                        if (sale.refundedAt != null)
                          Row(children: [
                            Icon(FluentIcons.clock_24_regular, size: 14, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Text("Annulé le : ", style: TextStyle(color: theme.colorScheme.error.withValues(alpha: 0.7), fontSize: 11)),
                            Text(DateFormatter.formatDateTime(sale.refundedAt!), style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700, fontSize: 11)),
                          ]),
                        if (sd.refundedByUserName != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(FluentIcons.person_24_regular, size: 14, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Text("Par : ", style: TextStyle(color: theme.colorScheme.error.withValues(alpha: 0.7), fontSize: 11)),
                            Text(sd.refundedByUserName!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700, fontSize: 11)),
                          ]),
                        ],
                      ],
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

  void _printSaleDocument(BuildContext context, SaleWithDetails sd, String docType) async {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) return;

    final user = ref.read(authServiceProvider).value;
    final clients = ref.read(clientListProvider).value ?? [];
    final client = clients.firstWhere(
      (c) => c.id == sd.sale.clientId,
      orElse: () => const Client(id: '', name: ''),
    );

    final rItems = sd.items.map((i) => ReceiptItem(
      name: i.productName,
      qty: i.item.quantity,
      unitPrice: i.item.unitPrice,
      discountPercent: i.item.discountPercent,
    )).toList();

    final iItems = sd.items.map((i) => InvoiceItem(
      name: i.productName,
      qty: i.item.quantity,
      unitPrice: i.item.unitPrice,
      discountPercent: i.item.discountPercent,
    )).toList();

    final double change = (sd.sale.amountPaid - sd.sale.totalAmount).clamp(0.0, double.infinity);
    final double subtotal = sd.sale.totalAmount + sd.sale.discountAmount;

    final rd = ReceiptData(
      saleId: sd.sale.id,
      date: sd.sale.date,
      items: rItems,
      totalAmount: sd.sale.totalAmount,
      amountPaid: sd.sale.amountPaid,
      change: change,
      isCredit: sd.sale.isCredit,
      clientName: sd.clientName,
      clientPhone: client.phone,
      cashierName: sd.userName ?? user?.fullName ?? 'Caissier',
      settings: settings,
      paymentMethod: sd.sale.paymentMethod,
      discountAmount: sd.sale.discountAmount,
    );

    final id = InvoiceData(
      invoiceNumber: "INV-${sd.sale.id.substring(0, 8).toUpperCase()}",
      date: sd.sale.date,
      items: iItems,
      subtotal: subtotal,
      totalAmount: sd.sale.totalAmount,
      amountPaid: sd.sale.amountPaid,
      change: change,
      isCredit: sd.sale.isCredit,
      clientName: sd.clientName,
      clientPhone: client.phone,
      clientEmail: client.email,
      cashierName: sd.userName ?? user?.fullName ?? 'Caissier',
      settings: settings,
      saleId: sd.sale.id,
      paymentMethod: sd.sale.paymentMethod,
      discountAmount: sd.sale.discountAmount,
      taxRate: settings.useTax ? (settings.taxRate / 100) : 0,
    );

    showDialog(
      context: context,
      builder: (_) => SaleDocViewer(
        receiptData: rd,
        invoiceData: id,
        initialType: docType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);
    final theme = Theme.of(context);

    return sessionAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chargement de la session...',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      error: (e, st) {
        // Auto-retry silencieux (max 3 fois) avant d'afficher l'erreur
        if (_sessionRetryCount < _maxRetries) {
          _sessionRetryCount++;
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) ref.invalidate(activeSessionProvider);
          });
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48, height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tentative de reconnexion ($_sessionRetryCount/$_maxRetries)...',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.error_circle_24_regular, color: theme.colorScheme.error, size: 48),
                const SizedBox(height: 16),
                Text('Erreur de Session', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    _sessionRetryCount = 0;
                    ref.invalidate(activeSessionProvider);
                  },
                  icon: const Icon(FluentIcons.arrow_sync_24_regular, size: 18),
                  label: const Text('RÉESSAYER', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        );
      },
      data: (activeSession) {
        _sessionRetryCount = 0; // Réinitialiser le compteur de retries sur succès
        final user = ref.watch(authServiceProvider).value;
        if (user == null) return const LoginScreen();

        final isImpersonating = ref.watch(authServiceProvider.notifier).isImpersonating;

        if (activeSession == null && !isImpersonating) {
          return const OpenSessionScreen();
        }

        final isPosFullScreen = ref.watch(posFullScreenProvider) && ref.watch(navigationProvider) == 3;

        return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _logout(); // Trigger the logout guard logic
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              // ── IMPERSONATION BANNER ──
              if (ref.watch(authServiceProvider.notifier).isImpersonating && !isPosFullScreen)
                const _ImpersonationBanner(),

              // ── TOP NAVIGATION BAR (Enterprise Header) ──
              if (!isPosFullScreen)
                _TopNavBar(
                  isSidebarCollapsed: _isSidebarCollapsed,
                  activeSession: activeSession,
                  user: user,
                  onToggleSidebar: () =>
                      setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                  onLogout: _logout,
                ),

              // ── MAIN BODY ROW ──
              Expanded(
                child: Row(
                  children: [
                    // Collapsible Sidebar (Isolated)
                    if (!isPosFullScreen)
                      _Sidebar(
                        isCollapsed: _isSidebarCollapsed,
                        user: user,
                        onLogout: _logout,
                      ),

                    // Content Area (Isolated)
                    Expanded(
                      child: RepaintBoundary(
                        child: Container(
                          color: theme.scaffoldBackgroundColor,
                        child: Stack(
                          children: [
                            _buildBody(ref.watch(navigationProvider)),
                            
                            // PROACTIVE ALERT OVERLAY
                            if (ref.watch(proactiveAlertProvider) != null)
                              Positioned(
                                top: 0, 
                                left: 0, 
                                right: 0, 
                                child: ProactiveAlertOverlay(
                                  title: ref.watch(proactiveAlertProvider)!.title,
                                  message: ref.watch(proactiveAlertProvider)!.message,
                                  level: ref.watch(proactiveAlertProvider)!.detectedLevel,
                                  onDismiss: () => ref.read(proactiveAlertProvider.notifier).clear(),
                                  onAction: () => ref.read(proactiveAlertProvider.notifier).clear(),
                                ),
                              ),

                            if ((ref.watch(shopSettingsProvider).whenOrNull(data: (s) => s.showAssistant) ?? false) &&
                                user.canUseAi)
                              const VirtualAssistantWidget(),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Future<void> _executeAutonomousCheckout(dynamic payload) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "⚠️ **Encaissement impossible** : Le panier est vide."
      );
      return;
    }

    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) return;

    final user = ref.read(authServiceProvider).value;
    if (user == null || !user.canSell) return;

    Map<String, dynamic>? params = payload is Map<String, dynamic> ? payload : null;
    final paymentMethod = params?['payment_method'] as String? ?? 'CASH';
    
    final isCredit = params?['is_credit'] as bool? ?? false;
    final dueDateStr = params?['due_date'] as String?;
    final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
    final documentType = params?['document_type'] as String?;

    final cartSnapshot = List<PosCartItem>.from(cart);
    final subtotal = cartSnapshot.fold(0.0, (s, i) => s + i.lineTotal);
    
    final amountPaid = params?['amount_paid'] != null 
        ? (params?['amount_paid'] as num).toDouble() 
        : (isCredit ? 0.0 : subtotal);

    final treasury = ref.read(treasuryProvider.notifier);
    final accountType = paymentMethod == 'CASH' ? AccountType.CASH : AccountType.BANK;
    final defaultAccount = await treasury.getDefaultAccount(accountType);
    final accountId = defaultAccount?.id;

    // Paiements mixtes
    List<Map<String, dynamic>>? multiPayments;
    final multiPaymentsRaw = params?['multi_payments'] as List?;
    if (multiPaymentsRaw != null) {
      multiPayments = [];
      for (final p in multiPaymentsRaw) {
        if (p is Map) {
          final method = p['method'] as String? ?? 'CASH';
          final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
          final pAccountType = method == 'CASH' ? AccountType.CASH : AccountType.BANK;
          final pAccount = await treasury.getDefaultAccount(pAccountType);
          
          multiPayments.add({
            'method': method,
            'amount': amount,
            'accountId': pAccount?.id,
          });
        }
      }
    }

    final rawCart = cartSnapshot.map((i) => {
      'product_id': i.productId,
      'name': i.name,
      'price': i.unitPrice,
      'qty': i.qty,
      'discount_percent': i.discountPercent,
    }).toList();

    try {
      final saleId = await ref.read(posProvider).checkout(
        cart: rawCart,
        totalAmount: subtotal,
        amountPaid: amountPaid,
        clientId: ref.read(selectedClientIdProvider),
        accountId: accountId,
        paymentMethod: paymentMethod,
        isCredit: isCredit,
        dueDate: dueDate,
        multiPayments: multiPayments,
        discountAmount: 0.0,
      );

      if (saleId != null) {
        final rItems = cartSnapshot.map((i) => ReceiptItem(
          name: i.name,
          qty: i.qty,
          unitPrice: i.unitPrice,
          discountPercent: i.discountPercent,
        )).toList();

        final iItems = cartSnapshot.map((i) => InvoiceItem(
          name: i.name,
          qty: i.qty,
          unitPrice: i.unitPrice,
          discountPercent: i.discountPercent,
        )).toList();

        final selectedClientId = ref.read(selectedClientIdProvider);
        final clients = ref.read(clientListProvider).value ?? [];
        final client = selectedClientId != null 
            ? clients.where((c) => c.id == selectedClientId).firstOrNull 
            : null;

        final rd = ReceiptData(
          saleId: saleId,
          date: DateTime.now(),
          items: rItems,
          totalAmount: subtotal,
          amountPaid: amountPaid,
          change: (amountPaid - subtotal).clamp(0.0, double.infinity),
          isCredit: isCredit,
          clientName: client?.name,
          clientPhone: client?.phone,
          cashierName: user.fullName,
          settings: settings,
          paymentMethod: paymentMethod,
          discountAmount: 0.0,
          loyaltyPointsGained: (settings.loyaltyEnabled && client != null) 
              ? (subtotal / settings.pointsPerAmount).floor() 
              : 0,
          loyaltyPointsBalance: (settings.loyaltyEnabled && client != null)
              ? (client.loyaltyPoints + (subtotal / settings.pointsPerAmount).floor())
              : 0,
        );

        final id = InvoiceData(
          invoiceNumber: "INV-${saleId.substring(0, 8).toUpperCase()}",
          date: DateTime.now(),
          items: iItems,
          subtotal: subtotal,
          totalAmount: subtotal,
          amountPaid: amountPaid,
          change: (amountPaid - subtotal).clamp(0.0, double.infinity),
          isCredit: isCredit,
          clientName: client?.name,
          clientPhone: client?.phone,
          clientEmail: client?.email,
          cashierName: user.fullName,
          settings: settings,
          saleId: saleId,
          paymentMethod: paymentMethod,
          discountAmount: 0.0,
          taxRate: settings.useTax ? (settings.taxRate / 100) : 0,
          loyaltyPointsGained: (settings.loyaltyEnabled && client != null)
              ? (subtotal / settings.pointsPerAmount).floor()
              : 0,
          loyaltyPointsBalance: (settings.loyaltyEnabled && client != null)
              ? (client.loyaltyPoints + (subtotal / settings.pointsPerAmount).floor())
              : 0,
        );

        try {
          if (settings.autoPrintTicket) {
            await ReceiptService.print(rd, settings.defaultReceipt);
          }
        } catch (e) {
          debugPrint("❌ Impression automatique échouée: $e");
        }

        ref.read(soundServiceProvider).playSaleSuccess();
        ref.read(cartProvider.notifier).clear();
        ref.read(selectedClientIdProvider.notifier).setClient(null);

        if (mounted) {
          if (documentType != null) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => SaleDocViewer(
                receiptData: rd,
                invoiceData: id,
                initialType: documentType == 'invoice' ? 'invoice' : 'ticket',
              ),
            );
          } else {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => PaymentSuccessOverlay(
                receiptData: rd,
                invoiceData: id,
              ),
            );
          }
        }
      }
    } catch (e) {
      ref.read(soundServiceProvider).playScanError();
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "❌ **Erreur lors de la validation** : $e"
      );
    }
  }

  void _logout() async {
    final authNotif = ref.read(authServiceProvider.notifier);
    if (authNotif.isImpersonating) {
      authNotif.stopImpersonation();
      return;
    }

    final activeSession = ref.read(activeSessionProvider).value;
    if (activeSession != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text("Déconnexion Bloquée"),
            ],
          ),
          content: const Text(
            "Une session de caisse est encore ouverte.\n\nVeuillez fermer la caisse avant de vous déconnecter pour garantir l'intégrité de l'audit.",
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("COMPRIS"),
            ),
          ],
        ),
      );
      return;
    }
    ref.read(authServiceProvider.notifier).logout();
  }

  Widget _buildBody(int index) {
    final user = ref.watch(authServiceProvider).value;
    if (user == null) return const SizedBox.shrink();

    switch (index) {
      case 0:
        if (!user.canViewDashboard) return _denied("Tableau de Bord");
        if (user.isCashier) {
          return const CashierDashboardContent();
        }
        return const DashboardContent();
      case 1:
        if (!user.canManageInventory) return _denied("Inventaire");
        return const ProductListScreen();
      case 2:
        if (!user.canManageInventory) return _denied("Mouvements");
        return const StockMovementScreen();
      case 3:
        if (!user.canSell) return _denied("Point de Vente");
        return const PosScreen();
      case 4:
        if (!user.canSell) return _denied("Historique");
        return const SalesHistoryScreen();
      case 5:
        if (!user.canViewReports) return _denied("Rapports");
        return const ReportsScreen();
      case 6:
        if (!user.canAccessFinance) return _denied("Trésorerie");
        return const FinanceScreen();
      case 7:
        if (!user.canManageCustomers) return _denied("Clients");
        return const ClientsScreen();
      case 8:
        if (!user.canManageSuppliers) return _denied("Fournisseurs");
        return const SuppliersScreen();
      case 9:
        if (!user.canAccessSettings) return _denied("Paramètres");
        return const SettingsScreen();
      case 10:
        if (!user.canSell) return _denied("Devis");
        return const QuotesScreen();
      case 11:
        if (!user.canManageInventory) return _denied("Entrepôts");
        return const WarehousesScreen();
      case 12:
        if (!user.canManageCustomers) return _denied("Dettes");
        return const ClientDebtScreen();
      case 13:
        if (!user.canManageExpenses) return _denied("Dépenses");
        return const ExpensesScreen();
      case 14:
        if (!user.canManageInventory) return _denied("Alertes");
        return const StockAlertsScreen();
      case 15:
        if (!user.canManageInventory) return _denied("Inventaire Physique");
        return const StockAuditScreen();
      case 16:
        if (!user.canManageSuppliers) return _denied("Achats");
        return const PurchaseScreen();
      case 18:
        return const HelpScreen();
      case 19:
        return const HrScreen();
      default:
        return const DashboardContent();
    }
  }

  Widget _denied(String module) {
    return AccessDeniedScreen(
      message: "Accès au module $module restreint",
      subtitle: "Votre rôle ne vous octroie pas les permissions nécessaires.",
    );
  }
}

class _TopNavBar extends ConsumerStatefulWidget {
  final bool isSidebarCollapsed;
  final dynamic activeSession;
  final User user;
  final VoidCallback onToggleSidebar;
  final VoidCallback onLogout;

  const _TopNavBar({
    required this.isSidebarCollapsed,
    required this.activeSession,
    required this.user,
    required this.onToggleSidebar,
    required this.onLogout,
  });

  @override
  ConsumerState<_TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends ConsumerState<_TopNavBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _botifiLink = LayerLink();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _botifiOverlay;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _removeBotifiOverlay();
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    // On n'enlève plus l'overlay ici, car TapRegion s'en occupe mieux
    if (_focusNode.hasFocus && _searchController.text.isNotEmpty) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: TapRegion(
            groupId: 'global_search',
            child: GlobalSearchOverlay(
              onResultClicked: () {
                _removeOverlay();
                _searchController.clear();
                _focusNode.unfocus();
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showBotifiOverlay() {
    _removeBotifiOverlay();
    final overlay = Overlay.of(context);
    
    _botifiOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 380,
        child: CompositedTransformFollower(
          link: _botifiLink,
          showWhenUnlinked: false,
          offset: const Offset(-340, 44),
          child: TapRegion(
            groupId: 'botifi_dropdown',
            onTapOutside: (_) => _removeBotifiOverlay(),
            child: AssistantNotificationDropdown(
              onAction: () => _removeBotifiOverlay(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_botifiOverlay!);
  }

  void _removeBotifiOverlay() {
    _botifiOverlay?.remove();
    _botifiOverlay = null;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        ref.read(globalSearchProvider.notifier).search(query);
        if (_overlayEntry == null) _showOverlay();
      } else {
        ref.read(globalSearchProvider.notifier).clear();
        _removeOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shopSettings = ref.watch(shopSettingsProvider).value;
    final assistantState = ref.watch(assistantProvider);
    final unreadCount = ref.watch(assistantNotificationProvider).where((n) => !n.isRead).length;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shopSettings?.logoPath != null && File(shopSettings!.logoPath!).existsSync())
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(shopSettings.logoPath!)),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else
                Icon(
                  FluentIcons.data_bar_vertical_24_filled,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  (shopSettings?.name ?? 'Danaya+').toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  FluentIcons.line_horizontal_3_20_regular,
                  color: theme.iconTheme.color,
                ),
                onPressed: widget.onToggleSidebar,
                tooltip: 'Afficher/Masquer le menu',
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(width: 16),
          // --- HIDE ADVANCED CONTROLS FOR CASHIERS ---
          if (widget.user.canViewGlobalSalesHistory || widget.user.canManageInventory) ...[
            Flexible(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TapRegion(
                      groupId: 'global_search',
                      onTapOutside: (_) => _removeOverlay(),
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Rechercher partout...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                          prefixIcon: Icon(
                            FluentIcons.search_20_regular,
                            size: 18,
                            color: isDark
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                          ),
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(FluentIcons.dismiss_16_regular, size: 14),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                  _focusNode.unfocus();
                                },
                              )
                            : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
            const SizedBox(width: 16),
          ] else ...[
             const SizedBox(width: 16),
          ],
          // --- INDICATEUR RÉSEAU ---
          if (shopSettings != null && shopSettings.networkMode != NetworkMode.solo) ...[
            _NetworkIndicator(
              mode: shopSettings.networkMode,
              isReachable: ref.watch(serverReachabilityProvider),
            ),
            const SizedBox(width: 12),
          ],
          // --- GROUP 1: Cash Operations (Admin/Manager only) ---
          if (!ref.watch(authServiceProvider.notifier).isImpersonating)
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.of(context).size.width;
              final showLabels = screenWidth > 1200;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showLabels)
                            FilledButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => CloseSessionDialog(session: widget.activeSession),
                              ),
                              icon: const Icon(FluentIcons.lock_closed_20_regular, size: 16),
                              label: const Text("Fermer Caisse", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.errorClr.withValues(alpha: 0.1),
                                foregroundColor: AppTheme.errorClr,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          else
                            IconButton(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => CloseSessionDialog(session: widget.activeSession),
                              ),
                              icon: const Icon(FluentIcons.lock_closed_20_regular, size: 18, color: AppTheme.errorClr),
                              tooltip: "Fermer Caisse",
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(6),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.errorClr.withValues(alpha: 0.08),
                              ),
                            ),
                          const SizedBox(width: 4),
                          if (widget.user.isAdmin || widget.user.isManager)
                            IconButton(
                              onPressed: () => showDialog(context: context, builder: (_) => const SessionHistoryDialog()),
                              icon: Icon(FluentIcons.history_20_regular, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              tooltip: "Historique Sessions",
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(6),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  // --- GROUP 2: Tools (Notifications + Afficheur) ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shopSettings?.showAssistant ?? false) ...[
                          IconButton(
                            icon: Icon(
                              FluentIcons.bot_sparkle_20_filled,
                              size: 18,
                              color: assistantState.isOpen ? Colors.blue : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                            onPressed: () {
                              debugPrint('[DashboardScreen] Assistant button clicked. Current state isOpen: ${assistantState.isOpen}');
                              ref.read(assistantProvider.notifier).toggleOpen();
                            },
                            tooltip: "Danaya Copilot (IA Chat)",
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: const EdgeInsets.all(6),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (widget.user.isAdmin || widget.user.isManager)
                          CompositedTransformTarget(
                            link: _botifiLink,
                            child: Badge(
                              label: Text(unreadCount.toString()),
                              isLabelVisible: unreadCount > 0,
                              backgroundColor: Colors.redAccent,
                              child: IconButton(
                                icon: Icon(FluentIcons.alert_20_regular, size: 18, color: unreadCount > 0 ? Colors.blue : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                onPressed: _showBotifiOverlay,
                                tooltip: "Botifi - IA Notifications",
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: const EdgeInsets.all(6),
                              ),
                            ),
                          ),
                        if (shopSettings != null) ...[
                          if (widget.user.isAdmin || widget.user.isManager)
                            const SizedBox(width: 2),
                          if (showLabels)
                            FilledButton.icon(
                              onPressed: () async {
                                final port = shopSettings.serverPort;
                                await DisplayLauncherService.launchCustomerDisplay(port);
                              },
                              icon: const Icon(FluentIcons.desktop_mac_20_regular, size: 16),
                              label: const Text("Afficheur Client", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.08),
                                foregroundColor: theme.colorScheme.tertiary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          else
                            IconButton(
                              onPressed: () async {
                                final port = shopSettings.serverPort;
                                await DisplayLauncherService.launchCustomerDisplay(port);
                              },
                              icon: Icon(FluentIcons.desktop_mac_20_regular, size: 18, color: theme.colorScheme.tertiary),
                              tooltip: "Afficheur Client",
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(6),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Spacer pushes profile to the far right corner
          const Spacer(),
          // --- GROUP 3: User Profile & Logout (far right) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.13),
                  child: Text(
                    widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : "U",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (MediaQuery.of(context).size.width > 1000) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.user.username,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.successClr.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.user.role.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppTheme.successClr,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  width: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(isDark ? FluentIcons.weather_sunny_20_regular : FluentIcons.weather_moon_20_regular, size: 16),
                  onPressed: () {
                    ref.read(themeNotifierProvider.notifier).setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                  },
                  tooltip: 'Changer le thème',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(FluentIcons.sign_out_20_regular, size: 16, color: AppTheme.errorClr),
                  onPressed: widget.onLogout,
                  tooltip: 'Déconnexion',
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: const EdgeInsets.all(4),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.errorClr.withValues(alpha: 0.06),
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

class _Sidebar extends ConsumerWidget {
  final bool isCollapsed;
  final User user;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.isCollapsed,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: isCollapsed ? 52 : 180,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 2 : 8),
              children: [
                // ── SECTION 1 : GÉNÉRAL ──────────────────────────
                _SidebarSection(
                  title: "GÉNÉRAL",
                  isCollapsed: isCollapsed,
                  children: [
                    if (user.canViewDashboard)
                      _NavItem(
                        0,
                        "Tableau de Bord",
                        FluentIcons.home_20_regular,
                        FluentIcons.home_20_filled,
                        isCollapsed,
                      ),
                  ],
                ),

                // ── SECTION 2 : VENTES ───────────────────────────
                _SidebarSection(
                  title: "VENTES",
                  isCollapsed: isCollapsed,
                  children: [
                    if (user.canSell)
                      _NavItem(
                        3,
                        "Point de Vente",
                        FluentIcons.cart_20_regular,
                        FluentIcons.cart_20_filled,
                        isCollapsed,
                      ),
                    if (user.canSell)
                      _NavItem(
                        4,
                        "Historique Ventes",
                        FluentIcons.receipt_20_regular,
                        FluentIcons.receipt_20_filled,
                        isCollapsed,
                      ),
                    if (user.canSell)
                      _NavItem(
                        10,
                        "Devis / Proformas",
                        FluentIcons.document_pdf_20_regular,
                        FluentIcons.document_pdf_20_filled,
                        isCollapsed,
                      ),
                  ],
                ),

                // ── SECTION 3 : INVENTAIRE ───────────────────────
                _SidebarSection(
                  title: "INVENTAIRE",
                  isCollapsed: isCollapsed,
                  children: [
                    if (user.canManageInventory)
                      _NavItem(
                        1,
                        "Produits",
                        FluentIcons.box_20_regular,
                        FluentIcons.box_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageInventory)
                      _NavItem(
                        2,
                        "Mouvements Stock",
                        FluentIcons.history_20_regular,
                        FluentIcons.history_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageInventory)
                      _NavItem(
                        14,
                        "Alertes Stock",
                        FluentIcons.alert_20_regular,
                        FluentIcons.alert_20_filled,
                        isCollapsed,
                        badgeCount: ref
                            .watch(stockStatsProvider)
                            .criticalStockCount,
                      ),
                    if (user.canManageInventory)
                      _NavItem(
                        15,
                        "Inventaire Physique",
                        FluentIcons.clipboard_search_20_regular,
                        FluentIcons.clipboard_search_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageInventory)
                      _NavItem(
                        11,
                        "Entrepôts",
                        FluentIcons.building_multiple_20_regular,
                        FluentIcons.building_multiple_20_filled,
                        isCollapsed,
                      ),
                  ],
                ),

                // ── SECTION 4 : FINANCES ─────────────────────────
                _SidebarSection(
                  title: "FINANCES",
                  isCollapsed: isCollapsed,
                  children: [
                    if (user.canAccessFinance)
                      _NavItem(
                        6,
                        "Trésorerie",
                        FluentIcons.wallet_20_regular,
                        FluentIcons.wallet_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageExpenses)
                      _NavItem(
                        13,
                        "Dépenses",
                        FluentIcons.money_hand_20_regular,
                        FluentIcons.money_hand_20_filled,
                        isCollapsed,
                      ),
                    if (user.canAccessReports)
                      _NavItem(
                        5,
                        "Rapports & Stats",
                        FluentIcons.data_bar_vertical_20_regular,
                        FluentIcons.data_bar_vertical_20_filled,
                        isCollapsed,
                      ),
                  ],
                ),

                // ── SECTION 5 : PARTENAIRES ──────────────────────
                _SidebarSection(
                  title: "PARTENAIRES",
                  isCollapsed: isCollapsed,
                  children: [
                    if (user.canManageCustomers)
                      _NavItem(
                        7,
                        "Clients",
                        FluentIcons.people_20_regular,
                        FluentIcons.people_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageCustomers)
                      _NavItem(
                        12,
                        "Dettes Clients",
                        FluentIcons.person_money_20_regular,
                        FluentIcons.person_money_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageSuppliers)
                      _NavItem(
                        8,
                        "Fournisseurs",
                        FluentIcons.building_20_regular,
                        FluentIcons.building_20_filled,
                        isCollapsed,
                      ),
                    if (user.canManageSuppliers)
                      _NavItem(
                        16,
                        "Achats (SRM)",
                        FluentIcons.cart_20_regular,
                        FluentIcons.cart_20_filled,
                        isCollapsed,
                      ),
                  ],
                ),

                // ── SECTION 6 : ADMINISTRATION ───────────────────
                _SidebarSection(
                  title: "ADMINISTRATION",
                  isCollapsed: isCollapsed,
                  children: [
                    _NavItem(
                      19,
                      user.canManageHR ? "Personnel & RH" : "Mon Espace RH",
                      FluentIcons.people_community_24_regular,
                      FluentIcons.people_community_24_filled,
                      isCollapsed,
                    ),
                    if (user.canAccessSettings)
                      _NavItem(
                        9,
                        "Paramètres",
                        FluentIcons.settings_20_regular,
                        FluentIcons.settings_20_filled,
                        isCollapsed,
                      ),
                    if (user.isAdmin || user.isManager)
                      _NavItem(
                        18,
                        "Aide & Support",
                        FluentIcons.question_circle_20_regular,
                        FluentIcons.question_circle_20_filled,
                        isCollapsed,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(indent: 8, endIndent: 8),
          _LogoutItem(isCollapsed: isCollapsed, onLogout: onLogout),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isCollapsed;

  const _SidebarSection({
    required this.title,
    required this.children,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCollapsed)
          Padding(
            padding: EdgeInsets.fromLTRB(isCollapsed ? 0 : 12, 12, 12, 4),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ...children,
        const SizedBox(height: 4),
      ],
    );
  }
}

class _NavItem extends ConsumerWidget {
  final int index;
  final String title;
  final IconData iconRegular;
  final IconData iconFilled;
  final bool isCollapsed;
  final int badgeCount;

  const _NavItem(
    this.index,
    this.title,
    this.iconRegular,
    this.iconFilled,
    this.isCollapsed, {
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedIndex = ref.watch(navigationProvider);
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => ref.read(navigationProvider.notifier).setPage(index, ref),
        borderRadius: BorderRadius.circular(12),
        hoverColor: isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : theme.colorScheme.primary.withValues(alpha: 0.03),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.primary.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        child: ClipRect(
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                isSelected ? iconFilled : iconRegular,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280)),
                size: 16,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                      fontSize: 12,
                      color: isSelected
                          ? (isDark ? Colors.white : theme.colorScheme.primary)
                          : (isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorClr,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorClr.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _LogoutItem extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onLogout;

  const _LogoutItem({required this.isCollapsed, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 4 : 8,
        vertical: 4,
      ),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTheme.errorClr.withValues(alpha: 0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 8,
            vertical: 6,
          ),
          child: ClipRect(
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                isCollapsed ? FluentIcons.sign_out_20_filled : FluentIcons.sign_out_20_regular,
                color: AppTheme.errorClr,
                size: 16,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    "Déconnexion",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.errorClr,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _NetworkIndicator extends ConsumerWidget {
  final NetworkMode mode;
  final bool isReachable;

  const _NetworkIndicator({
    required this.mode,
    required this.isReachable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mode == NetworkMode.cloud) {
      final cloudStatus = ref.watch(cloudSyncStatusProvider);
      final isSyncing = cloudStatus.state == CloudSyncState.syncing;
      final isError = cloudStatus.state == CloudSyncState.error;
      
      final color = isError ? AppTheme.errorClr : AppTheme.successClr;
      final icon = isSyncing 
          ? FluentIcons.cloud_sync_20_filled 
          : (isError ? FluentIcons.cloud_sync_16_regular : FluentIcons.cloud_24_filled);
      final label = "CLOUD";

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
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

    final isServer = mode == NetworkMode.server;
    final color = isServer ? AppTheme.successClr : (isReachable ? AppTheme.successClr : AppTheme.errorClr);
    final icon = isServer ? FluentIcons.server_20_filled : (isReachable ? FluentIcons.wifi_1_24_filled : FluentIcons.wifi_off_24_regular);
    final label = isServer ? "SERVEUR" : (isReachable ? "CONNECTÉ" : "DÉCONNECTÉ");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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
}

class _ImpersonationBanner extends ConsumerWidget {
  const _ImpersonationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider.notifier);
    final currentUser = ref.watch(authServiceProvider).value;
    final admin = auth.originalAdmin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)], // Vibrant Orange
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.incognito_24_regular, color: Colors.white, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                children: [
                   const TextSpan(text: "MODE ADMINISTRATEUR : Vous agissez en tant que "),
                  TextSpan(
                    text: currentUser?.username ?? "Utilisateur",
                    style: const TextStyle(fontWeight: FontWeight.w900, decoration: TextDecoration.underline),
                  ),
                  TextSpan(text: " (Session de ${admin?.username ?? 'Admin'})"),
                ],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => auth.stopImpersonation(),
            icon: const Icon(FluentIcons.sign_out_20_regular, size: 16),
            label: const Text("QUITTER LE MODE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
