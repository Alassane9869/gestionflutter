import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:url_launcher/url_launcher.dart';

class DisplayLauncherService {
  static Future<void> launchCustomerDisplay(int port) async {
    final url = 'http://127.0.0.1:$port/display';

    try {
      if (Platform.isWindows) {
        // Retrieve all connected displays
        List<Display> displays = await screenRetriever.getAllDisplays();
        
        if (displays.length > 1) {
          Display? primaryDisplay;
          Display? secondaryDisplay;
          
          try {
             primaryDisplay = await screenRetriever.getPrimaryDisplay();
          } catch (e) {
             debugPrint("Erreur récupération écran principal: $e");
             if (displays.isNotEmpty) primaryDisplay = displays.first;
          }

          // Find the secondary display
          for (var display in displays) {
            if (primaryDisplay != null && display.id != primaryDisplay.id) {
              secondaryDisplay = display;
              break;
            }
          }

          if (secondaryDisplay != null) {
            final x = secondaryDisplay.visiblePosition?.dx.toInt() ?? 0;
            final y = secondaryDisplay.visiblePosition?.dy.toInt() ?? 0;
            
            debugPrint("🎯 2ème écran détecté en X:$x, Y:$y. Lancement Kiosk Auto...");

            // Method 1: Chrome Kiosk Mode
            try {
              final result = await Process.run(
                'cmd', 
                ['/c', 'start chrome --app=$url --window-position=$x,$y --kiosk --user-data-dir="%TEMP%\\danaya_display_chrome"']
              );
              // Si la commande ne retourne pas d'erreur critique
              if (result.exitCode == 0) return;
            } catch (e) {
              debugPrint("Échec du lancement Chrome: $e");
            }

            // Method 2: Edge Kiosk Mode
            try {
               final result = await Process.run(
                'cmd', 
                ['/c', 'start msedge --app=$url --window-position=$x,$y --kiosk --user-data-dir="%TEMP%\\danaya_display_edge"']
              );
              if (result.exitCode == 0) return;
            } catch (e) {
              debugPrint("Échec du lancement Edge: $e");
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la détection des écrans: $e");
    }

    // Fallback normal : s'il n'y a qu'un écran, ou pas Windows, ou si la tentative secrète a échoué.
    // L'utilisateur devra glisser lui-même la fenêtre.
    debugPrint("⚠️ Kiosk auto échoué ou non disponible. Lancement standard.");
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
