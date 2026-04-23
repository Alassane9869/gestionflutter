import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
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
import 'package:danaya_plus/core/network/display_launcher_service.dart';
import 'package:danaya_plus/features/assistant/presentation/widgets/assistant_notification_dropdown.dart';
import 'package:danaya_plus/features/assistant/application/assistant_notification_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'dart:async';

final navigationProvider = NotifierProvider<NavigationNotifier, int>(
  NavigationNotifier.new,
);

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setPage(int page, WidgetRef ref) {
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
    // Connect Assistant Actions to Navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assistantProvider.notifier).setActionCallback((action, {payload}) {
        if (action == "navigate" && payload is int) {
          ref.read(navigationProvider.notifier).setPage(payload, ref);
        }
      });
    });
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
                                  onDismiss: () => ref.read(proactiveAlertProvider.notifier).clear(),
                                  onAction: () => ref.read(proactiveAlertProvider.notifier).clear(),
                                ),
                              ),

                            if (ref.watch(shopSettingsProvider).whenOrNull(data: (s) => s.showAssistant) ?? true)
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
        if (!user.canManageHR) return _denied("RH");
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
    final showAssistantInHeader = (shopSettings?.showAssistant ?? true) && !assistantState.isOpen;

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
              if (shopSettings?.logoPath != null)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(shopSettings!.logoPath!)),
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
              if (showAssistantInHeader) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FluentIcons.bot_sparkle_24_filled, color: Colors.blue, size: 24),
                  onPressed: () => ref.read(assistantProvider.notifier).toggleOpen(),
                  tooltip: "IA Danaya+ Pro",
                  splashRadius: 20,
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds, color: Colors.blue.withValues(alpha: 0.3)),
              ],
            ],
          ),
          const SizedBox(width: 16),
          // --- HIDE ADVANCED CONTROLS FOR CASHIERS ---
          if (widget.user.isAdmin || widget.user.isManager) ...[
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
                  if (widget.user.isAdmin || widget.user.isManager) ...[
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
                  ],
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
        color: isDark ? const Color(0xFF16181D) : Colors.white,
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
                    _NavItem(
                      3,
                      "Point de Vente",
                      FluentIcons.cart_20_regular,
                      FluentIcons.cart_20_filled,
                      isCollapsed,
                    ),
                    _NavItem(
                      4,
                      "Historique Ventes",
                      FluentIcons.receipt_20_regular,
                      FluentIcons.receipt_20_filled,
                      isCollapsed,
                    ),
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
                    if (user.canManageHR)
                      _NavItem(
                        19,
                        "Personnel & RH",
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                FluentIcons.sign_out_20_regular,
                color: AppTheme.errorClr,
                size: 16,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    "Déconnexion",
                    maxLines: 1,
                    overflow: TextOverflow.clip,
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

class _NetworkIndicator extends StatelessWidget {
  final NetworkMode mode;
  final bool isReachable;

  const _NetworkIndicator({
    required this.mode,
    required this.isReachable,
  });

  @override
  Widget build(BuildContext context) {
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
