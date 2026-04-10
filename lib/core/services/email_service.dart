import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

class EmailSendResult {
  final bool success;
  final String? errorMessage;
  EmailSendResult({required this.success, this.errorMessage});
}

class EmailService {
  final ShopSettings settings;

  EmailService(this.settings);

  /// Envoie un email avec des pièces jointes optionnelles.
  Future<EmailSendResult> sendEmail({
    required String recipient,
    required String subject,
    required String body,
    List<File>? attachments,
    bool isHtml = false,
  }) async {
    final smtpUser = settings.smtpUser.trim();
    final smtpPassword = settings.smtpPassword.trim().replaceAll(' ', '');

    if (smtpUser.isEmpty || smtpPassword.isEmpty) {
      return EmailSendResult(
        success: false,
        errorMessage: "Configuration SMTP incomplète (Utilisateur ou Mot de passe vide).",
      );
    }

    try {
      final smtpServer = _getSmtpServer(smtpUser, smtpPassword);
      
      final message = Message()
        ..from = Address(smtpUser, settings.name)
        ..recipients.add(recipient)
        ..subject = subject;

      if (isHtml) {
        message.html = body;
      } else {
        message.text = body;
      }

      if (attachments != null && attachments.isNotEmpty) {
        for (final file in attachments) {
          if (await file.exists()) {
            message.attachments.add(FileAttachment(file));
          }
        }
      }

      final sendReport = await send(message, smtpServer).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw 'Le serveur SMTP ne répond pas (Délai d\'attente dépassé).',
      );
      debugPrint('EmailService: Message sent: ${sendReport.toString()}');
      return EmailSendResult(success: true);
    } catch (e) {
      debugPrint('EmailService Error: $e');
      return EmailSendResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Détermine le serveur SMTP à utiliser avec les identifiants nettoyés.
  SmtpServer _getSmtpServer(String user, String password) {
    final host = settings.smtpHost.toLowerCase();
    
    if (host.contains('gmail')) {
      return gmail(user, password);
    } else if (host.contains('hotmail') || host.contains('outlook')) {
      return hotmail(user, password);
    } else if (host.contains('yahoo')) {
      return yahoo(user, password);
    } else {
      // SMTP Générique (Amélioré)
      final port = settings.smtpPort;
      return SmtpServer(
        settings.smtpHost.trim(),
        port: port,
        username: user,
        password: password,
        ssl: port == 465, // SSL/TLS direct
        allowInsecure: port != 465 && port != 587, 
        ignoreBadCertificate: true,
      );
    }
  }

  /// Méthode de validation rapide pour les réglages utilisateur.
  Future<EmailSendResult> testConnection() async {
    return sendEmail(
      recipient: settings.backupEmailRecipient.isNotEmpty 
          ? settings.backupEmailRecipient 
          : settings.smtpUser,
      subject: 'Danaya+ : Test de connexion SMTP',
      body: _buildHtmlLayout(
        'TEST DE CONNEXION RÉUSSI', 
        '<p>Félicitations ! Votre configuration SMTP fonctionne parfaitement.</p><p>Danaya+ Pro peut désormais envoyer vos sauvegardes et rapports automatiquement.</p>',
        badgeText: 'SYSTÈME',
        badgeColor: '#10b981', // Emerald
      ),
      isHtml: true,
    );
  }

  /// Applique un template HTML "Elite Design" professionnel au contenu de l'email.
  String _buildHtmlLayout(
    String title, 
    String content, {
    String? buttonText, 
    String? buttonUrl, 
    String? badgeText, 
    String? badgeColor,
  }) {
    final primaryColor = '#2563eb'; // Bleu Elite
    final statusColor = badgeColor ?? primaryColor;
    
    final contactParts = <String>[];
    if (settings.phone.isNotEmpty) contactParts.add('Tél: ${settings.phone}');
    if (settings.email.isNotEmpty) contactParts.add(settings.email);
    final contactLine = contactParts.isNotEmpty ? '${contactParts.join(' | ')}<br>' : '';
    final addressLine = settings.address.isNotEmpty ? '${settings.address}<br>' : '';

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #1e293b; line-height: 1.6; margin: 0; padding: 0; background-color: #f1f5f9; }
        .wrapper { background-color: #f1f5f9; padding: 40px 20px; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.05); border: 1px solid #e2e8f0; }
        .header { background: linear-gradient(135deg, $primaryColor 0%, #1d4ed8 100%); color: white; padding: 40px 30px; text-align: center; }
        .content { padding: 40px 30px; }
        .footer { background-color: #f8fafc; padding: 30px; text-align: center; font-size: 13px; color: #64748b; border-top: 1px solid #f1f5f9; }
        .badge { display: inline-block; padding: 6px 14px; background-color: $statusColor; color: white; border-radius: 50px; font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 20px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        .button { display: inline-block; padding: 14px 28px; background-color: $primaryColor; color: white !important; text-decoration: none; border-radius: 10px; font-weight: bold; margin-top: 25px; transition: all 0.2s ease; box-shadow: 0 4px 6px -1px rgba(37, 99, 235, 0.2); }
        .shop-name { font-size: 26px; font-weight: 900; margin-bottom: 8px; letter-spacing: -0.02em; }
        .title { font-size: 22px; font-weight: 800; color: #0f172a; margin-bottom: 25px; letter-spacing: -0.01em; }
        .subtitle { font-size: 14px; opacity: 0.9; font-weight: 500; }
        hr { border: 0; border-top: 1px solid #f1f5f9; margin: 30px 0; }
        table { width: 100%; border-collapse: separate; border-spacing: 0; border-radius: 10px; overflow: hidden; border: 1px solid #f1f5f9; }
        th { background-color: #f8fafc; padding: 12px; text-align: left; font-size: 12px; color: #64748b; text-transform: uppercase; letter-spacing: 0.02em; }
        td { padding: 12px; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="container">
            <div class="header">
                <div class="shop-name">${settings.name}</div>
                ${settings.slogan.isNotEmpty ? '<div class="subtitle">${settings.slogan}</div>' : ''}
            </div>
            <div class="content">
                ${badgeText != null ? '<div class="badge">$badgeText</div>' : ''}
                <div class="title">$title</div>
                $content
                ${buttonText != null ? '<div style="text-align: center;"><a href="${buttonUrl ?? '#'}" class="button">$buttonText</a></div>' : ''}
                <hr>
                <div style="font-size: 14px; color: #64748b;">
                  Merci de votre confiance,<br>
                  <strong>L'équipe ${settings.name}</strong>
                </div>
            </div>
            <div class="footer">
                <div style="font-weight: 700; color: #475569; margin-bottom: 10px;">${settings.name}</div>
                $addressLine
                $contactLine
                <div style="margin-top: 15px; font-size: 11px; opacity: 0.7;">© ${DateTime.now().year} ${settings.name}. Ce message est généré automatiquement par Danaya+ Pro.</div>
            </div>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Helper pour envoyer une facture PDF.
  Future<EmailSendResult> sendInvoice({
    required String recipient,
    required String invoiceNumber,
    required File pdfFile,
  }) async {
    final title = 'Facture $invoiceNumber';
    final content = '''
        <p>Bonjour,</p>
        <p>Veuillez trouver ci-joint votre facture <strong>$invoiceNumber</strong> correspondant à votre achat chez <strong>${settings.name}</strong>.</p>
        <p>Le document PDF est attaché à cet email pour votre archivage.</p>
    ''';
    
    return sendEmail(
      recipient: recipient,
      subject: 'Facture $invoiceNumber - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'FACTURE',
        badgeColor: '#2563eb',
      ),
      isHtml: true,
      attachments: [pdfFile],
    );
  }

  /// Helper pour envoyer un ticket de caisse PDF avec le template HTML professionnel.
  Future<EmailSendResult> sendReceipt({
    required String recipient,
    required String saleId,
    required File pdfFile,
  }) async {
    final shortId = saleId.length > 8 ? saleId.substring(0, 8) : saleId;
    final title = 'Ticket de Caisse #$shortId';
    final content = '''
        <p>Bonjour,</p>
        <p>Merci pour votre achat chez <strong>${settings.name}</strong> !</p>
        <p>Veuillez trouver ci-joint votre ticket de caisse <strong>#$shortId</strong> au format PDF pour votre archivage.</p>
        <p>Pour toute question concernant votre achat, n'hésitez pas à nous contacter.</p>
    ''';
    
    return sendEmail(
      recipient: recipient,
      subject: 'Ticket de caisse #$shortId - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'REÇU',
        badgeColor: '#10b981',
      ),
      isHtml: true,
      attachments: [pdfFile],
    );
  }

  /// Helper pour envoyer un devis PDF.
  Future<EmailSendResult> sendQuote({
    required String recipient,
    required String quoteNumber,
    required File pdfFile,
  }) async {
    final title = 'Devis $quoteNumber';
    final content = '''
        <p>Bonjour,</p>
        <p>Suite à votre demande, nous avons le plaisir de vous transmettre notre proposition commerciale <strong>$quoteNumber</strong>.</p>
        <p>Ce devis est valable ${settings.quoteValidityDays} jours. N'hésitez pas à nous contacter pour toute question.</p>
    ''';
    
    return sendEmail(
      recipient: recipient,
      subject: 'Devis $quoteNumber - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'DEVIS',
        badgeColor: '#6366f1',
      ),
      isHtml: true,
      attachments: [pdfFile],
    );
  }

  /// Helper pour envoyer un Bon de Commande (Fournisseur).
  Future<EmailSendResult> sendPurchaseOrder({
    required String recipient,
    required String poNumber,
    required String supplierName,
    required File pdfFile,
  }) async {
    final title = 'Bon de Commande $poNumber';
    final content = '''
        <p>Bonjour <strong>$supplierName</strong>,</p>
        <p>Veuillez trouver ci-joint notre bon de commande <strong>$poNumber</strong> émis par <strong>${settings.name}</strong>.</p>
        <p>Merci de bien vouloir nous confirmer sa réception et le délai de livraison prévu.</p>
    ''';
    
    return sendEmail(
      recipient: recipient,
      subject: 'Bon de Commande $poNumber - ${settings.name}',
      body: _buildHtmlLayout(title, content),
      isHtml: true,
      attachments: [pdfFile],
    );
  }

  /// Sends a debt reminder to a client
  Future<EmailSendResult> sendDebtReminder({
    required String recipient,
    required String clientName,
    required double totalDebt,
    File? statementFile,
  }) async {
    final title = 'Rappel de Paiement';
    final content = '''
        <p>Bonjour <strong>$clientName</strong>,</p>
        <p>Ceci est un rappel concernant votre solde débiteur dans notre boutique <strong>${settings.name}</strong>.</p>
        <p style="font-size: 20px; color: #dc2626; font-weight: bold; text-align: center; margin: 20px 0;">
            Montant dû : ${DateFormatter.formatCurrency(totalDebt, settings.currency, removeDecimals: false)}
        </p>
        <p>Nous vous remercions de bien vouloir régulariser votre situation dès que possible.</p>
        ${statementFile != null ? '<p>Vous trouverez en pièce jointe le détail de vos transactions (Relevé de compte).</p>' : ''}
    ''';

    return sendEmail(
      recipient: recipient,
      subject: 'Rappel de paiement - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'RAPPEL',
        badgeColor: '#ef4444',
      ),
      isHtml: true,
      attachments: statementFile != null ? [statementFile] : [],
    );
  }

  /// Sends a low stock alert report to the shop owner
  Future<EmailSendResult> sendLowStockAlert({
    required String recipient,
    required List<Map<String, dynamic>> lowStockProducts,
  }) async {
    if (lowStockProducts.isEmpty) return EmailSendResult(success: true);

    final title = 'ALERTE STOCK BAS';
    String tableRows = '';
    for (var p in lowStockProducts) {
      tableRows += '''
        <tr>
            <td style="padding: 10px; border-bottom: 1px solid #f3f4f6;">${p['name']}</td>
            <td style="padding: 10px; border-bottom: 1px solid #f3f4f6; text-align: center; color: #dc2626; font-weight: bold;">${p['stock']}</td>
            <td style="padding: 10px; border-bottom: 1px solid #f3f4f6; text-align: center;">${p['threshold']}</td>
        </tr>
      ''';
    }

    final content = '''
        <p>Les produits suivants ont atteint ou sont passés sous leur seuil d'alerte :</p>
        <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
            <thead>
                <tr style="background-color: #f9fafb;">
                    <th style="padding: 10px; text-align: left; border-bottom: 2px solid #e5e7eb;">Produit</th>
                    <th style="padding: 10px; text-align: center; border-bottom: 2px solid #e5e7eb;">Stock</th>
                    <th style="padding: 10px; text-align: center; border-bottom: 2px solid #e5e7eb;">Seuil</th>
                </tr>
            </thead>
            <tbody>
                $tableRows
            </tbody>
        </table>
        <p style="margin-top: 20px;">Veuillez prévoir un réapprovisionnement rapidement.</p>
    ''';

    return sendEmail(
      recipient: recipient,
      subject: 'ALERTE STOCK BAS - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'ALERTE STOCK',
        badgeColor: '#f59e0b',
      ),
      isHtml: true,
    );
  }

  /// Sends a professional sales report email with PDF/Excel attachments
  Future<EmailSendResult> sendSalesReport({
    required String recipient,
    required DateTimeRange range,
    required dynamic kpis, // ReportKPIs
    required List<dynamic> topProducts, // List<TopProduct>
    required List<dynamic> userSales, // List<UserSaleSummary>
    required List<File> attachments,
  }) async {

    
    final title = 'RAPPORT DE VENTES';
    
    // ── Table de performance par vendeur ──
    String userRows = '';
    for (var u in userSales) {
      userRows += '''
        <tr>
          <td style="padding: 10px; border-bottom: 1px solid #f3f4f6;"><strong>${u.username}</strong></td>
          <td style="padding: 10px; border-bottom: 1px solid #f3f4f6; text-align: center;">${u.salesCount}</td>
          <td style="padding: 10px; border-bottom: 1px solid #f3f4f6; text-align: right; color: #2563eb; font-weight: bold;">${DateFormatter.formatCurrency(u.totalRevenue, settings.currency, removeDecimals: true)}</td>
        </tr>
      ''';
    }

    final content = '''
        <p>Bonjour,</p>
        <p>Veuillez trouver ci-joint les rapports d'activité pour la période du <strong>${DateFormatter.formatDate(range.start)}</strong> au <strong>${DateFormatter.formatDate(range.end)}</strong>.</p>
        
        <div style="background-color: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #e2e8f0;">
            <h3 style="margin-top: 0; color: #1e293b;">Résumé Global</h3>
            <table style="width: 100%;">
                <tr>
                    <td>Chiffre d'Affaires :</td>
                     <td style="text-align: right; font-weight: bold; font-size: 18px;">${DateFormatter.formatCurrency(kpis.totalRevenue, settings.currency, removeDecimals: true)}</td>
                </tr>
                <tr>
                    <td>Bénéfice Brut :</td>
                     <td style="text-align: right; font-weight: bold; color: #16a34a;">${DateFormatter.formatCurrency(kpis.totalProfit, settings.currency, removeDecimals: true)}</td>
                </tr>
                <tr>
                    <td>Nombre de Ventes :</td>
                    <td style="text-align: right; font-weight: bold;">${kpis.salesCount}</td>
                </tr>
            </table>
        </div>

        <h3 style="color: #1e293b;">Performance par Vendeur</h3>
        <table style="width: 100%; border-collapse: collapse;">
            <thead>
                <tr style="background-color: #f1f5f9;">
                    <th style="padding: 10px; text-align: left; border-bottom: 2px solid #e2e8f0;">Vendeur</th>
                    <th style="padding: 10px; text-align: center; border-bottom: 2px solid #e2e8f0;">Ventes</th>
                    <th style="padding: 10px; text-align: right; border-bottom: 2px solid #e2e8f0;">CA</th>
                </tr>
            </thead>
            <tbody>
                $userRows
            </tbody>
        </table>

        <p style="margin-top: 20px;">Les fichiers PDF et Excel détaillés sont joints à cet email.</p>
    ''';

    return sendEmail(
      recipient: recipient,
      subject: 'Rapport de Ventes (${DateFormatter.formatDate(range.start)} - ${DateFormatter.formatDate(range.end)}) - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'ANALYSE FINANCIÈRE',
        badgeColor: '#4f46e5',
      ),
      isHtml: true,
      attachments: attachments,
    );
  }

  /// Sends the encrypted database backup to the admin email
  Future<EmailSendResult> sendDatabaseBackup({
    required String recipient,
    required File backupFile,
  }) async {
    final title = 'SAUVEGARDE SYSTÈME SÉCURISÉE';
    
    // Compression au format GZ (Isolate pour ne pas figer l'UI)
    final gzPath = '${backupFile.path}.gz';
    final secureFile = File(gzPath);
    final bytes = await backupFile.readAsBytes();
    
    final compressedBytes = await compute((List<int> b) => gzip.encode(b), bytes);
    await secureFile.writeAsBytes(compressedBytes);

    final fileSizeMb = (await secureFile.length()) / (1024 * 1024);
    
    final content = '''
        <p>Bonjour,</p>
        <p>Une sauvegarde automatique de la base de données <strong>${settings.name}</strong> a été générée avec succès le <strong>${DateFormatter.formatDateTime(DateTime.now())}</strong>.</p>
        
        <div style="background-color: #f8fafc; padding: 15px; border-radius: 8px; margin: 20px 0; border: 1px solid #e2e8f0; text-align: center;">
            <p style="margin: 0; color: #16a34a; font-weight: bold;">✅ Base de données intègre et compressée</p>
            <p style="margin: 5px 0 0 0; font-size: 13px;">Taille de l'archive : ${fileSizeMb.toStringAsFixed(2)} Mo</p>
        </div>

        <p>Le fichier de sauvegarde sécurisé <code>${secureFile.path.split(Platform.pathSeparator).last}</code> est en pièce jointe (Format GZ).</p>
        <p style="color: #dc2626; font-size: 12px; font-weight: bold;">
          ⚠️ Conservez cette archive en lieu sûr. Le fichier interne est vital pour restaurer votre système Danaya+.
        </p>
    ''';

    final result = await sendEmail(
      recipient: recipient,
      subject: 'Sauvegarde Sécurisée BDD - ${DateFormatter.formatDate(DateTime.now())} - ${settings.name}',
      body: _buildHtmlLayout(
        title, 
        content,
        badgeText: 'SÉCURITÉ CLOUD',
        badgeColor: '#059669',
      ),
      isHtml: true,
      attachments: [secureFile],
    );

    // Suppression de l'archive temporaire après l'envoi pour des raisons de sécurité
    if (await secureFile.exists()) {
      await secureFile.delete();
    }

    return result;
  }
}

final emailServiceProvider = Provider<EmailService>((ref) {
  final settings = ref.watch(shopSettingsProvider).value;
  return EmailService(settings ?? ShopSettings());
});
