import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/theme/theme_provider.dart';
import 'package:danaya_plus/features/license/domain/license_service.dart';
import 'package:danaya_plus/features/license/presentation/license_screen.dart';
import 'package:danaya_plus/features/auth/presentation/login_screen.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/settings/presentation/setup_wizard_screen.dart';
import 'package:danaya_plus/features/settings/providers/backup_providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:danaya_plus/core/network/network_service.dart';
import 'package:danaya_plus/core/services/stock_alert_service.dart';
import 'package:danaya_plus/core/services/scheduled_report_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:flutter/services.dart';
import 'package:danaya_plus/core/services/marketing_automation_service.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:danaya_plus/core/widgets/safety_screen.dart'; // [NOUVEAU]
import 'package:danaya_plus/core/widgets/auto_lock_wrapper.dart'; // [NOUVEAU]
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';
import 'dart:ui';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🧹 OPTIMISATION RAM (Audit Extrême) - Limite le cache d'images pour les petites machines Windows
  PaintingBinding.instance.imageCache.maximumSize = 150; // max 150 images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024; // max 40 MB de RAM pour les images

  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  
  await windowManager.ensureInitialized();
  // Suppression du hide() initial qui peut causer des bugs de 'disparition' sur certaines versions de Windows
  await windowManager.setPreventClose(true);
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('fr', null);

  // 📄 PRÉ-CHARGEMENT DES RESSOURCES PDF (Optimisation Performance)
  // Charge les polices en mémoire dès le démarrage pour des aperçus instantanés
  try {
    // ignore: unawaited_futures
    Future.microtask(() => PdfResourceService.instance.preload());
  } catch (e) {
    debugPrint("⚠️ Erreur pré-chargement PDF: $e");
  }
  
  final container = ProviderContainer();
  
  // 🛡️ SUPREME GLOBAL ERROR GUARD (Phase Audit)
  // Intercepter les erreurs d'interface (UI rendering/logic)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logFatalError(container, details.exception, details.stack);
  };

  // Intercepter les exceptions asynchrones (Futures/Network/Compute)
  PlatformDispatcher.instance.onError = (error, stack) {
    _logFatalError(container, error, stack);
    return true;
  };

  // Remplacer l'écran "Red Screen of Death" par notre SafetyScreen premium
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return SafetyScreen(error: details.exception, stackTrace: details.stack);
  };

  // Configuration Initiale de la Fenêtre
  await windowManager.waitUntilReadyToShow(const WindowOptions(
    title: "Danaya+ - Gestion de Stock Pro",
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    minimumSize: Size(900, 600), // Prevent rendering errors on small windows
  ));

  // Enforce minimum size at the OS level (prevents user from dragging too small)
  await windowManager.setMinimumSize(const Size(900, 600));

  runApp(UncontrolledProviderScope(
    container: container,
    child: AutoLockWrapper(
      child: AppWindowListener(container: container, child: const GestionStockApp()),
    ),
  ));
}

/// Helper pour journaliser les crashs critiques dans l'audit forensic
void _logFatalError(ProviderContainer container, Object error, StackTrace? stack) {
  try {
    container.read(databaseServiceProvider).logActivity(
      actionType: 'CRITICAL_ERROR',
      description: "FATAL: ${error.toString().split('\n').first}",
      entityType: 'SYSTEM_CRASH',
      metadata: {
        'error': error.toString(),
        'stack': stack?.toString().split('\n').take(10).join('\n'), // Top 10 frames
        'platform': 'windows',
        'date': DateTime.now().toIso8601String(),
      },
    );
  } catch (e) {
    debugPrint("Failed to log fatal error: $e");
  }
}

class AppWindowListener extends StatefulWidget {
  final Widget child;
  final ProviderContainer container;
  const AppWindowListener({super.key, required this.child, required this.container});

  @override
  State<AppWindowListener> createState() => _AppWindowListenerState();
}

class _AppWindowListenerState extends State<AppWindowListener> with WindowListener {
  bool _isTransitioning = false; // Guard against race conditions

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    debugPrint("🚨 Interception de la fermeture de fenêtre...");
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      final activeSession = widget.container.read(activeSessionProvider).value;
      
      if (activeSession != null) {
        if (!mounted) return;
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 12),
                  Text("Action Bloquée"),
                ],
              ),
              content: const Text(
                "Une session de caisse est actuellement ouverte.\n\n"
                "Pour des raisons de sécurité et d'audit, vous devez obligatoirement fermer la caisse avant de quitter l'application.",
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("COMPRIS"),
                ),
              ],
            ),
          );
        }
      } else {
        // Sortie propre pour éviter les processus fantômes ou les crashs de transition
        exit(0);
      }
    }
  }

  /// Handle leaving fullscreen via Windows title bar buttons (restore/maximize)
  @override
  void onWindowUnmaximize() {
    debugPrint("🪟 Window unmaximized - adjusting layout...");
    _ensureVisibility();
  }

  @override
  void onWindowRestore() {
    debugPrint("🪟 Window restored - adjusting layout...");
    _ensureVisibility();
  }

  Future<void> _ensureVisibility() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await windowManager.show();
    await windowManager.focus();
    await _ensureMinimumWindowSize();
  }

  /// Ensure the window has a sane minimum size after state transitions
  Future<void> _ensureMinimumWindowSize() async {
    try {
      final size = await windowManager.getSize();
      // If window is unreasonably small after a transition, fix it
      if (size.width < 800 || size.height < 500) {
        await windowManager.setSize(const Size(1280, 800));
        await windowManager.center();
      }
    } catch (e) {
      debugPrint("⚠️ Window size check failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
          if (_isTransitioning) return KeyEventResult.handled; // Block spamming
          _isTransitioning = true;

          windowManager.isFullScreen().then((isFull) async {
            try {
              if (isFull) {
                // EXIT FULLSCREEN
                await windowManager.setFullScreen(false);
                await Future.delayed(const Duration(milliseconds: 200));
                await windowManager.setSize(const Size(1280, 800));
                await windowManager.center();
                await windowManager.show(); // Forcer la visibilité
                await windowManager.focus(); // Rendre le focus
              } else {
                await windowManager.setFullScreen(true);
                await windowManager.show();
                await windowManager.focus();
              }
            } finally {
              // Allow next transition after a cooldown
              Future.delayed(const Duration(milliseconds: 500), () {
                _isTransitioning = false;
              });
            }
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

final initProvider = FutureProvider<bool>((ref) async {
  final licenseService = ref.read(licenseServiceProvider);
  return await licenseService.isAppActivated();
});

class GestionStockApp extends ConsumerStatefulWidget {
  const GestionStockApp({super.key});

  @override
  ConsumerState<GestionStockApp> createState() => _GestionStockAppState();
}

class _GestionStockAppState extends ConsumerState<GestionStockApp> {
  static bool _windowShown = false; // CRITICAL: Only show window ONCE in the app lifetime
  bool _networkInitialized = false;

  /// Show the window only once during app startup  
  void _showWindowReadyOnce() async {
    if (_windowShown) return; // Guard: Never re-force fullscreen after first show
    _windowShown = true;

    try {
      // 1. D'abord rendre la fenêtre visible pour que Windows crée l'icône de barre des tâches
      await windowManager.show();
      
      // 2. Ensuite passer en plein écran si nécessaire
      final isFullScreen = await windowManager.isFullScreen();
      if (!isFullScreen) {
        await windowManager.setFullScreen(true);
      }
      
      await windowManager.focus();
    } catch (e) {
      debugPrint("⚠️ Window show error: $e");
    }
    FlutterNativeSplash.remove();
  }

  @override
  void initState() {
    super.initState();
    
    // SÉCURITÉ STARTUP : Forcer l'affichage après 5 secondes max
    // (Utile si la DB ou les settings mettent trop de temps)
    // Runs only ONCE (initState is called once per widget lifetime)
    Future.delayed(const Duration(seconds: 5), () {
      _showWindowReadyOnce();
    });
  }

  @override
  Widget build(BuildContext context) {
    final initAsync = ref.watch(initProvider);
    final selectedTheme = ref.watch(themeNotifierProvider);
    final settings = ref.watch(shopSettingsProvider).value;
    final appName = settings?.name ?? 'Danaya+';

    // Listen for init completion to show window (only fires meaningfully once due to guard)
    ref.listen<AsyncValue<bool>>(initProvider, (previous, next) {
      if (next.hasValue || next.hasError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWindowReadyOnce();
        });
      }
    });

    // Initialisation du réseau (une seule fois)
    if (!_networkInitialized) {
      _networkInitialized = true;
      Future.microtask(() {
        ref.read(networkServiceProvider).listenToSettings();
        ref.read(networkServiceProvider).initNetwork();
      });
    }

    // Déclencher la sauvegarde automatique et l'alerte stock une seule fois lors du chargement initial des paramètres
    ref.listen<AsyncValue<ShopSettings?>>(shopSettingsProvider, (previous, next) {
      if (previous?.value == null && next.value != null) {
        ref.read(backupServiceProvider).triggerAutoBackup();
        ref.read(stockAlertServiceProvider).checkAndSendAlert();
        ref.read(scheduledReportServiceProvider).checkAndSendReport();
        ref.read(marketingAutomationServiceProvider).runDailyInactivityAudit();
      }
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(selectedTheme.color, Brightness.light),
      darkTheme: AppTheme.getTheme(selectedTheme.color, Brightness.dark),
      themeMode: selectedTheme.mode,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: initAsync.when(
        data: (isActivated) {
          if (isActivated) {
            final isConfigured = settings?.isConfigured ?? false;
            
            if (isConfigured) {
              // AUTH GATE RÉACTIF : Redirection automatique selon l'état de l'utilisateur
              final authAsync = ref.watch(authServiceProvider);
              
              return authAsync.maybeWhen(
                data: (user) {
                  if (user != null) {
                    return const DashboardScreen();
                  } else {
                    return const LoginScreen();
                  }
                },
                // On ne montre le loader que si on n'est pas déjà sur un écran stable (Login/Dashboard)
                // ou si c'est le premier chargement.
                loading: () => authAsync.hasValue ? (authAsync.value == null ? const LoginScreen() : const DashboardScreen()) : const Scaffold(body: Center(child: CircularProgressIndicator())),
                // En cas d'erreur de connexion, on RESTE sur la LoginScreen pour que l'utilisateur voie la SnackBar
                orElse: () => const LoginScreen(),
              );
            } else {
              return const SetupWizardScreen();
            }
          } else {
            return const LicenseScreen();
          }
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red.shade900, Colors.black],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 80),
                const SizedBox(height: 24),
                const Text(
                  "ÉCHEC DE Lancement",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 16),
                Text(
                  "Une erreur critique est survenue lors de l'initialisation des composants système.\n\n"
                  "Détails : $error",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    // Force refresh via le provider (si possible) ou restart app
                    ref.invalidate(initProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("TENTER DE REDÉMARRER"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text("QUITTER", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
