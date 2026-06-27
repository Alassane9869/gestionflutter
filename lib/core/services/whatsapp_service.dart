import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';

final whatsappServiceProvider = Provider((ref) => WhatsappService());

class WhatsappService {
  /// Sends a WhatsApp message using the WhatsApp Cloud API.
  /// Requires proper configuration of the Cloud API (Token and Phone Number ID).
  Future<bool> sendMessageViaApi({
    required String to,
    required String message,
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': to,
          'type': 'text',
          'text': {
            'preview_url': false,
            'body': message,
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('WhatsApp API: Message sent successfully');
        return true;
      } else {
        debugPrint('WhatsApp API Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsApp API Exception: $e');
      return false;
    }
  }

  /// Sends a Document (PDF) using the WhatsApp Cloud API.
  /// This is a 2-step process: First we upload the file, then we send the message.
  Future<bool> sendDocumentViaApi({
    required String to,
    required Uint8List documentBytes,
    required String fileName,
    String? caption,
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      // Step 1: Upload the media to WhatsApp Servers
      final uploadUrl = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/media');
      
      var request = http.MultipartRequest('POST', uploadUrl)
        ..headers.addAll({
          'Authorization': 'Bearer $accessToken',
        })
        ..fields['messaging_product'] = 'whatsapp'
        ..files.add(http.MultipartFile.fromBytes(
          'file', 
          documentBytes, 
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ));

      final uploadResponse = await request.send();
      final uploadResponseBody = await uploadResponse.stream.bytesToString();
      
      if (uploadResponse.statusCode != 200) {
        debugPrint('WhatsApp API Upload Error: $uploadResponseBody');
        return false;
      }

      final mediaId = jsonDecode(uploadResponseBody)['id'];

      // Step 2: Send the document using the media ID
      final messageUrl = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');
      final messageResponse = await http.post(
        messageUrl,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'recipient_type': 'individual',
          'to': to,
          'type': 'document',
          'document': {
            'id': mediaId,
            'caption': caption ?? 'Voici votre document',
            'filename': fileName,
          }
        }),
      );

      if (messageResponse.statusCode == 200 || messageResponse.statusCode == 201) {
        debugPrint('WhatsApp API: Document sent successfully');
        return true;
      } else {
        debugPrint('WhatsApp API Document Error: ${messageResponse.body}');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsApp API Document Exception: $e');
      return false;
    }
  }

  /// Sends a Template message using the WhatsApp Cloud API.
  /// Mandatory if you initiate the conversation (outside the 24h window).
  /// [templateName] is the exact name of your approved template in Meta.
  /// [bodyVariables] is a list of texts to replace {{1}}, {{2}}, etc., in the template.
  /// [documentMediaId] and [documentFileName] are optional, used if your template header is a PDF.
  Future<bool> sendTemplateViaApi({
    required String to,
    required String templateName,
    String languageCode = 'fr',
    List<String> bodyVariables = const [],
    String? documentMediaId,
    String? documentFileName,
    required String phoneNumberId,
    required String accessToken,
  }) async {
    try {
      final url = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');

      // Construction des composants du template dynamiquement
      List<Map<String, dynamic>> components = [];

      // Si le template attend un document en en-tête (Header)
      if (documentMediaId != null && documentMediaId.isNotEmpty) {
        components.add({
          'type': 'header',
          'parameters': [
            {
              'type': 'document',
              'document': {
                'id': documentMediaId,
                if (documentFileName != null) 'filename': documentFileName,
              }
            }
          ]
        });
      }

      // Si le template contient des variables dans le corps du texte (Body)
      if (bodyVariables.isNotEmpty) {
        List<Map<String, dynamic>> bodyParams = bodyVariables.map((variable) {
          return {
            'type': 'text',
            'text': variable,
          };
        }).toList();

        components.add({
          'type': 'body',
          'parameters': bodyParams,
        });
      }

      final bodyPayload = {
        'messaging_product': 'whatsapp',
        'to': to,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {
            'code': languageCode,
          },
          // On ajoute la clé components uniquement si elle n'est pas vide
          if (components.isNotEmpty) 'components': components,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyPayload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('WhatsApp API: Template sent successfully');
        return true;
      } else {
        debugPrint('WhatsApp API Template Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsApp API Template Exception: $e');
      return false;
    }
  }

  /// Opens the WhatsApp app to send a message using a deep link.
  /// Useful for offline/local scenarios without using the Cloud API.
  Future<bool> openWhatsAppDirectly({
    required String phone,
    required String message,
  }) async {
    // Remove any non-numeric characters from the phone number
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final encodedMessage = Uri.encodeComponent(message);
    
    final url = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
    final webUrl = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(url);
      } else if (await canLaunchUrl(webUrl)) {
        return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('WhatsApp Direct: Could not launch WhatsApp');
        return false;
      }
    } catch (e) {
      debugPrint('WhatsApp Direct Exception: $e');
      return false;
    }
  }
}
