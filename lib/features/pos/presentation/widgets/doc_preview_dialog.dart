import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocPreviewDialog extends ConsumerStatefulWidget {
  final Future<pw.Document>? receiptFuture;
  final Future<pw.Document>? invoiceFuture;
  final String receiptFileName;
  final String invoiceFileName;
  final bool initialIsTicket;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onPrintInvoice;
  final String? clientEmail;
  final String? invoiceNumber;
  final String? shopName;

  const DocPreviewDialog({
    super.key,
    this.receiptFuture,
    this.invoiceFuture,
    this.receiptFileName = "Ticket.pdf",
    this.invoiceFileName = "Facture.pdf",
    this.initialIsTicket = true,
    this.onPrintReceipt,
    this.onPrintInvoice,
    this.clientEmail,
    this.invoiceNumber,
    this.shopName,
  });

  @override
  ConsumerState<DocPreviewDialog> createState() => _DocPreviewDialogState();
}

class _DocPreviewDialogState extends ConsumerState<DocPreviewDialog> {
  late bool _showTicket;
  bool _isSendingEmail = false;

  @override
  void initState() {
    super.initState();
    if (widget.receiptFuture == null) {
      _showTicket = false;
    } else if (widget.invoiceFuture == null) {
      _showTicket = true;
    } else {
      _showTicket = widget.initialIsTicket;
    }
  }

  Future<void> _sendEmail(Future<pw.Document>? currentFuture, String fileName) async {
    if (currentFuture == null) return;
    
    final emailCtrl = TextEditingController(text: widget.clientEmail);
    
    final targetEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Envoyer par Email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Veuillez confirmer l'adresse de réception :"),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: "Email du destinataire",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
            child: const Text("ENVOYER"),
          ),
        ],
      ),
    );

    if (targetEmail == null || targetEmail.isEmpty) return;

    setState(() => _isSendingEmail = true);

    try {
      final doc = await currentFuture;
      final bytes = await doc.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final emailService = ref.read(emailServiceProvider);
      
      EmailSendResult result;
      if (_showTicket) {
        result = await emailService.sendReceipt(
          recipient: targetEmail,
          saleId: widget.receiptFileName.replaceAll(RegExp(r'[^\w]'), ''),
          pdfFile: file,
        );
      } else {

        result = await emailService.sendInvoice(
          recipient: targetEmail,
          invoiceNumber: widget.invoiceNumber ?? "Facture",
          pdfFile: file,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? "Email envoyé avec succès à $targetEmail" : "Échec d'envoi : ${result.errorMessage}"),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
      
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final currentFuture = _showTicket ? widget.receiptFuture : widget.invoiceFuture;
    final currentFileName = _showTicket ? widget.receiptFileName : widget.invoiceFileName;
    final hasBoth = widget.receiptFuture != null && widget.invoiceFuture != null;

    final double dialogWidth = screenWidth > 900 ? 800 : screenWidth * 0.9;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(vertical: screenHeight * 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Carré
      elevation: 24,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          children: [
            // BARRE D'OUTILS DENSE
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF3F3F3),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(FluentIcons.print_20_regular, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text("DOC APERÇU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.white70 : Colors.black87)),
                  
                  const Spacer(),

                  // TABS DE NAVIGATION (SI MULTIPLES DOCS DISPO)
                  if (hasBoth)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white, border: Border.all(color: theme.dividerColor)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDenseTab("TICKET", true, isDark, theme),
                            _buildDenseTab("FACTURE", false, isDark, theme),
                          ],
                        ),
                      ),
                    ),
                    
                  const Spacer(),

                  // ACTIONS
                  Tooltip(
                    message: "Email",
                    child: IconButton(
                      icon: _isSendingEmail 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(FluentIcons.mail_20_regular, size: 16, color: Colors.orange),
                      onPressed: _isSendingEmail ? null : () => _sendEmail(currentFuture, currentFileName),
                      splashRadius: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Container(width: 1, height: 24, color: theme.dividerColor, margin: const EdgeInsets.symmetric(horizontal: 4)),
                  Tooltip(
                    message: "Imprimer",
                    child: IconButton(
                      icon: Icon(FluentIcons.print_20_regular, size: 16, color: theme.colorScheme.primary),
                      onPressed: () async {
                        final directPrintCallback = _showTicket ? widget.onPrintReceipt : widget.onPrintInvoice;
                        
                        if (directPrintCallback != null) {
                          directPrintCallback();
                          if (mounted) Navigator.pop(context);
                        } else {
                          final doc = await currentFuture;
                          if (doc != null) {
                            await Printing.layoutPdf(onLayout: (format) => doc.save(), name: currentFileName);
                          }
                        }
                      },
                      splashRadius: 20,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Container(width: 1, height: 24, color: theme.dividerColor, margin: const EdgeInsets.symmetric(horizontal: 4)),
                  IconButton(
                    onPressed: () => Navigator.pop(context), 
                    icon: const Icon(FluentIcons.dismiss_20_regular, size: 16),
                    splashRadius: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            
            // APERÇU PDF DENSE & STABILISÉ
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                child: currentFuture == null 
                  ? const Center(child: Text("Document non disponible", style: TextStyle(fontSize: 12)))
                  : RepaintBoundary(
                      child: FutureBuilder<pw.Document>(
                        key: ValueKey("${_showTicket}_$currentFileName"), 
                        future: currentFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(strokeWidth: 2),
                                  const SizedBox(height: 12),
                                  Text("GÉNÉRATION DU PDF...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                ],
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text("Erreur : ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 12)));
                          }
                          
                          return PdfPreview(
                            build: (format) => snapshot.data!.save(),
                            allowPrinting: false,
                            allowSharing: false,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            canDebug: false,
                            useActions: false,
                            pdfFileName: currentFileName,
                            dpi: 200,
                            maxPageWidth: _showTicket ? 380 : 800,
                            loadingWidget: const SizedBox.shrink(), // On utilise notre propre loader
                          );
                        },
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDenseTab(String label, bool forTicket, bool isDark, ThemeData theme) {
    final active = _showTicket == forTicket;
    return GestureDetector(
      onTap: () => setState(() => _showTicket = forTicket),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        alignment: Alignment.center,
        color: active ? theme.colorScheme.primary : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
