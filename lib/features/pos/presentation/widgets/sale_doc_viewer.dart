import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:printing/printing.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/pos/services/receipt_service.dart';
import 'package:danaya_plus/features/pos/services/invoice_service.dart';
import 'package:danaya_plus/features/pos/services/quote_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SaleDocViewer extends ConsumerStatefulWidget {
  final ReceiptData? receiptData;
  final InvoiceData? invoiceData;
  final QuoteData? quoteData;
  final String? initialType; // "ticket", "invoice", "quote"

  const SaleDocViewer({
    super.key,
    this.receiptData,
    this.invoiceData,
    this.quoteData,
    this.initialType,
  });

  @override
  ConsumerState<SaleDocViewer> createState() => _SaleDocViewerState();
}

class _SaleDocViewerState extends ConsumerState<SaleDocViewer> {
  late String _currentType;
  bool _isSendingEmail = false;
  
  // Modèles sélectionnés
  ReceiptTemplate _selectedReceiptTpl = ReceiptTemplate.prestige;
  InvoiceTemplate _selectedInvoiceTpl = InvoiceTemplate.prestige;
  QuoteTemplate _selectedQuoteTpl = QuoteTemplate.prestige;

  @override
  void initState() {
    super.initState();
    
    // Initialisation des types
    if (widget.initialType != null) {
      _currentType = widget.initialType!;
    } else {
      if (widget.receiptData != null) {
        _currentType = "ticket";
      } else if (widget.invoiceData != null) {
        _currentType = "invoice";
      } else if (widget.quoteData != null) {
        _currentType = "quote";
      } else {
        _currentType = "ticket";
      }
    }

    // Initialisation des modèles par défaut depuis les paramètres
    final sReceipt = widget.receiptData?.settings;
    final sInvoice = widget.invoiceData?.settings;
    final sQuote = widget.quoteData?.settings;

    if (sReceipt != null) _selectedReceiptTpl = sReceipt.defaultReceipt;
    if (sInvoice != null) _selectedInvoiceTpl = sInvoice.defaultInvoice;
    if (sQuote != null) _selectedQuoteTpl = sQuote.defaultQuote;
  }

  Future<void> _sendEmail() async {
    final clientEmail = _getClientEmail();
    final emailCtrl = TextEditingController(text: clientEmail);
    
    // 1. Demander/Confirmer l'email si nécessaire
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
      final pdf = await _buildCurrentDoc();
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final fileName = _getFileName();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final emailService = ref.read(emailServiceProvider);
      
      EmailSendResult result;
      if (_currentType == "invoice") {
        result = await emailService.sendInvoice(
          recipient: targetEmail,
          invoiceNumber: widget.invoiceData!.invoiceNumber,
          pdfFile: file,
        );
      } else if (_currentType == "quote") {
        result = await emailService.sendQuote(
          recipient: targetEmail,
          quoteNumber: widget.quoteData!.quoteNumber,
          pdfFile: file,
        );
      } else {
        // Ticket — envoi avec le template HTML professionnel
        result = await emailService.sendReceipt(
          recipient: targetEmail,
          saleId: widget.receiptData?.saleId ?? 'N/A',
          pdfFile: file,
        );
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? "Email envoyé avec succès à $targetEmail" : "Échec : ${result.errorMessage}"),
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

  Future<void> _shareDoc() async {
    try {
      final pdf = await _buildCurrentDoc();
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final fileName = _getFileName();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName.replaceAll('.pdf', ''),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors du partage : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder() async {
    String? phone;
    String? clientName;
    double? amount;

    if (_currentType == "invoice" && widget.invoiceData != null) {
      phone = widget.invoiceData!.clientPhone?.replaceAll(RegExp(r'\D'), '');
      clientName = widget.invoiceData!.clientName;
      amount = widget.invoiceData!.totalAmount - widget.invoiceData!.amountPaid;
    } else if (_currentType == "ticket" && widget.receiptData != null) {
      phone = widget.receiptData!.clientPhone?.replaceAll(RegExp(r'\D'), '');
      clientName = widget.receiptData!.clientName;
      amount = widget.receiptData!.totalAmount - widget.receiptData!.amountPaid;
    }

    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Le client n'a pas de numéro de téléphone.")),
        );
      }
      return;
    }

    final settings = ref.read(shopSettingsProvider).value;
    final String shopName = settings?.name ?? "Danaya+";
    final String currency = settings?.currency ?? "FCFA";

    final String formattedAmount = DateFormatter.formatCurrency(
      amount ?? 0, 
      currency, 
      removeDecimals: settings?.removeDecimals ?? false
    );

    final String message = "Bonjour ${clientName ?? 'Cher client'}, c'est l'établissement $shopName. "
        "Nous vous contactons pour vous rappeler votre solde restant de $formattedAmount. "
        "Merci de régulariser votre situation dès que possible. Bonne journée !";

    final Uri whatsappUrl = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
        );
      }
    }
  }

  String? _getClientEmail() {
    switch (_currentType) {
      case "invoice": return widget.invoiceData?.clientEmail;
      case "quote": return widget.quoteData?.clientEmail;
      default: return null;
    }
  }

  // Cache pour les documents déjà générés
  final Map<String, pw.Document> _docCache = {};

  Future<pw.Document> _buildCurrentDoc() async {
    final String templateId;
    switch (_currentType) {
      case "ticket": templateId = _selectedReceiptTpl.name; break;
      case "invoice": templateId = _selectedInvoiceTpl.name; break;
      case "quote": templateId = _selectedQuoteTpl.name; break;
      default: templateId = "default";
    }
    
    final cacheKey = "$_currentType-$templateId";
    if (_docCache.containsKey(cacheKey)) {
      return _docCache[cacheKey]!;
    }

    final pw.Document doc;
    switch (_currentType) {
      case "ticket":
        doc = await ReceiptService.buildDocument(widget.receiptData!, _selectedReceiptTpl);
        break;
      case "invoice":
        doc = await InvoiceService.buildDocument(widget.invoiceData!, _selectedInvoiceTpl);
        break;
      case "quote":
        doc = await QuoteService.buildDocument(widget.quoteData!, _selectedQuoteTpl);
        break;
      default:
        throw Exception("Type inconnu");
    }

    _docCache[cacheKey] = doc;
    return doc;
  }

  String _getFileName() {
    switch (_currentType) {
      case "ticket": return "Ticket_${widget.receiptData?.saleId.substring(0, 8)}.pdf";
      case "invoice": return "Facture_${widget.invoiceData?.invoiceNumber}.pdf";
      case "quote": return "Devis_${widget.quoteData?.quoteNumber}.pdf";
      default: return "document.pdf";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final double dialogWidth = screenWidth > 900 ? 800 : screenWidth * 0.9;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(vertical: screenHeight * 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Carré industriel
      elevation: 24,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          children: [
            // BARRE D'OUTILS HAUTE DENSE
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF3F3F3),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    _currentType == "ticket" ? FluentIcons.receipt_20_regular : FluentIcons.document_pdf_20_regular, 
                    size: 18, color: theme.colorScheme.primary
                  ),
                  const SizedBox(width: 12),
                  Text("VISUALISATION DE DOCUMENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.white70 : Colors.black87)),
                  
                  const Spacer(),

                  // TABS DE NAVIGATION (SI MULTIPLES DOCS DISPO)
                  if (widget.receiptData != null || widget.invoiceData != null || widget.quoteData != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white,
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.receiptData != null) _buildDenseTab("TICKET", "ticket", isDark, theme),
                            if (widget.invoiceData != null) _buildDenseTab("FACTURE", "invoice", isDark, theme),
                            if (widget.quoteData != null) _buildDenseTab("DEVIS", "quote", isDark, theme),
                          ],
                        ),
                      ),
                    ),
                    
                  const Spacer(),

                  // ACTIONS RAPIDES DANS LA TOOLBAR
                  _buildToolAction(FontAwesomeIcons.whatsapp, "WhatsApp", _sendWhatsAppReminder, Colors.green),
                  _buildToolAction(FluentIcons.mail_20_regular, "Email", _sendEmail, Colors.orange),
                  _buildToolAction(FluentIcons.share_20_regular, "Partager", _shareDoc, Colors.blue),
                  Container(width: 1, height: 24, color: theme.dividerColor, margin: const EdgeInsets.symmetric(horizontal: 4)),
                  _buildToolAction(FluentIcons.print_20_regular, "Imprimer", () async {
                    if (_currentType == "ticket") {
                      await ReceiptService.print(widget.receiptData!, _selectedReceiptTpl);
                    } else if (_currentType == "invoice") {
                      await InvoiceService.print(widget.invoiceData!, _selectedInvoiceTpl);
                    } else if (_currentType == "quote") {
                      await QuoteService.print(widget.quoteData!, _selectedQuoteTpl);
                    }
                  }, theme.colorScheme.primary),
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
            
            // SELECTEUR DE MODÈLE ULTRA-COMPACT
            _buildDenseModelSelector(theme),

            // APERÇU PDF
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                child: FutureBuilder<pw.Document>(
                  key: ValueKey("$_currentType-$_selectedReceiptTpl-$_selectedInvoiceTpl-$_selectedQuoteTpl"), 
                  future: _buildCurrentDoc(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Erreur technique : ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 12)));
                    }
                    
                    return PdfPreview(
                      build: (format) => snapshot.data!.save(),
                      allowPrinting: false, // On utilise nos boutons de toolbar
                      allowSharing: false,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      useActions: false, // Pas d'actions standards PDF
                      pdfFileName: _getFileName(),
                      dpi: 200,
                      maxPageWidth: _currentType == "ticket" ? 400 : 800,
                      loadingWidget: const Center(child: Text("Génération...", style: TextStyle(fontSize: 10))),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDenseTab(String label, String type, bool isDark, ThemeData theme) {
    final active = _currentType == type;
    return GestureDetector(
      onTap: () => setState(() => _currentType = type),
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

  Widget _buildToolAction(IconData icon, String tooltip, Future<void> Function() action, Color color) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: _isSendingEmail && tooltip == "Email" 
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 16, color: color),
        onPressed: action,
        splashRadius: 20,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildDenseModelSelector(ThemeData theme) {
    List<Widget> chips = [];
    final isDark = theme.brightness == Brightness.dark;
    
    if (_currentType == "ticket") {
      chips = ReceiptTemplate.values.map((tpl) => _buildMiniChip(
        label: tpl == ReceiptTemplate.values.first ? "STANDARD" : tpl.name.toUpperCase(),
        active: _selectedReceiptTpl == tpl,
        onTap: () => setState(() => _selectedReceiptTpl = tpl),
        theme: theme, isDark: isDark,
      )).toList();
    } else if (_currentType == "invoice") {
      chips = InvoiceTemplate.values.map((tpl) => _buildMiniChip(
        label: tpl == InvoiceTemplate.values.first ? "STANDARD" : tpl.name.toUpperCase(),
        active: _selectedInvoiceTpl == tpl,
        onTap: () => setState(() => _selectedInvoiceTpl = tpl),
        theme: theme, isDark: isDark,
      )).toList();
    } else if (_currentType == "quote") {
      chips = QuoteTemplate.values.map((tpl) => _buildMiniChip(
        label: tpl == QuoteTemplate.values.first ? "STANDARD" : tpl.name.toUpperCase(),
        active: _selectedQuoteTpl == tpl,
        onTap: () => setState(() => _selectedQuoteTpl = tpl),
        theme: theme, isDark: isDark,
      )).toList();
    }

    return Container(
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(FluentIcons.paint_brush_16_regular, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text("STYLE :", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip({required String label, required bool active, required VoidCallback onTap, required ThemeData theme, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : (isDark ? Colors.white10 : Colors.grey.shade200),
          border: Border.all(color: active ? theme.colorScheme.primary : theme.dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9, 
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87)
          ),
        ),
      ),
    );
  }
}
