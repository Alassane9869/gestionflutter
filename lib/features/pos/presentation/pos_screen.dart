import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/assistant/application/nlp_engine.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';


import 'package:danaya_plus/features/pos/providers/pos_providers.dart';

import 'package:danaya_plus/features/pos/services/receipt_service.dart';
import 'package:danaya_plus/features/pos/services/invoice_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

import 'package:danaya_plus/features/pos/presentation/widgets/payment_success_overlay.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/premium_checkout_dialog.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/pos_product_card.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/pos_cart_widgets.dart';


import 'package:danaya_plus/core/widgets/glass_widgets.dart';
import 'package:danaya_plus/core/services/sound_service.dart';
import 'package:window_manager/window_manager.dart';


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
      builder: (_) => PremiumCheckoutDialog(
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
                      child: PosCartHeader(
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
                          ? const PosEmptyCart()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemCount: cart.length,
                              itemBuilder: (ctx, i) => PosCartLine(
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
                                PosPaymentModeToggle(
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
                        itemBuilder: (ctx, i) => PosProductCard(
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
      builder: (context) => PosClientSearchDialog(
        onSelected: (id) {
          ref.read(selectedClientIdProvider.notifier).setClient(id);
          ref.read(cartProvider.notifier).forceBroadcast();
        },
      ),
    );
  }
}


