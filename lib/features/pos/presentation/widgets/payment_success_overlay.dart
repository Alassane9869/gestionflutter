import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/pos/services/receipt_service.dart';
import 'package:danaya_plus/features/pos/services/invoice_service.dart';
import 'package:danaya_plus/features/pos/presentation/widgets/sale_doc_viewer.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';

class PaymentSuccessOverlay extends StatelessWidget {
  final ReceiptData receiptData;
  final InvoiceData invoiceData;

  const PaymentSuccessOverlay({
    super.key,
    required this.receiptData,
    required this.invoiceData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Backdrop blur for premium feel
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 450,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOP ANIMATED CHECKMARK
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.successClr.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          FluentIcons.checkmark_circle_48_filled,
                          color: AppTheme.successClr,
                          size: 64,
                        ),
                      ),
                    )
                    .animate()
                    .scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                    )
                    .shimmer(delay: 800.ms, duration: 1200.ms, color: Colors.white24),

                    const SizedBox(height: 32),

                    // TITLE
                    Text(
                      "Vente Réussie !",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.successClr,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 12),

                    // SUBTITLE / SALE INFO
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "RÉF: ${receiptData.saleId.substring(0, 8).toUpperCase()}",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ).animate().fade(delay: 400.ms).scale(begin: const Offset(0.9, 0.9)),

                    const SizedBox(height: 48),

                    // THE QUESTION
                    Text(
                      "Une étape de plus ?",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fade(delay: 600.ms),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      "Voulez-vous prévisualiser les différents modèles de facture et ticket afin de faire un partage personnalisé ?",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ).animate().fade(delay: 700.ms),

                    const SizedBox(height: 48),

                    // ACTIONS
                    Column(
                      children: [
                        // PREVIEW BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (_) => SaleDocViewer(
                                  receiptData: receiptData,
                                  invoiceData: invoiceData,
                                  initialType: "ticket",
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: const Icon(FluentIcons.document_pdf_24_filled),
                            label: const Text(
                              "APERÇU DES MODÈLES",
                              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ).animate().slideX(begin: 0.1, end: 0, delay: 800.ms).fade(delay: 800.ms),

                        const SizedBox(height: 16),

                        // FINISH BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: BorderSide(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              "TERMINER",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ).animate().slideX(begin: 0.1, end: 0, delay: 900.ms).fade(delay: 900.ms),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
