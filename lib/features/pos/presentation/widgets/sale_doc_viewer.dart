import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:danaya_plus/core/services/whatsapp_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';

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
  bool _isSendingWhatsapp = false;
  
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
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Envoyer par Email",
        icon: FluentIcons.mail_24_regular,
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Veuillez confirmer ou saisir l'adresse e-mail de réception :",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: emailCtrl,
              label: "ADRESSE E-MAIL DU DESTINATAIRE",
              hint: "Ex: client@domain.com",
              icon: FluentIcons.mail_24_regular,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
            child: const Text("Confirmer & Envoyer"),
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
            content: Text(result.success ? "Email envoyé avec succès à $targetEmail !" : "Échec : ${result.errorMessage}"),
            backgroundColor: result.success ? Colors.green.shade600 : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'envoi : $e"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendWhatsAppReminder() async {
    // Chercher le numéro et le nom dans TOUTES les sources disponibles
    String? phone;
    String? clientName;

    // DEBUG: Afficher ce que chaque source contient
    debugPrint('=== WhatsApp DEBUG ===');
    debugPrint('receiptData: ${widget.receiptData != null ? "OUI, phone=${widget.receiptData!.clientPhone}, name=${widget.receiptData!.clientName}" : "NULL"}');
    debugPrint('invoiceData: ${widget.invoiceData != null ? "OUI, phone=${widget.invoiceData!.clientPhone}, name=${widget.invoiceData!.clientName}" : "NULL"}');
    debugPrint('quoteData: ${widget.quoteData != null ? "OUI, phone=${widget.quoteData!.clientPhone}, name=${widget.quoteData!.clientName}" : "NULL"}');

    // Priorité au type courant, puis fallback sur les autres
    final sources = <Map<String, String?>>[
      if (widget.receiptData != null) {'phone': widget.receiptData!.clientPhone, 'name': widget.receiptData!.clientName},
      if (widget.invoiceData != null) {'phone': widget.invoiceData!.clientPhone, 'name': widget.invoiceData!.clientName},
      if (widget.quoteData != null) {'phone': widget.quoteData!.clientPhone, 'name': widget.quoteData!.clientName},
    ];

    for (final src in sources) {
      final srcPhone = src['phone'];
      final srcName = src['name'];
      if ((phone == null || phone.trim().isEmpty) && srcPhone != null && srcPhone.trim().isNotEmpty) {
        phone = srcPhone;
      }
      if ((clientName == null || clientName.trim().isEmpty) && srcName != null && srcName.trim().isNotEmpty) {
        clientName = srcName;
      }
    }

    // Recherche dans la base de données locale si le numéro est vide mais qu'on a le nom du client
    if ((phone == null || phone.trim().isEmpty) && clientName != null && clientName.trim().isNotEmpty) {
      final clients = ref.read(clientListProvider).value ?? [];
      final c = clients.firstWhere(
        (cl) => cl.name.toLowerCase() == clientName!.toLowerCase(),
        orElse: () => const Client(id: '', name: ''),
      );
      if (c.phone != null && c.phone!.isNotEmpty) {
        phone = c.phone;
      }
    }

    debugPrint('Résultat final: phone=$phone, clientName=$clientName');

    String? targetPhone = phone;

    if (targetPhone == null || targetPhone.trim().isEmpty) {
      final phoneCtrl = TextEditingController(text: phone);
      
      // Demander le numéro si absent
      targetPhone = await showDialog<String>(
        context: context,
        builder: (context) => EnterpriseWidgets.buildPremiumDialog(
          context,
          title: "Envoyer par WhatsApp",
          icon: FontAwesomeIcons.whatsapp,
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Le client n'a pas de numéro enregistré. Veuillez le saisir :",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: phoneCtrl,
                label: "NUMÉRO DE TÉLÉPHONE (WHATSAPP)",
                hint: "Ex: 76000000 ou 22376000000",
                icon: FontAwesomeIcons.whatsapp,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, phoneCtrl.text.trim()),
              child: const Text("Confirmer"),
            ),
          ],
        ),
      );
    }

    if (targetPhone == null || targetPhone.isEmpty) return;

    setState(() => _isSendingWhatsapp = true);

    try {
      final cleanPhone = targetPhone.replaceAll(RegExp(r'[^\d]'), '');
      String finalPhone = cleanPhone;
      if (cleanPhone.length == 8) {
        finalPhone = '223$cleanPhone'; // Préfixe Mali par défaut
      }

      final settings = ref.read(shopSettingsProvider).value;
      final whatsappService = ref.read(whatsappServiceProvider);
      final String shopName = settings?.name ?? "Danaya+";

      // On génère et sauvegarde le PDF localement pour qu'il soit facilement accessible
      final pdf = await _buildCurrentDoc();
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final fileName = _getFileName();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // On lance le WhatsApp classique (WhatsApp Web / Desktop)
      final String message = "Bonjour ${clientName ?? 'Cher client'}, voici votre document venant de $shopName.";
      final success = await whatsappService.openWhatsAppDirectly(
        phone: finalPhone,
        message: message,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir WhatsApp sur cet appareil."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur WhatsApp : $e"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingWhatsapp = false);
    }
  }

  String? _getClientEmail() {
    final sources = <String?>[
      if (widget.invoiceData != null) widget.invoiceData!.clientEmail,
      if (widget.quoteData != null) widget.quoteData!.clientEmail,
    ];
    for (final email in sources) {
      if (email != null && email.isNotEmpty) return email;
    }

    final clientName = widget.receiptData?.clientName ?? 
                       widget.invoiceData?.clientName ?? 
                       widget.quoteData?.clientName;
    final clientPhone = widget.receiptData?.clientPhone ?? 
                        widget.invoiceData?.clientPhone ?? 
                        widget.quoteData?.clientPhone;

    // Recherche dans la base locale si absent
    final clients = ref.read(clientListProvider).value ?? [];
    if (clientName != null && clientName.isNotEmpty) {
      final c = clients.firstWhere(
        (cl) => cl.name.toLowerCase() == clientName.toLowerCase(),
        orElse: () => const Client(id: '', name: ''),
      );
      if (c.email != null && c.email!.isNotEmpty) return c.email;
    }

    if (clientPhone != null && clientPhone.isNotEmpty) {
      final cleanPhone = clientPhone.replaceAll(RegExp(r'[^\d]'), '');
      for (final c in clients) {
        final cPhone = c.phone?.replaceAll(RegExp(r'[^\d]'), '');
        if (cPhone != null && cPhone.isNotEmpty && cPhone.contains(cleanPhone)) {
          if (c.email != null && c.email!.isNotEmpty) return c.email;
        }
      }
    }

    return null;
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

    final double dialogWidth = (screenWidth > 900 ? 900.0 : screenWidth * 0.92).clamp(400.0, screenWidth * 0.95);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          width: 1.5,
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: screenHeight * 0.92,
        ),
        child: Column(
          children: [
            // ─── HEADER (identique à buildPremiumDialog) ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _currentType == "ticket" 
                          ? FluentIcons.receipt_20_regular 
                          : _currentType == "quote"
                              ? FluentIcons.document_text_20_regular
                              : FluentIcons.document_pdf_20_regular,
                      size: 20, 
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Visualisation de Document",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Actions rapides
                  _buildHeaderAction(FontAwesomeIcons.whatsapp, "WhatsApp", _sendWhatsAppReminder, Colors.green, isLoading: _isSendingWhatsapp),
                  _buildHeaderAction(FluentIcons.mail_20_regular, "Email", _sendEmail, Colors.orange, isLoading: _isSendingEmail),
                  _buildHeaderAction(FluentIcons.share_20_regular, "Partager", _shareDoc, theme.colorScheme.primary),
                  Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                  _buildHeaderAction(FluentIcons.print_20_regular, "Imprimer", () async {
                    if (_currentType == "ticket") {
                      await ReceiptService.print(widget.receiptData!, _selectedReceiptTpl);
                    } else if (_currentType == "invoice") {
                      await InvoiceService.print(widget.invoiceData!, _selectedInvoiceTpl);
                    } else if (_currentType == "quote") {
                      await QuoteService.print(widget.quoteData!, _selectedQuoteTpl);
                    }
                  }, theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(FluentIcons.dismiss_24_regular, color: Colors.grey.shade500, size: 20),
                    style: IconButton.styleFrom(
                      hoverColor: Colors.red.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─── TABS + STYLE SELECTOR ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  // Tabs de type de document
                  if (widget.receiptData != null || widget.invoiceData != null || widget.quoteData != null)
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.receiptData != null) _buildDocTab("TICKET", "ticket", theme, isDark),
                          if (widget.invoiceData != null) _buildDocTab("FACTURE", "invoice", theme, isDark),
                          if (widget.quoteData != null) _buildDocTab("DEVIS", "quote", theme, isDark),
                        ],
                      ),
                    ),
                  
                  Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 16), color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                  
                  // Sélecteur de style
                  Icon(FluentIcons.paint_brush_16_regular, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "STYLE :", 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.primary, letterSpacing: 0.8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _buildStyleChips(theme, isDark)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─── APERÇU PDF ───
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF0A0A0C) : Colors.grey.shade200,
                child: FutureBuilder<pw.Document>(
                  key: ValueKey("$_currentType-$_selectedReceiptTpl-$_selectedInvoiceTpl-$_selectedQuoteTpl"), 
                  future: _buildCurrentDoc(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                            const SizedBox(height: 12),
                            Text("GÉNÉRATION DU DOCUMENT...", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: theme.colorScheme.primary)),
                          ],
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Erreur technique : ${snapshot.error}", style: const TextStyle(color: Colors.red, fontSize: 12)));
                    }
                    
                    return PdfPreview(
                      build: (format) => snapshot.data!.save(),
                      allowPrinting: false,
                      allowSharing: false,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      useActions: false,
                      pdfFileName: _getFileName(),
                      dpi: 200,
                      maxPageWidth: _currentType == "ticket" ? 420 : 800,
                      loadingWidget: const SizedBox.shrink(),
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

  // ─── Header action button (harmonisé avec le système) ───
  Widget _buildHeaderAction(IconData icon, String tooltip, Future<void> Function() action, Color color, {bool isLoading = false}) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton(
          onPressed: isLoading ? null : action,
          icon: isLoading 
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, size: 18, color: color),
          style: IconButton.styleFrom(
            hoverColor: color.withValues(alpha: 0.1),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  // ─── Doc type tab (harmonisé) ───
  Widget _buildDocTab(String label, String type, ThemeData theme, bool isDark) {
    final active = _currentType == type;
    return GestureDetector(
      onTap: () => setState(() => _currentType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: active ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  // ─── Style chips builder ───
  List<Widget> _buildStyleChips(ThemeData theme, bool isDark) {
    if (_currentType == "ticket") {
      return ReceiptTemplate.values.map((tpl) => _buildStyleChip(
        label: tpl == ReceiptTemplate.values.first ? "STANDARD" : tpl.name.toUpperCase(),
        active: _selectedReceiptTpl == tpl,
        onTap: () => setState(() => _selectedReceiptTpl = tpl),
        theme: theme, isDark: isDark,
      )).toList();
    } else if (_currentType == "invoice") {
      return InvoiceTemplate.values.map((tpl) => _buildStyleChip(
        label: tpl == InvoiceTemplate.values.first ? "STANDARD" : tpl.name.toUpperCase(),
        active: _selectedInvoiceTpl == tpl,
        onTap: () => setState(() => _selectedInvoiceTpl = tpl),
        theme: theme, isDark: isDark,
      )).toList();
    } else if (_currentType == "quote") {
      return QuoteTemplate.values.map((tpl) => _buildStyleChip(
        label: tpl == QuoteTemplate.values.first ? "STANDARD" : tpl.name.toUpperCase(),
        active: _selectedQuoteTpl == tpl,
        onTap: () => setState(() => _selectedQuoteTpl = tpl),
        theme: theme, isDark: isDark,
      )).toList();
    }
    return [];
  }

  // ─── Individual style chip (harmonisé avec buildPremiumDropdown) ───
  Widget _buildStyleChip({required String label, required bool active, required VoidCallback onTap, required ThemeData theme, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: active 
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active 
                    ? theme.colorScheme.primary 
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9, 
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
                color: active ? Colors.white : (isDark ? Colors.white60 : Colors.grey.shade700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
