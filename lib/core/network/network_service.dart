import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/server_service.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/core/network/cloud_sync_service.dart';

final networkServiceProvider = Provider((ref) => NetworkService(ref));

final localIpProvider = FutureProvider<String?>((ref) async {
  return await ref.read(networkServiceProvider).getLocalIp();
});

final serverReachabilityProvider = NotifierProvider<ServerReachabilityNotifier, bool>(
  ServerReachabilityNotifier.new,
);

class ServerReachabilityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setReachability(bool value) => state = value;
}

class NetworkService {
  final Ref _ref;
  final _info = NetworkInfo();
  Timer? _heartbeatTimer;
  bool _isListening = false;
  bool _isDiscovering = false;

  NetworkService(this._ref);

  Future<String?> getLocalIp() async {
    try {
      // Sur Windows, getWifiIP peut être capricieux. On tente NetworkInterface en backup.
      String? ip = await _info.getWifiIP();
      if (ip != null) return ip;

      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'IP: $e');
    }
    return null;
  }

  Future<void> initNetwork() async {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null) return;

    final server = _ref.read(serverServiceProvider);
    final cloudSync = _ref.read(cloudSyncServiceProvider);
    
    // Stop any active cloud sync background timer
    cloudSync.stopBackgroundSync();

    // DÉMARRAGE UNIVERSEL DU SERVEUR LOCAL :
    // Même en mode "Client", on lance le serveur local (127.0.0.1) 
    // pour que l'Afficheur Client (le 2ème écran) fonctionne sur ce PC.
    if (!server.isRunning) {
      await server.startServer();
    }

    if (settings.networkMode == NetworkMode.server || settings.networkMode == NetworkMode.solo) {
      _stopHeartbeat();
    } else if (settings.networkMode == NetworkMode.client) {
      _startHeartbeat();
      // Lancer la découverte automatique en tâche de fond avant de synchroniser
      autoDiscoverAndConfigure().then((_) {
        syncData();
      });
    } else if (settings.networkMode == NetworkMode.cloud) {
      _stopHeartbeat();
      cloudSync.startBackgroundSync();
      // Start an initial sync cycle in background
      cloudSync.runFullSyncCycle();
    } else {
      _stopHeartbeat();
    }
  }

  Future<void> autoDiscoverAndConfigure() async {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || settings.networkMode != NetworkMode.client) return;

    // Si on a déjà une IP configurée et que le serveur répond, on ne fait rien
    if (settings.serverIp.isNotEmpty) {
      final reachable = await isServerReachable();
      if (reachable) {
        debugPrint('📶 Serveur déjà configuré et joignable à ${settings.serverIp}:${settings.serverPort}');
        return;
      }
    }

    if (_isDiscovering) return;
    _isDiscovering = true;

    try {
      debugPrint('🔎 Lancement de l\'auto-découverte invisible du serveur en arrière-plan...');
      final servers = await discoverServers();
      if (servers.isNotEmpty) {
        final serverInfo = servers.first;
        final ip = serverInfo['ip']!;
        final port = int.tryParse(serverInfo['port'] ?? '8080') ?? 8080;
        
        debugPrint('🟢 Serveur trouvé automatiquement : $ip:$port (${serverInfo['name']})');
        
        // Sauvegarder automatiquement les nouveaux réglages du serveur
        final updated = settings.copyWith(
          serverIp: ip,
          serverPort: port,
        );
        await _ref.read(shopSettingsProvider.notifier).save(updated);
      } else {
        debugPrint('⚠️ Aucun serveur Danaya+ trouvé via UDP broadcast.');
      }
    } finally {
      _isDiscovering = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final reachable = await isServerReachable();
      final wasReachable = _ref.read(serverReachabilityProvider);
      
      _ref.read(serverReachabilityProvider.notifier).setReachability(reachable);

      // Si on vient de se reconnecter, lancer le rattrapage des ventes
      if (reachable && !wasReachable) {
        debugPrint('📶 Reconnexion détectée ! Lancement du rattrapage...');
        _ref.read(clientSyncProvider).syncPendingSales();
        // Optionnel : Re-synchroniser aussi les produits
        syncData();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _ref.read(serverReachabilityProvider.notifier).setReachability(false);
  }

  Future<bool> isServerReachable() async {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings == null || settings.networkMode != NetworkMode.client) return false;
    
    try {
      final response = await http.get(
        Uri.parse('http://${settings.serverIp}:${settings.serverPort}/health'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Recherche tous les serveurs Danaya+ sur le réseau via UDP Broadcast
  Future<List<Map<String, String>>> discoverServers() async {
    RawDatagramSocket? socket;
    final List<Map<String, String>> discovered = [];
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      debugPrint('🔎 Recherche de serveurs Danaya+ en cours...');
      final data = utf8.encode('DANAYA_DISCOVER');
      socket.send(data, InternetAddress('255.255.255.255'), 5555);

      final completer = Completer<List<Map<String, String>>>();
      
      // On attend 2 secondes pour collecter toutes les réponses du voisinage
      Timer(const Duration(seconds: 2), () {
        socket?.close();
        if (!completer.isCompleted) {
          completer.complete(discovered);
        }
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final response = utf8.decode(datagram.data, allowMalformed: true);
              if (response.startsWith('DANAYA_SERVER|')) {
                final parts = response.split('|');
                final serverInfo = {
                  'ip': parts[1],
                  'port': parts[2],
                  'name': parts[3],
                };
                
                // Eviter les doublons
                if (!discovered.any((s) => s['ip'] == serverInfo['ip'])) {
                  discovered.add(serverInfo);
                }
              }
            } catch (e) {
              debugPrint('⚠️ Erreur décodage découverte UDP: $e');
            }
          }
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('❌ Erreur lors de la découverte: $e');
      socket?.close();
      return discovered;
    }
  }

  // Ancienne méthode pour compatibilité (optionnel, mais on va tout migrer)
  Future<Map<String, String>?> discoverServer() async {
    final servers = await discoverServers();
    return servers.isNotEmpty ? servers.first : null;
  }

  /// Synchronise les données essentielles (Produits) si on est client
  Future<void> syncData() async {
    final settings = _ref.read(shopSettingsProvider).value;
    if (settings?.networkMode == NetworkMode.client) {
      debugPrint('🔄 Synchronisation automatique en cours...');
      await _ref.read(clientSyncProvider).syncUsersFromServer();
      await _ref.read(clientSyncProvider).syncProductsFromServer();
      await _ref.read(clientSyncProvider).syncPendingSales();
      
      // Connexion au WebSocket pour écouter les changements en temps réel
      _ref.read(clientSyncProvider).connectWebSocket();
    }
  }

  void listenToSettings() {
    if (_isListening) return;
    _isListening = true;
    _ref.listen(shopSettingsProvider, (previous, next) {
      if (next.value != null && previous?.value != next.value) {
        initNetwork();
      }
    });
  }
}
