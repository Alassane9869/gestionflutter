import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

final marketingEmailServiceProvider = Provider<MarketingEmailService>((ref) {
  final emailService = ref.watch(emailServiceProvider);
  return MarketingEmailService(emailService, ref);
});

class MarketingBroadcastResult {
  final int totalClients;
  final int clientsWithEmail;
  final int emailsSent;
  final int emailsFailed;
  final List<String> errorMessages;
  
  MarketingBroadcastResult({
    required this.totalClients,
    required this.clientsWithEmail,
    required this.emailsSent,
    required this.emailsFailed,
    this.errorMessages = const [],
  });

  bool get success => emailsSent > 0;
}

class MarketingEmailService {
  final EmailService _emailService;
  final Ref _ref;

  MarketingEmailService(this._emailService, this._ref);

  /// Sends a broadcast email for a new product.
  Future<MarketingBroadcastResult> broadcastNewProduct(Product product, List<Client> clients) async {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || !settings.marketingEmailsEnabled) {
      return MarketingBroadcastResult(
        totalClients: clients.length,
        clientsWithEmail: 0,
        emailsSent: 0,
        emailsFailed: 0,
      );
    }

    final clientsWithEmail = clients.where((c) => c.email != null && c.email!.isNotEmpty).toList();
    if (clientsWithEmail.isEmpty) {
      return MarketingBroadcastResult(
        totalClients: clients.length,
        clientsWithEmail: 0,
        emailsSent: 0,
        emailsFailed: 0,
      );
    }

    int sentCount = 0;
    int failedCount = 0;
    List<String> errors = [];

    
    final htmlContent = _buildNewProductHtml(
      shopName: settings.name,
      productName: product.name,
      price: DateFormatter.formatCurrency(product.sellingPrice, settings.currency, removeDecimals: settings.removeDecimals),
      category: product.category ?? "Général",
      description: product.description ?? "Découvrez notre nouveau produit dès maintenant en magasin !",
      primaryColor: "#d4af37",
    );

    for (var client in clientsWithEmail) {
      try {
        final result = await _emailService.sendEmail(
          recipient: client.email!,
          subject: "✨ Nouveau chez ${settings.name} : ${product.name}",
          body: htmlContent,
          isHtml: true,
        );
        if (result.success) {
          sentCount++;
        } else {
          failedCount++;
          if (result.errorMessage != null) errors.add(result.errorMessage!);
        }
      } catch (e) {
        failedCount++;
        errors.add(e.toString());
      }
    }

    return MarketingBroadcastResult(
      totalClients: clients.length,
      clientsWithEmail: clientsWithEmail.length,
      emailsSent: sentCount,
      emailsFailed: failedCount,
      errorMessages: errors,
    );
  }

  /// Sends a re-engagement email to an inactive client.
  Future<EmailSendResult> sendInactivityReminder(Client client) async {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || client.email == null || client.email!.isEmpty) {
      return EmailSendResult(success: false, errorMessage: "Client sans e-mail.");
    }

    final htmlContent = _buildInactivityHtml(
      shopName: settings.name,
      clientName: client.name,
      primaryColor: "#d4af37",
    );

    return await _emailService.sendEmail(
      recipient: client.email!,
      subject: "👋 Vous nous manquez chez ${settings.name}",
      body: htmlContent,
      isHtml: true,
    );
  }

  String _buildNewProductHtml({
    required String shopName,
    required String productName,
    required String price,
    required String category,
    required String description,
    required String primaryColor,
  }) {
    return '''
<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f9f9f9;">
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    <tr>
      <td align="center" style="padding: 40px 0;">
        <table border="0" cellpadding="0" cellspacing="0" width="600" style="background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.05);">
          <!-- Header -->
          <tr>
            <td align="center" style="background-color: #1a1a1a; padding: 40px 20px;">
              <h2 style="color: $primaryColor; margin: 0; font-size: 24px; letter-spacing: 2px;">$shopName</h2>
              <p style="color: #ffffff; margin: 10px 0 0 0; font-size: 14px; opacity: 0.7; text-transform: uppercase; letter-spacing: 1px;">Arrivage Exclusif</p>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px 40px 20px 40px;">
              <h1 style="color: #1a1a1a; margin: 0; font-size: 28px; line-height: 1.2;">Un nouveau trésor est arrivé.</h1>
              <div style="margin: 30px 0; padding: 25px; background-color: #fcfcfc; border: 1px solid #efefef; border-radius: 8px;">
                <p style="color: $primaryColor; font-weight: bold; margin: 0 0 10px 0; text-transform: uppercase; font-size: 12px;">$category</p>
                <h3 style="color: #1a1a1a; margin: 0 0 15px 0; font-size: 22px;">$productName</h3>
                <p style="color: #666666; margin: 0; line-height: 1.6; font-size: 16px;">$description</p>
                <div style="margin-top: 25px; border-top: 1px solid #efefef; padding-top: 20px;">
                  <span style="color: #999999; font-size: 14px;">Prix de vente :</span>
                  <span style="color: #1a1a1a; font-size: 24px; font-weight: bold; margin-left: 10px;">$price</span>
                </div>
              </div>
            </td>
          </tr>
          <!-- CTA -->
          <tr>
            <td align="center" style="padding: 0 40px 40px 40px;">
              <table border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="background-color: $primaryColor; border-radius: 6px;">
                    <a href="#" style="display: inline-block; padding: 16px 40px; color: #000000; font-weight: bold; text-decoration: none; font-size: 16px;">Voir en magasin</a>
                  </td>
                </tr>
              </table>
              <p style="color: #999999; margin: 30px 0 0 0; font-size: 13px;">Nous sommes impatients de vous revoir chez $shopName.</p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td align="center" style="background-color: #fcfcfc; padding: 25px; border-top: 1px solid #efefef;">
              <p style="color: #bbbbbb; margin: 0; font-size: 11px;">Cet email vous est envoyé par $shopName. Vous pouvez gérer vos préférences de communication dans nos centres de gestion.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  String _buildInactivityHtml({
    required String shopName,
    required String clientName,
    required String primaryColor,
  }) {
    return '''
<!DOCTYPE html>
<html>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f9f9f9;">
  <table border="0" cellpadding="0" cellspacing="0" width="100%">
    <tr>
      <td align="center" style="padding: 40px 0;">
        <table border="0" cellpadding="0" cellspacing="0" width="600" style="background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.05);">
          <!-- Header -->
          <tr>
            <td align="center" style="background-color: #1a1a1a; padding: 40px 20px;">
              <h2 style="color: $primaryColor; margin: 0; font-size: 24px; letter-spacing: 2px;">$shopName</h2>
            </td>
          </tr>
          <!-- Content -->
          <tr>
            <td style="padding: 40px;">
              <h1 style="color: #1a1a1a; margin: 0; font-size: 26px;">Cher(e) $clientName,</h1>
              <p style="color: #666666; font-size: 16px; line-height: 1.8; margin: 25px 0;">
                Cela fait un moment que nous ne vous avons pas vu en magasin. Votre présence nous manque !
                <br><br>
                De nouveaux produits et des offres exclusives vous attendent. Passez nous voir pour découvrir les dernières nouveautés de <strong>$shopName</strong>.
              </p>
              <div style="margin: 35px 0; padding: 25px; background-color: #fff8e1; border: 1px solid #ffe082; border-radius: 8px; text-align: center;">
                <p style="color: #856404; margin: 0; font-size: 18px; font-weight: bold;">Une petite surprise vous attend en magasin.</p>
                <p style="color: #856404; margin: 10px 0 0 0; font-size: 14px; opacity: 0.8;">Mentionnez cet e-mail lors de votre prochain passage.</p>
              </div>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td align="center" style="padding: 0 40px 40px 40px;">
              <p style="color: #999999; margin: 0; font-size: 13px;">On se dit à très bientôt ?</p>
              <p style="color: #1a1a1a; margin: 10px 0 0 0; font-weight: bold; font-size: 15px;">L'équipe de $shopName</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
