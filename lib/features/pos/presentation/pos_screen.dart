import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/assistant/application/nlp_engine.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:uuid/uuid.dart';

import 'package:danaya_plus/features/pos/providers/pos_providers.dart';

import 'package:danaya_plus/features/pos/services/receipt_service.dart';
import 'package:danaya_plus/features/pos/services/invoice_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/payment_success_overlay.dart';

import 'package:danaya_plus/core/widgets/glass_widgets.dart';
import 'package:danaya_plus/core/services/sound_service.dart';
import 'package:danaya_plus/core/utils/image_resolver.dart';
import 'package:window_manager/window_manager.dart';
import 'package:danaya_plus/core/widgets/pin_pad_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// POS Screen
// ─────────────────────────────────────────────────────────────────────────────

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isCreditSale = false;
  // _selectedClientId is now managed via selectedClientIdProvider
  double _discount = 0.0; // DA absolute discount
  final _discountCtrl = TextEditingController(text: '0');
  int? _activeCartIndex; // currently selected line
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Barcode Scanning
  final _barcodeFocusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPressTime;
  bool _isFullScreen = false;

  // Animation controller for cart item add
  late AnimationController _addAnim;

  @override
  void initState() {
    super.initState();
    _addAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _searchInputFocusNode = FocusNode();
    
    // Check initial full-screen state
    windowManager.isFullScreen().then((value) {
      if (mounted) setState(() => _isFullScreen = value);
    });
  }

  late FocusNode _searchInputFocusNode;

  @override
  void dispose() {
    _addAnim.dispose();
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _barcodeFocusNode.dispose();
    _searchInputFocusNode.dispose();
    super.dispose();
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  double get _subtotal =>
      ref.watch(cartProvider).fold(0.0, (s, i) => s + i.lineTotal);

  double get _total => (_subtotal - _discount).clamp(0.0, double.infinity);

  // ── Cart logic ────────────────────────────────────────────────────────────
  void _addToCart(Product p) async {
    if (p.isOutOfStock) {
      ref.read(soundServiceProvider).playStockAlert();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text("Produit Épuisé"),
            ],
          ),
          content: Text("Le produit '${p.name}' est actuellement en rupture de stock.\n\nVoulez-vous quand même l'ajouter au panier ? (Utile pour générer un devis)"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("ANNULER"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("AJOUTER AU PANIER"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    ref.read(cartProvider.notifier).addProduct(p);
    _addAnim
      ..reset()
      ..forward(from: 0);
  }

  Future<void> _toggleFullScreen() async {
    final newState = !_isFullScreen;
    ref.read(posFullScreenProvider.notifier).setFullScreen(newState);
    if (mounted) setState(() => _isFullScreen = newState);
  }

  void _handleBarcode(String code) {
    if (code.isEmpty) return;
    final theme = Theme.of(context);
    // Look for product with this barcode
    final products = ref.read(productListProvider).value ?? [];
    try {
      final p = products.firstWhere((p) => p.barcode == code);
      _addToCart(p);
      ref.read(soundServiceProvider).playScanSuccess();
      _showSnack("Produit ajouté : ${p.name}", theme.colorScheme.primary);
    } catch (e) {
      ref.read(soundServiceProvider).playScanError();
      _showSnack("Code-barres inconnu : $code", theme.colorScheme.error);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    // Only capture keys if no text field is focused (or handle specially)
    // For now, let's capture if it's fast
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
        // If it's slower than 100ms and we have a buffer, it might be a split or manual typing.
        if (elapsed > 300 && _barcodeBuffer.isNotEmpty) {
          _barcodeBuffer = '';
        }

        final char = event.character;
        if (char != null && char.isNotEmpty) {
          if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
            _barcodeBuffer += char;
          }
        }
      }
    }
  }

  void _setQty(int index, double qty, String productId) {
    ref.read(cartProvider.notifier).updateQty(productId, qty);
  }

  void _removeItem(int index, String productId) {
    final user = ref.read(authServiceProvider).value;
    if (user != null && !user.canRefund) {
      ref.read(soundServiceProvider).playScanError();
      _showSnack("Autorisation requise pour supprimer un article (canRefund).", Colors.red);
      return;
    }
    ref.read(cartProvider.notifier).removeProduct(productId);
    setState(() {
      _activeCartIndex = null;
    });
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  Future<void> _openCheckout() async {
    final currentCart = ref.read(cartProvider);
    if (currentCart.isEmpty) return;
    
    final selectedClientId = ref.read(selectedClientIdProvider);
    if (_isCreditSale && selectedClientId == null) {
      _showSnack(
        "Sélectionnez un client pour une vente à crédit.",
        Colors.orange,
      );
      return;
    }
    final clients = ref.read(clientListProvider).value ?? [];
    final client = selectedClientId != null
        ? clients.where((c) => c.id == selectedClientId).firstOrNull
        : null;
    final user = await ref.read(authServiceProvider.future);
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) {
      if (mounted) _showSnack("Paramètres non chargés", Colors.red);
      return;
    }
    final cartSnapshot = List<PosCartItem>.from(currentCart);

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(
        cart: cartSnapshot,
        subtotal: _subtotal,
        discount: _discount,
        total: _total,
        isCredit: _isCreditSale,
        clientId: selectedClientId,
        clientName: client?.name,
        clientPhone: client?.phone,
        cashierName: user?.username ?? 'Caissier',
        onConfirmed: (
              paid,
              change,
              totalAmount,
              paymentMethod,
              financialAccountId,
              receiptTpl,
              invoiceTpl,
              ptsRedeemed,
              discountAmount,
              multiPayments,
              dueDate,
            ) async {

              final rawCart = cartSnapshot
                  .map(
                    (i) => {
                      'product_id': i.productId,
                      'name': i.name,
                      'price': i.unitPrice,
                      'qty': i.qty,
                      'discount_percent': i.discountPercent,
                    },
                  )
                  .toList();

              // CRITICAL: Capture totals BEFORE checkout clears the cart
              final currentSubtotal = _subtotal;
              final currentIsCredit = _isCreditSale;
              final currentClient = client;

              String? saleId;
              try {
                saleId = await ref
                    .read(posProvider)
                    .checkout(
                      cart: rawCart,
                      totalAmount: totalAmount, // Use totalAmount from callback
                      amountPaid: paid,
                      clientId: selectedClientId,
                      accountId: financialAccountId,
                      paymentMethod: multiPayments != null
                          ? "MIXTE"
                          : paymentMethod,
                      isCredit: _isCreditSale,
                      pointsToRedeem: ptsRedeemed,
                      multiPayments: multiPayments,
                      discountAmount: discountAmount, // Use discountAmount from callback
                      dueDate: dueDate,
                    );
              } catch (e) {
                if (mounted) {
                  _showSnack("Erreur critique lors de l'enregistrement: $e", Colors.red);
                }
                return;
              }

              if (!mounted) return;
              if (saleId == null) {
                _showSnack("Erreur lors de l'enregistrement.", Colors.red);
                return;
              }

              // Data already captured before checkout

              final rItems = cartSnapshot
                  .map(
                    (i) => ReceiptItem(
                      name: i.name,
                      qty: i.qty,
                      unitPrice: i.unitPrice,
                      discountPercent: i.discountPercent,
                    ),
                  )
                  .toList();
              final iItems = cartSnapshot
                  .map(
                    (i) => InvoiceItem(
                      name: i.name,
                      qty: i.qty,
                      unitPrice: i.unitPrice,
                      discountPercent: i.discountPercent,
                    ),
                  )
                  .toList();

              final rd = ReceiptData(
                saleId: saleId,
                date: DateTime.now(),
                items: rItems,
                totalAmount: totalAmount,
                amountPaid: paid,
                change: change,
                isCredit: currentIsCredit,
                clientName: currentClient?.name,
                clientPhone: currentClient?.phone,
                cashierName: user?.username ?? 'Caissier',
                settings: settings,
                paymentMethod: paymentMethod,
                discountAmount: discountAmount,
                loyaltyPointsGained: (settings.loyaltyEnabled && currentClient != null) 
                  ? (totalAmount / settings.pointsPerAmount).floor() 
                  : 0,
                loyaltyPointsBalance: (settings.loyaltyEnabled && currentClient != null)
                  ? (currentClient.loyaltyPoints + (totalAmount / settings.pointsPerAmount).floor() - ptsRedeemed)
                  : 0,
              );

              final id = InvoiceData(
                invoiceNumber: "INV-${saleId.substring(0, 8).toUpperCase()}",
                date: DateTime.now(),
                items: iItems,
                subtotal: currentSubtotal,
                totalAmount: totalAmount,
                amountPaid: paid,
                change: change,
                isCredit: currentIsCredit,
                clientName: currentClient?.name,
                clientPhone: currentClient?.phone,
                clientEmail: currentClient?.email,
                cashierName: user?.username ?? 'Caissier',
                settings: settings,
                saleId: saleId,
                paymentMethod: paymentMethod,
                discountAmount: discountAmount,
                taxRate: settings.useTax ? (settings.taxRate / 100) : 0,
                loyaltyPointsGained: (settings.loyaltyEnabled && currentClient != null)
                  ? (totalAmount / settings.pointsPerAmount).floor()
                  : 0,
                loyaltyPointsBalance: (settings.loyaltyEnabled && currentClient != null)
                  ? (currentClient.loyaltyPoints + (totalAmount / settings.pointsPerAmount).floor() - ptsRedeemed)
                  : 0,
              );

              // ── SANDBOX IMPRESSION ──
              try {
                if (settings.autoPrintTicket) {
                  await ReceiptService.print(rd, settings.defaultReceipt);
                }
              } catch (e) {
                debugPrint("❌ Erreur impression automatique: $e");
                if (mounted) {
                  _showSnack("Vente enregistrée (Matériel indisponible : [Réimprimer])", Colors.orange);
                }
              }

              // ── FINALISATION FLUX (Même si l'impression a échoué) ──
              ref.read(soundServiceProvider).playSaleSuccess();

              if (mounted) {
                ref.read(cartProvider.notifier).clear();
                ref.read(selectedClientIdProvider.notifier).setClient(null);
                setState(() {
                  _discount = 0;
                  _discountCtrl.text = '0';
                  _isCreditSale = false;
                  _activeCartIndex = null;
                });
                
                // Affichage du succès premium
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => PaymentSuccessOverlay(
                    receiptData: rd,
                    invoiceData: id,
                  ),
                );
              }
            },
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canSell) {
      return const AccessDeniedScreen(
        message: "Accès Point de Vente Restreint",
        subtitle: "Votre rôle ne vous permet pas de réaliser des ventes.",
      );
    }

    // Log access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'VIEW_POS',
        description: 'Connexion au Point de Vente par ${user.username}',
      );
    });

    final currency = ref.watch(shopSettingsProvider).value?.currency ?? 'FCFA';
    final selectedClientId = ref.watch(selectedClientIdProvider);

    // Using ref.fmt extension from core/extensions/ref_extensions.dart

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): const DoNothingIntent(), // Managed via key listener if focus is not on input
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const DoNothingIntent(),
        // Enter is handled manually or by buttons
      },
      child: KeyboardListener(
        focusNode: _barcodeFocusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
             // Handle Global Shortcuts
             if (event.logicalKey == LogicalKeyboardKey.f1) {
                _searchInputFocusNode.requestFocus();
                return;
             }
             if (event.logicalKey == LogicalKeyboardKey.keyN && HardwareKeyboard.instance.isControlPressed) {
                ref.read(cartProvider.notifier).clear();
                setState(() => _activeCartIndex = null);
                _showSnack("Nouvelle vente initiée.", Colors.blue);
                return;
             }
             if (event.logicalKey == LogicalKeyboardKey.escape) {
               if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                 Navigator.pop(context); // Close Drawer
               } else if (_searchInputFocusNode.hasFocus) {
                 _searchInputFocusNode.unfocus();
                 _searchCtrl.clear();
                 setState(() => _searchQuery = '');
                 _barcodeFocusNode.requestFocus();
               }
               return;
             }

             // Submit Sale with Enter if Drawer is open or cart is not empty and no dialog is showing
             if (event.logicalKey == LogicalKeyboardKey.enter && !event.deviceType.name.contains('scanner')) {
                // If focus is NOT on a textfield (except barcode focus node)
                if (FocusManager.instance.primaryFocus == _barcodeFocusNode) {
                  final cart = ref.read(cartProvider);
                  if (cart.isNotEmpty) {
                    _openCheckout();
                  }
                }
             }
          }
          // Original barcode logic handle
          _handleKeyEvent(event);
        },
        child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        // FLOATING ACTION BUTTON
        floatingActionButton: Consumer(
          builder: (context, ref, child) {
            final cart = ref.watch(cartProvider);
            final totalItems = ref.read(cartProvider.notifier).totalItems;
            final subtotal = ref.read(cartProvider.notifier).subtotal;
            final total = (subtotal - _discount).clamp(0.0, double.infinity);

            return FloatingActionButton.extended(
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
              backgroundColor: cart.isEmpty
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.primary,
              icon: const Icon(FluentIcons.cart_24_filled, color: Colors.white),
              label: Text(
                cart.isEmpty
                    ? "Panier vide"
                    : "Panier (${ref.qty(totalItems)}) - ${ref.fmt(total)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              elevation: 8,
            );
          },
        ),
        // CART DRAWER (PANIER ELITE GLASS)
        endDrawer: Consumer(
          builder: (context, ref, child) {
            final cart = ref.watch(cartProvider);
            final totalItems = ref.read(cartProvider.notifier).totalItems;
            final subtotal = ref.read(cartProvider.notifier).subtotal;
            final total = (subtotal - _discount).clamp(0.0, double.infinity);

            return Drawer(
              width: 420,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: GlassContainer(
                borderRadius: 0,
                blur: 50,
                opacity: isDark ? 0.08 : 0.7,
                border: Border(
                  left: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Cart header
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 10,
                      ),
                      child: _CartHeader(
                        itemCount: totalItems,
                        onClear: cart.isEmpty
                            ? null
                            : () {
                                ref.read(cartProvider.notifier).clear();
                                setState(() => _activeCartIndex = null);
                                Navigator.pop(context); // close drawer if cleared
                              },
                      ),
                    ),
                    const Opacity(opacity: 0.2, child: Divider(height: 1)),

                    // Cart items list
                    Expanded(
                      child: cart.isEmpty
                          ? _EmptyCart()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemCount: cart.length,
                              itemBuilder: (ctx, i) => _CartLine(
                                item: PosCartItem(
                                  productId: cart[i].productId,
                                  name: cart[i].name,
                                  unitPrice: cart[i].unitPrice,
                                  qty: cart[i].qty,
                                ),
                                isActive: _activeCartIndex == i,
                                onTap: () => setState(() => _activeCartIndex = i),
                                onQtyChange: (qty) =>
                                    _setQty(i, qty, cart[i].productId),
                                onRemove: () => _removeItem(i, cart[i].productId),
                              ),
                            ),
                    ),

                    // Totals section (Remise + Client + Pay)
                    if (cart.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          children: [
                            // --- Remise ---
                            Row(
                              children: [
                                Icon(
                                  FluentIcons.tag_24_regular,
                                  size: 20,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "REMISE",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: _discountCtrl,
                                    enabled: user.canChangePrice,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                                    ],
                                    decoration: InputDecoration(
                                      prefixIcon: !user.canChangePrice ? const Icon(Icons.lock, size: 12, color: Colors.orange) : null,
                                      suffixText: currency,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13, 
                                      fontWeight: FontWeight.bold,
                                      color: !user.canChangePrice ? Colors.grey : null,
                                    ),
                                    onChanged: (v) => setState(() {
                                      _discount = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                                    }),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            // --- Client ---
                            Row(
                              children: [
                                Icon(
                                  FluentIcons.person_24_regular,
                                  size: 20,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: selectedClientId == null
                                      ? InkWell(
                                          onTap: () => _showClientSearch(context, ref),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                                              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "Lier un client...",
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                                          ),
                                          child: Row(
                                            children: [
                                              ref.watch(clientListProvider).when(
                                                data: (clients) {
                                                  final c = clients.firstWhere(
                                                    (c) => c.id == selectedClientId,
                                                    orElse: () => clients.first,
                                                  );
                                                  return Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          c.name,
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                        ),
                                                        Text(
                                                          "${c.loyaltyPoints} pts",
                                                          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                loading: () => const SizedBox(height: 20),
                                                error: (_, __) => const Text("Err"),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.error),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  ref.read(selectedClientIdProvider.notifier).setClient(null);
                                                  ref.read(cartProvider.notifier).forceBroadcast();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Payment toggle
                                _ModeToggle(
                                  isCredit: _isCreditSale,
                                  onChanged: (v) => setState(() {
                                    _isCreditSale = v;
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Totals CTA Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50.withValues(alpha: 0.5),
                          border: Border(
                            top: BorderSide(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Subtotal
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Sous-total",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  ref.fmt(subtotal),
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_discount > 0) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Remise globale",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    "- ${ref.fmt(_discount)}",
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            
                            // Total Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: _isCreditSale 
                                    ? theme.colorScheme.error.withValues(alpha: 0.08)
                                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "TOTAL GÉNÉRAL",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: _isCreditSale 
                                              ? theme.colorScheme.error.withValues(alpha: 0.6)
                                              : theme.colorScheme.primary.withValues(alpha: 0.6),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Text(
                                        _isCreditSale ? "Vente à Crédit" : "Vente au Comptant",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    ref.fmt(total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      letterSpacing: -0.8,
                                      color: _isCreditSale
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Checkout button
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: cart.isEmpty ? null : LinearGradient(
                                  colors: _isCreditSale
                                      ? [const Color(0xFFC62828), const Color(0xFFEF5350)]
                                      : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.85)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                color: cart.isEmpty ? Colors.grey.shade400 : null,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: cart.isEmpty ? [] : [
                                  BoxShadow(
                                    color: (_isCreditSale ? theme.colorScheme.error : theme.colorScheme.primary).withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: cart.isEmpty ? null : _openCheckout,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isCreditSale ? FluentIcons.people_money_20_filled : FluentIcons.payment_20_filled,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          (cart.isEmpty ? "PANIER VIDE" : (_isCreditSale ? "PAYER CRÉDIT" : "ENCAISSER")).toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        // BODY: PRODUCT BROWSER (PLEIN ECRAN)
        body: Stack(
          children: [
            // PREMIUM BACKGROUND LAYER
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark 
                      ? [const Color(0xFF020202), const Color(0xFF0E1015), const Color(0xFF020202)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  ),
                ),
              ),
            ),
            // Floating Decorative Shapes for Depth
            if (isDark) ...[
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark 
                      ? Colors.white.withValues(alpha: 0.02)
                      : theme.colorScheme.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
            
            Column(
              children: [
                // Top search bar (Frosted)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassContainer(
                          blur: 40,
                          opacity: isDark ? 0.1 : 0.6,
                          borderRadius: 20,
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchInputFocusNode,
                            decoration: InputDecoration(
                              hintText: "Rechercher un produit (F1)...",
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  FluentIcons.search_24_regular, 
                                  size: 24,
                                  color: isDark ? Colors.white60 : null,
                                ),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                            ),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Full-screen toggle button
                      GlassContainer(
                        width: 54,
                        height: 54,
                        blur: 40,
                        opacity: isDark ? 0.1 : 0.6,
                        borderRadius: 16,
                        child: IconButton(
                          icon: Icon(
                            _isFullScreen 
                              ? FluentIcons.full_screen_minimize_24_regular 
                              : FluentIcons.full_screen_maximize_24_regular,
                            size: 24,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          onPressed: _toggleFullScreen,
                          tooltip: _isFullScreen ? "Sortir du plein écran" : "Plein écran",
                        ),
                      ),
                    ],
                  ),
                ),

            // Category filter strip
            ref
                .watch(productListProvider)
                .when(
                  loading: () => const SizedBox(height: 60),
                  error: (_, __) => const SizedBox(height: 60),
                  data: (products) {
                    final cats =
                        products
                            .map((p) => p.category)
                            .whereType<String>()
                            .toSet()
                            .toList()
                          ..sort();
                    return SizedBox(
                      height: 50,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _catChip("Tout", _selectedCategory == null, isDark),
                          ...cats.map(
                            (c) => _catChip(c, _selectedCategory == c, isDark),
                          ),
                        ],
                      ),
                    );
                  },
                ),

            // Product grid (PLEIN ECRAN)
            Expanded(
              child: ref
                  .watch(productListProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erreur: $e')),
                    data: (products) {
                      final filtered = products.where((p) {
                        final q = _searchQuery.toLowerCase().trim();
                        if (q.isEmpty) {
                          return _selectedCategory == null || p.category == _selectedCategory;
                        }

                        // Expanded Searchable Fields
                        final pName = p.name.toLowerCase();
                        final pBarcode = (p.barcode ?? '').toLowerCase();
                        final pRef = (p.reference ?? '').toLowerCase();
                        final pCat = (p.category ?? '').toLowerCase();
                        final pDesc = (p.description ?? '').toLowerCase();

                        // 1. Multi-Token Logic: Each word in query must match something
                        final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
                        bool multiMatch = tokens.every((t) => 
                          pName.contains(t) || 
                          pBarcode.contains(t) || 
                          pRef.contains(t) || 
                          pCat.contains(t) ||
                          pDesc.contains(t)
                        );

                        // 2. Magic Auto-Correct Fallback (Typo tolerance)
                        bool fuzzyMatch = false;
                        if (!multiMatch && q.length > 3) {
                          final sim = NlpEngine.similarity(q, pName);
                          if (sim >= 0.7) fuzzyMatch = true;
                        }

                        final matchQ = multiMatch || fuzzyMatch;
                        final matchC = _selectedCategory == null || p.category == _selectedCategory;
                        return matchQ && matchC;
                      }).toList();

                      // --- Smart Ranking / Sorting ---
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase().trim();
                        filtered.sort((a, b) {
                          final aName = a.name.toLowerCase();
                          final bName = b.name.toLowerCase();
                          final aBarcode = (a.barcode ?? '').toLowerCase();
                          final bBarcode = (b.barcode ?? '').toLowerCase();
                          final aRef = (a.reference ?? '').toLowerCase();
                          final bRef = (b.reference ?? '').toLowerCase();

                          // Priority 1: Exact Barcode or Reference (SKU) match
                          bool aExact = aBarcode == q || aRef == q;
                          bool bExact = bBarcode == q || bRef == q;
                          if (aExact && !bExact) return -1;
                          if (!aExact && bExact) return 1;

                          // Priority 2: Name starts with query
                          bool aPrefix = aName.startsWith(q);
                          bool bPrefix = bName.startsWith(q);
                          if (aPrefix && !bPrefix) return -1;
                          if (!aPrefix && bPrefix) return 1;

                          // Priority 3: Contains the full query as a block
                          bool aContains = aName.contains(q);
                          bool bContains = bName.contains(q);
                          if (aContains && !bContains) return -1;
                          if (!aContains && bContains) return 1;

                          // Priority 4: Alphabetical for consistency
                          return aName.compareTo(bName);
                        });
                      }

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FluentIcons.box_24_regular,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Aucun produit trouvé dans cette catégorie.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent:
                                  135, // ~30% smaller for more compact grid
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.82,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _ProductCard(
                          product: filtered[i],
                          onTap: () => _addToCart(filtered[i]),
                        ),
                      );
                    },
                  ),
            ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  // ── Category chip ─────────────────────────────────────────────────────────

  Widget _catChip(String label, bool active, bool isDark) => GestureDetector(
    onTap: () =>
        setState(() => _selectedCategory = label == "Tout" ? null : label),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(right: 12),
      child: GlassContainer(
        borderRadius: 12,
        blur: 20,
        opacity: active ? (isDark ? 0.3 : 0.8) : (isDark ? 0.1 : 0.4),
        color: active ? Theme.of(context).colorScheme.primary : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        border: Border.all(
          color: active 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          width: 0.5,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w900,
            color: active 
              ? Colors.white 
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    ),
  );

  void _showClientSearch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _ClientSearchDialog(
        onSelected: (id) {
          ref.read(selectedClientIdProvider.notifier).setClient(id);
          ref.read(cartProvider.notifier).forceBroadcast();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Card (Elite Glass Edition)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cartQty = ref.watch(cartProvider.select((cart) =>
        cart.where((item) => item.productId == product.id).firstOrNull?.qty ?? 0));

    final settings = ref.watch(shopSettingsProvider).value;

    final out = product.isOutOfStock;
    final low = product.isLowStock && !out;
    final inCart = cartQty > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: out ? null : onTap,
        onDoubleTap: out ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AbsorbPointer(
          absorbing: out,
          child: GlassContainer(
            borderRadius: 16,
            blur: 15,
            opacity: inCart ? (isDark ? 0.25 : 0.6) : (isDark ? 0.1 : 0.3),
            padding: EdgeInsets.zero,
            border: Border.all(
              color: inCart
                  ? theme.colorScheme.primary
                  : low
                  ? Colors.orange.withValues(alpha: 0.3)
                   : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05)),
              width: inCart ? 1.5 : 0.5,
            ),
            child: Stack(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: out ? 0.4 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image Section
                      Expanded(
                        flex: 11,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: ColorFiltered(
                            colorFilter: out 
                              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: (product.imagePath != null && product.imagePath!.isNotEmpty)
                                  ? Opacity(
                                      opacity: out ? 0.5 : 1.0,
                                      child: Image(
                                        image: ImageResolver.getProductImage(product.imagePath, settings),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildPlaceholderIcon(theme, out),
                                      ),
                                    )
                                  : _buildPlaceholderIcon(theme, out),
                            ),
                          ),
                        ),
                      ),

                      // Content Section
                      Expanded(
                        flex: 10,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: out
                                      ? Colors.grey.shade600
                                      : (isDark ? Colors.white : Colors.black87),
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      ref.fmt(product.sellingPrice),
                                      style: TextStyle(
                                        color: out
                                            ? Colors.grey
                                            : (inCart
                                                ? theme.colorScheme.primary
                                                : (isDark
                                                    ? Colors.white
                                                    : theme.colorScheme.primary)),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Tiny stock indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (out ? Colors.red : (low ? Colors.orange : Colors.green)).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      out ? "OUT" : ref.qty(product.quantity),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: out ? Colors.red : (low ? Colors.orange : Colors.green),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // \"ÉPUISÉ\" Overlay
                if (out)
                  Positioned.fill(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.15,
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          blur: 10,
                          opacity: 0.8,
                          borderRadius: 8,
                          color: Colors.red.shade900,
                          border: Border.all(color: Colors.white24, width: 1),
                          child: const Text(
                            "ÉPUISÉ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Selection Badge
                if (inCart)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      height: 24,
                      width: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          ref.qty(cartQty),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(ThemeData theme, bool out) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Icon(
        out ? FluentIcons.prohibited_24_regular : FluentIcons.box_24_regular,
        size: 26,
        color: out
            ? Colors.grey.withValues(alpha: 0.5)
            : (isDark ? Colors.white.withValues(alpha: 0.2) : theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Cart header
// ─────────────────────────────────────────────────────────────────────────────

class _CartHeader extends ConsumerWidget {
  final double itemCount;
  final VoidCallback? onClear;

  const _CartHeader({required this.itemCount, this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          Icon(
            FluentIcons.cart_24_filled,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            "Panier",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (itemCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ref.qty(itemCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (onClear != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: onClear,
              icon: const Icon(FluentIcons.delete_24_regular, size: 16),
              label: const Text("Vider", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty cart
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.cart_24_regular,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Panier vide",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Cliquez sur un produit\npour l'ajouter",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart line item
// ─────────────────────────────────────────────────────────────────────────────

class _CartLine extends ConsumerWidget {
  final PosCartItem item;
  final bool isActive;
  final VoidCallback onTap;
  final ValueChanged<double> onQtyChange;
  final VoidCallback onRemove;

  const _CartLine({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.onQtyChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Using ref.fmt extension

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1A1D24) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Qty stepper
            _QtyBox(
              qty: item.qty,
              onDecrement: () => onQtyChange(item.qty - 1.0),
              onIncrement: () => onQtyChange(item.qty + 1.0),
            ),
            const SizedBox(width: 10),

            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11, // Plus compact
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${ref.fmt(item.unitPrice)} × ${ref.qty(item.qty)}",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Line total + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ref.fmt(item.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      FluentIcons.delete_16_regular,
                      size: 16,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyBox extends StatelessWidget {
  final double qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QtyBox({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        _QtyBtn(icon: Icons.remove, color: color, onTap: onDecrement),
        SizedBox(
          width: 26,
          child: Text(
            DateFormatter.formatQuantity(qty),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        _QtyBtn(icon: Icons.add, color: color, onTap: onIncrement),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode toggle (Comptant / Crédit)
// ─────────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isCredit;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.isCredit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _ModeBtn(
            label: "Comptant",
            active: !isCredit,
            color: theme.colorScheme.primary,
            onTap: () => onChanged(false),
          ),
          _ModeBtn(
            label: "Crédit",
            active: isCredit,
            color: theme.colorScheme.error,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHECKOUT DIALOG (ULTRA PRO)
// ─────────────────────────────────────────────────────────────────────────────

class _CheckoutDialog extends ConsumerStatefulWidget {
  final List<PosCartItem> cart;
  final double subtotal;
  final double discount;
  final double total;
  final bool isCredit;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String cashierName;
    final Future<void> Function(
      double paid,
      double change,
      double totalAmount, // Added
      String paymentMethod,
      String? selectedAccountId,
      ReceiptTemplate? receipt,
      InvoiceTemplate? invoice,
      int pointsToRedeem,
      double discountAmount,
      List<Map<String, dynamic>>? multiPayments,
      DateTime? dueDate,
    ) onConfirmed;

  const _CheckoutDialog({
    required this.cart,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.isCredit,
    this.clientId,
    this.clientName,
    this.clientPhone,
    required this.cashierName,
    required this.onConfirmed,
  });

  @override
  ConsumerState<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<_CheckoutDialog> {
  final _paidCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(); 
  final _clientSearchCtrl = TextEditingController(); 
  final _pointsToRedeemCtrl = TextEditingController(text: '0');
  final ReceiptTemplate _receipt = ReceiptTemplate.modern;
  InvoiceTemplate? _invoice;
  bool _processing = false;
  String? _selectedPaymentMethod;
  DateTime? _dueDate;

  bool _isMixedPayment = false;
  final Map<String, double> _mixedPaymentAmounts = {};
  final Map<String, String> _mixedPaymentAccounts = {};
  bool _isPercentageDiscount = true; 

  String? _selectedAccountId;
  String? _selectedClientId;
  String? _selectedClientName;


  double get _globalDiscount {
    final val = (double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0.0).abs();
    if (_isPercentageDiscount) {
      final cartTotal = widget.cart.fold(0.0, (sum, item) => sum + item.lineTotal);
      return cartTotal * (val / 100).clamp(0.0, 1.0);
    }
    return val;
  }

  double get _effectiveTotal {
    final cartTotal = widget.cart.fold(0.0, (sum, item) => sum + item.lineTotal);
    final settings = ref.read(shopSettingsProvider).value;
    double loyaltyDiscount = 0;
    if (settings != null && settings.loyaltyEnabled && !widget.isCredit) {
      final points = int.tryParse(_pointsToRedeemCtrl.text) ?? 0;
      loyaltyDiscount = points * settings.amountPerPoint;
    }
    return (cartTotal - _globalDiscount - loyaltyDiscount).clamp(0.0, double.infinity);
  }

  double get _paid => _isMixedPayment
      ? _mixedPaymentAmounts.values.fold(0.0, (sum, amt) => sum + amt)
      : (double.tryParse(_paidCtrl.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0.0);

  double get _change => (_paid - _effectiveTotal).clamp(0.0, double.infinity);
  bool get _canPay {
    if (widget.isCredit) {
      return _paid < _effectiveTotal || _effectiveTotal == 0.0;
    }
    return _paid >= _effectiveTotal;
  }

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    _selectedClientName = widget.clientName;


    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final treasury = ref.read(treasuryProvider.notifier);
        final defaultAcc = await treasury.getDefaultAccount(AccountType.CASH);
        if (defaultAcc != null && mounted) {
          setState(() {
            _selectedAccountId = defaultAcc.id;
            _selectedPaymentMethod = _getPaymentName(defaultAcc);
          });
        }
      } catch (e) {
        debugPrint('⚠️ Erreur pré-sélection caisse: $e');
      }
    });

    if (!widget.isCredit) {
      _paidCtrl.text = _effectiveTotal.round().toString();
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    _clientSearchCtrl.dispose();
    _pointsToRedeemCtrl.dispose();
    super.dispose();
  }



  void _setAmount(double amount) {
    setState(() {
      _paidCtrl.text = amount.round().toString();
    });
  }

  List<double> _smartQuickAmounts(double total) {
    final amounts = <double>{};
    final steps = [500, 1000, 2000, 5000, 10000, 25000, 50000, 100000];
    for (final step in steps) {
      double rounded(double v, double m) => (v / m).ceil() * m;
      final r = rounded(total, step.toDouble());
      if (r > total) amounts.add(r);
      if (amounts.length >= 4) break;
    }
    return amounts.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.isCredit
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final settings = ref.read(shopSettingsProvider).value;
    final accounts = ref.watch(myTreasuryAccountsProvider).value ?? [];
    final currency = settings?.currency ?? 'FCFA';

    final quickAmounts = _smartQuickAmounts(_effectiveTotal);
    final pointsToEarn = (settings?.loyaltyEnabled == true && _selectedClientId != null) 
        ? ((widget.isCredit ? _paid : _effectiveTotal) / (settings?.pointsPerAmount ?? 1000)).floor() 
        : 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isExtraWide = constraints.maxWidth > 1050;
          final isWide = constraints.maxWidth > 750;
          final dialogWidth = isExtraWide ? 1050.0 : (isWide ? 850.0 : 450.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: constraints.maxHeight * 0.9,
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlimHeader(theme, accent),

                  Flexible(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // COLUMN 1: CONFIGURATION
                              Expanded(
                                flex: 32,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: _buildConfigZone(theme, isDark, accent, currency, settings),
                                ),
                              ),
                              VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              
                              // COLUMN 2: PAYMENT MATRIX
                              Expanded(
                                flex: 38,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: _buildPaymentMatrix(theme, isDark, accent, accounts),
                                ),
                              ),
                              VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),

                              // COLUMN 3: RECAP & FINALIZE
                              Expanded(
                                flex: 30,
                                child: _buildFinalRecapPanel(theme, isDark, accent, pointsToEarn.toInt(), quickAmounts),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildMobileTotalRow(accent, isDark),
                                const SizedBox(height: 16),
                                _buildConfigZone(theme, isDark, accent, currency, settings),
                                const Divider(height: 32),
                                _buildPaymentMatrix(theme, isDark, accent, accounts),
                                const SizedBox(height: 32),
                                _buildFinalRecapPanel(theme, isDark, accent, pointsToEarn.toInt(), quickAmounts),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlimHeader(ThemeData theme, Color accent) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFEF4F4), // pale pinkish background
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFFBE4E4), width: 1)),
      ),
      child: Row(
        children: [
          Icon(widget.isCredit ? FluentIcons.shield_24_regular : FluentIcons.payment_24_filled, color: accent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              (widget.isCredit ? "STATION CRÉDIT" : "BORNE DE PAIEMENT"),
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 1.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          _statusBadge(isProcessing: _processing),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigZone(ThemeData theme, bool isDark, Color accent, String currency, ShopSettings? settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniHeader(FluentIcons.tag_24_regular, "REMISE GLOBALE"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "0.00",
                    suffixText: _isPercentageDiscount ? "%" : currency,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _toggleBtn(
              isSelected: _isPercentageDiscount,
              onTap: () => setState(() => _isPercentageDiscount = true),
              label: "%",
            ),
            _toggleBtn(
              isSelected: !_isPercentageDiscount,
              onTap: () => setState(() => _isPercentageDiscount = false),
              label: currency == 'FCFA' ? "CASH" : currency,
            ),
          ],
        ),
        const SizedBox(height: 28),
        _miniHeader(FluentIcons.person_24_regular, "INFOS CLIENT", subtitle: "Affectation du ticket"),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => showDialog(context: context, builder: (_) => _ClientSearchDialog(onSelected: (id) => _onClientSelected(id))),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedClientId != null 
                  ? accent.withValues(alpha: 0.3) 
                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              ),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
              ]
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _selectedClientId == null ? FluentIcons.person_24_regular : FluentIcons.person_24_filled, 
                    size: 20, 
                    color: _selectedClientId != null ? accent : Colors.grey
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedClientId == null ? "CLIENT PASSANT" : (_selectedClientName ?? "Chargement..."),
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.w900, 
                          color: _selectedClientId == null ? Colors.grey : (isDark ? Colors.white : Colors.black)
                        ),
                      ),
                      if (_selectedClientId != null)
                        Text("Compte Fidélité Actif", style: TextStyle(fontSize: 10, color: Colors.green.shade400, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (_selectedClientId != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() {
                      _selectedClientId = null;
                      _selectedClientName = null;
                      _pointsToRedeemCtrl.text = '0';
                    }),
                  )
                else
                   _actionButton(
                      icon: FluentIcons.person_add_24_regular,
                      onTap: () => _showQuickCreateClient(context),
                      tooltip: "Nouveau",
                      accent: accent,
                    ),
              ],
            ),
          ),
        ),
        if (settings?.loyaltyEnabled == true && _selectedClientId != null && !widget.isCredit) ...[
          const SizedBox(height: 20),
          _buildLoyaltyRedemption(theme, isDark, accent, settings!),
        ],
      ],
    );
  }

  Widget _actionButton({required IconData icon, required VoidCallback onTap, required String tooltip, required Color accent}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 18, color: accent),
          ),
        ),
      ),
    );
  }

  void _showQuickCreateClient(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _QuickCreateClientDialog(
        onCreated: (client) {
          setState(() {
            _selectedClientId = client.id;
            _selectedClientName = client.name;
          });
        },
      ),
    );
  }

  void _onClientSelected(String id) {
    final clients = ref.read(clientListProvider).value ?? [];
    final client = clients.where((c) => c.id == id).firstOrNull;
    if (client != null) {
      setState(() {
        _selectedClientId = client.id;
        _selectedClientName = client.name;

      });
    }
  }

  Widget _buildPaymentMatrix(ThemeData theme, bool isDark, Color accent, List<FinancialAccount> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isCredit) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info_20_regular, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Saisissez un acompte si le client paie une partie maintenant, ou laissez à 0 pour un crédit total.",
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniHeader(
              FluentIcons.building_bank_20_regular, 
              _isMixedPayment ? "PAIEMENT MULTIPLE" : "MODE DE PAIEMENT",
              subtitle: _isMixedPayment ? "Répartir sur plusieurs caisses" : "Sélectionner la source",
            ),
            Switch.adaptive(
              value: _isMixedPayment,
              onChanged: (v) => setState(() {
                _isMixedPayment = v;
                _mixedPaymentAmounts.clear();
                if (!widget.isCredit) {
                  _paidCtrl.text = _effectiveTotal.round().toString();
                } else {
                  _paidCtrl.text = "";
                }
              }),
              activeTrackColor: accent.withValues(alpha: 0.5),
              activeThumbColor: accent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_isMixedPayment)
          ...accounts.map((acc) => _buildMixedPaymentLineFromAccount(acc, isDark, accent))
        else ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2222) : const Color(0xFFFFF4F4), // match image pale red background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isCredit ? "ACOMPTE REÇU (EN COURS)" : "MONTANT REÇU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.colorScheme.error.withValues(alpha: 0.6), letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.6), width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _paidCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: theme.colorScheme.error, letterSpacing: -1),
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              if (newValue.text.isEmpty) return newValue;
                              String digitsOnly = newValue.text.replaceAll(RegExp(r'\s+'), '');
                              String formatted = '';
                              int count = 0;
                              for (int i = digitsOnly.length - 1; i >= 0; i--) {
                                formatted = digitsOnly[i] + formatted;
                                count++;
                                if (count % 3 == 0 && i > 0) {
                                  formatted = ' $formatted';
                                }
                              }
                              return TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(offset: formatted.length),
                              );
                            }),
                          ],
                          decoration: const InputDecoration(
                            hintText: "0",
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      Icon(FluentIcons.money_24_regular, color: theme.colorScheme.error.withValues(alpha: 0.5), size: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _miniHeader(FluentIcons.wallet_20_regular, "CAISSE DE RÉCEPTION"),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8, 
              childAspectRatio: 2.5,
            ),
            itemCount: accounts.length,
            itemBuilder: (context, idx) {
              final acc = accounts[idx];
              final isSelected = _selectedAccountId == acc.id;
              return InkWell(
                onTap: () => setState(() {
                  _selectedAccountId = acc.id;
                  _selectedPaymentMethod = _getPaymentName(acc);
                }),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? accent.withValues(alpha: 0.1) : (isDark ? Colors.white10 : Colors.white),
                    border: Border.all(
                      color: isSelected ? accent.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected || isDark ? [] : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_accountIcon(acc), color: isSelected ? accent : Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          acc.name.toUpperCase(), 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                            color: isSelected ? accent : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFinalRecapPanel(ThemeData theme, bool isDark, Color accent, int points, List<double> quickAmounts) {
    return Column(
      children: [
        _buildSummaryCard(isDark, accent),
        const Spacer(),
        _buildRealTimeTotals(isDark, accent),
        const SizedBox(height: 16),
        if (!widget.isCredit && !_isMixedPayment) ...[
          _buildQuickOptions(quickAmounts, accent),
          const SizedBox(height: 16),
        ],
        _buildCheckoutFooter(isDark, accent),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark, Color accent) {
    final settings = ref.read(shopSettingsProvider).value;
    // ignore: unused_local_variable
    final theme = Theme.of(context);
    final cartTotal = widget.cart.fold(0.0, (sum, item) => sum + item.lineTotal);
    final points = int.tryParse(_pointsToRedeemCtrl.text) ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "RÉSUMÉ D'ENCAISSEMENT", 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: theme.colorScheme.error.withValues(alpha: 0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isCredit) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(FluentIcons.shield_20_regular, color: theme.colorScheme.error, size: 12),
                          const SizedBox(width: 4),
                          Text("VENTE À CRÉDIT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.colorScheme.error)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _summaryRow("Base Panier (HT):", ref.fmt(cartTotal)),
              if (_globalDiscount > 0) 
                 _summaryRow("Remise Globale:", "-${ref.fmt(_globalDiscount)}", color: Colors.green),
              
              if (settings?.loyaltyEnabled == true && points > 0)
                _summaryRow("Fidélité ($points pts):", "-${ref.fmt(points * settings!.amountPerPoint)}", color: Colors.green),
              
              const SizedBox(height: 24),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TOTAL À PAYER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 4),
                  Text(
                    ref.fmt(_effectiveTotal), 
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: theme.colorScheme.error, letterSpacing: -1.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutFooter(bool isDark, Color accent) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _miniTotalRow("TOTAL REÇU", ref.fmt(_paid), isDark),
          const SizedBox(height: 12),
          _miniTotalRow("À RENDRE", ref.fmt(_change), isDark, isHighlight: _change > 0),
          const SizedBox(height: 16),
          if (widget.isCredit && _paid >= _effectiveTotal && _effectiveTotal > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                   Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 20),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text("Un acompte ne peut pas couvrir la totalité. Si le client paie tout, utilisez une transaction au comptant.", style: TextStyle(color: theme.colorScheme.error, fontSize: 11, fontWeight: FontWeight.bold)),
                   ),
                ]
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              icon: Icon(_processing ? Icons.hourglass_empty : FluentIcons.checkmark_circle_24_filled, size: 24),
              label: Text(
                _processing ? "TRAITEMENT..." : (widget.isCredit ? "ENREGISTRER LE CRÉDIT" : "ENCAISSER L'ARGENT"),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: theme.colorScheme.error.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: (_canPay && !_processing) ? _confirmCheckout : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTotalRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: isDark ? Colors.white54 : Colors.black45)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w900, 
            color: isHighlight ? Colors.green : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeTotals(bool isDark, Color accent) {
    if (widget.isCredit) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _miniHeader(FluentIcons.calendar_clock_20_regular, "ÉCHÉANCE DU CRÉDIT"),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _dueDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.calendar_20_regular, size: 18, color: accent),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate == null ? "Sélectionner une date" : DateFormat('dd/MM/yyyy').format(_dueDate!), 
                      style: TextStyle(fontWeight: FontWeight.w900, color: accent),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_calendar_rounded, size: 16, color: accent.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasChange = _change > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFBFBFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
        ),
        child: Column(
          children: [
            _summaryRow("TOTAL REÇU:", ref.fmt(_paid)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "À RENDRE:", 
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.w900, 
                    color: hasChange ? Colors.green : Colors.black26,
                  ),
                ),
                Text(
                  ref.fmt(_change), 
                  style: TextStyle(
                    fontSize: hasChange ? 24 : 18, 
                    fontWeight: FontWeight.w900, 
                    color: hasChange ? Colors.green : (isDark ? Colors.white24 : Colors.black26),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMobileTotalRow(Color accent, bool isDark) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      color: accent.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("TOTAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: accent)),
          Text(ref.fmt(_effectiveTotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: accent)),
        ],
      ),
    );
  }

  Widget _miniHeader(IconData icon, String label, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.grey)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 8, color: Colors.grey.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.2)),
        ],
      ),
    );
  }

  Widget _statusBadge({required bool isProcessing}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isProcessing ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isProcessing ? Colors.orange : Colors.green).withValues(alpha: 0.3)),
      ),
      child: Text(
        (isProcessing ? "Traitement..." : "Prêt").toUpperCase(),
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isProcessing ? Colors.orange : Colors.green),
      ),
    );
  }

  Widget _toggleBtn({required bool isSelected, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _buildQuickOptions(List<double> quickAmounts, Color accent) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _QuickBtn(label: "Exact", accent: accent, isAccent: true, onTap: () => _setAmount(_effectiveTotal)),
        ...quickAmounts.map((a) => _QuickBtn(label: ref.fmt(a), accent: accent, onTap: () => _setAmount(a))),
      ],
    );
  }

  Widget _buildMixedPaymentLineFromAccount(FinancialAccount acc, bool isDark, Color accent) {
    final currentVal = _mixedPaymentAmounts[acc.id] ?? 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: currentVal > 0 ? accent.withValues(alpha: 0.05) : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: currentVal > 0 ? accent.withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 45,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (currentVal > 0 ? accent : Colors.grey).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_accountIcon(acc), size: 14, color: currentVal > 0 ? accent : Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      acc.name.toUpperCase(), 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: currentVal > 0 ? FontWeight.w900 : FontWeight.bold,
                        letterSpacing: 0.5,
                        color: currentVal > 0 ? accent : (isDark ? Colors.grey : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 55,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: currentVal > 0 ? accent.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: currentVal > 0 ? accent : (isDark ? Colors.white : Colors.black)),
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final amt = double.tryParse(v) ?? 0.0;
                    setState(() {
                      if (amt > 0) {
                        _mixedPaymentAmounts[acc.id] = amt;
                        _mixedPaymentAccounts[acc.id] = _getPaymentName(acc);
                      } else {
                        _mixedPaymentAmounts.remove(acc.id);
                        _mixedPaymentAccounts.remove(acc.id);
                      }
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }





















  Future<void> _confirmCheckout() async {
    final settings = ref.read(shopSettingsProvider).value;
    final totalDiscountPercent = (_globalDiscount / widget.subtotal) * 100;
    
    if (settings != null && totalDiscountPercent > settings.maxDiscountThreshold) {
      final authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinPadDialog(correctPin: settings.managerPin),
      );
      if (authorized != true) return;
    }

    // Validation for mixed payment
    if (_isMixedPayment) {
      if (_paid < _effectiveTotal && !widget.isCredit) {
        _showSnack("Le montant total n'est pas couvert.", Colors.orange);
        return;
      }
      
      // Check if all used methods have accounts
      bool missingAccount = false;
      _mixedPaymentAmounts.forEach((method, amount) {
        if (amount > 0 && (_mixedPaymentAccounts[method] == null || _mixedPaymentAccounts[method]!.isEmpty)) {
          missingAccount = true;
        }
      });
      
      if (missingAccount) {
        _showSnack("Compte de trésorerie manquant pour un des modes.", Colors.red);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _processing = true);
    
    List<Map<String, dynamic>>? multi;
    if (_isMixedPayment) {
      multi = [];
      _mixedPaymentAmounts.forEach((accId, amount) {
        if (amount > 0) {
          final accName = _mixedPaymentAccounts[accId];
          multi!.add({
            'accountId': accId,
            'amount': amount,
            'method': accName ?? 'Paiement Multiple',
          });
        }
      });
    }

    Navigator.pop(context); // Close dialog before triggering callback
    
    await widget.onConfirmed(
      _paid,
      _change,
      _effectiveTotal, // Added
      _selectedPaymentMethod ?? 'Espèces',
      _selectedAccountId,
      _receipt,
      _invoice,
      int.tryParse(_pointsToRedeemCtrl.text) ?? 0,
      _globalDiscount,
      multi,
      _dueDate,
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        showCloseIcon: true,
      ),
    );
  }

  IconData _accountIcon(FinancialAccount acc) {
    switch (acc.type) {
      case AccountType.CASH:
        return FluentIcons.wallet_24_filled;
      case AccountType.BANK:
        return FluentIcons.building_bank_24_filled;
      case AccountType.MOBILE_MONEY:
        final op = (acc.operator ?? '').toLowerCase();
        if (op.contains('wave')) return FluentIcons.phone_24_filled;
        if (op.contains('orange')) return FluentIcons.phone_24_filled;
        return FluentIcons.phone_24_filled;
    }
  }

  String _getPaymentName(FinancialAccount acc) {
    if (acc.type == AccountType.CASH) return "ESPÈCES";
    if (acc.operator != null && acc.operator!.isNotEmpty) {
      return acc.operator!.toUpperCase();
    }
    switch (acc.type) {
      case AccountType.BANK:
        return "CARTE/BANQUE";
      case AccountType.MOBILE_MONEY:
        return "MOBILE MONEY";
      default:
        return acc.name.toUpperCase();
    }
  }



  Widget _buildLoyaltyRedemption(ThemeData theme, bool isDark, Color accent, ShopSettings settings) {
    final clients = ref.watch(clientListProvider).value ?? [];
    final client = clients.where((c) => c.id == _selectedClientId).firstOrNull;
    final availablePoints = client?.loyaltyPoints ?? 0;
    
    if (availablePoints <= 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(FluentIcons.gift_16_regular, color: Colors.grey.shade400, size: 16),
            const SizedBox(width: 8),
            Text("Le client n'a pas encore de points.", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("POINTS DISPONIBLES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent.withValues(alpha: 0.7))),
                  Text("$availablePoints pts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    _pointsToRedeemCtrl.text = availablePoints.toString();
                  });
                },
                icon: const Icon(FluentIcons.arrow_down_16_filled, size: 16),
                tooltip: "Utiliser tout",
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pointsToRedeemCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: "POINTS À UTILISER",
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    hintText: "0",
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (v) {
                    final pts = int.tryParse(v) ?? 0;
                    if (pts > availablePoints) {
                      _pointsToRedeemCtrl.text = availablePoints.toString();
                    }
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("REMISE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.green)),
                  Text(
                    "- ${ref.fmt((int.tryParse(_pointsToRedeemCtrl.text) ?? 0) * settings.amountPerPoint)}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Amount Button
// ─────────────────────────────────────────────────────────────────────────────



// ─────────────────────────────────────────────────────────────────────────────
// Quick Amount Button
// ─────────────────────────────────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final bool isAccent;

  const _QuickBtn({
    required this.label,
    required this.onTap,
    required this.accent,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: isAccent ? accent.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white),
            side: BorderSide(
              color: isAccent ? accent.withValues(alpha: 0.5) : (isDark ? Colors.white10 : Colors.blueGrey.shade100),
              width: 1.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.5,
              color: isAccent ? accent : (isDark ? Colors.grey.shade400 : Colors.blueGrey.shade700),
            ),
          )),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────

class _ClientSearchDialog extends ConsumerStatefulWidget {
  final Function(String id) onSelected;
  const _ClientSearchDialog({required this.onSelected});

  @override
  ConsumerState<_ClientSearchDialog> createState() =>
      _ClientSearchDialogState();
}

class _ClientSearchDialogState extends ConsumerState<_ClientSearchDialog> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.person_search_24_filled,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Sélection Client",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Nom ou téléphone...",
                prefixIcon: const Icon(FluentIcons.search_20_regular),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = v);
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  final filtered = clients
                      .where(
                        (c) =>
                            c.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ) ||
                            (c.phone ?? '').contains(_query),
                      )
                      .toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text("Aucun client trouvé."));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(c.name[0].toUpperCase()),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(c.phone ?? "Sans téléphone"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${c.loyaltyPoints} pts",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (c.credit > 0)
                              const Text(
                                "Débiteur",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          widget.onSelected(c.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text("Erreur: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK CREATE CLIENT DIALOG (ELITE VERSION)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickCreateClientDialog extends ConsumerStatefulWidget {
  final Function(Client) onCreated;

  const _QuickCreateClientDialog({required this.onCreated});

  @override
  ConsumerState<_QuickCreateClientDialog> createState() => _QuickCreateClientDialogState();
}

class _QuickCreateClientDialogState extends ConsumerState<_QuickCreateClientDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    
    setState(() => _loading = true);
    try {
      final client = Client(
        id: const Uuid().v4(),
        name: name,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );

      await ref.read(clientListProvider.notifier).addClient(client);
      widget.onCreated(client);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: GlassContainer(
        width: 420,
        borderRadius: 24,
        blur: 40,
        opacity: isDark ? 0.3 : 0.95,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(FluentIcons.person_add_24_filled, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NOUVEAU CLIENT", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      Text("Ajout express au répertoire", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildField("Nom complet *", _nameCtrl, FluentIcons.person_20_regular, isDark, autofocus: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildField("Téléphone", _phoneCtrl, FluentIcons.phone_20_regular, isDark)),
                const SizedBox(width: 16),
                Expanded(child: _buildField("Email", _emailCtrl, FluentIcons.mail_20_regular, isDark)),
              ],
            ),
            const SizedBox(height: 20),
            _buildField("Adresse de résidence", _addressCtrl, FluentIcons.location_20_regular, isDark),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading 
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text("ENREGISTRER LE CLIENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isDark, {bool autofocus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          autofocus: autofocus,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintText: label.contains("*") ? "Obligatoire" : "Optionnel",
            hintStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey.shade400),
          ),
        ),
      ],
    );
  }
}

// PinPadDialog removed and moved to shared core/widgets/pin_pad_dialog.dart
