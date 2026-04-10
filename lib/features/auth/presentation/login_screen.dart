import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/widgets/premium_background.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/license/presentation/license_screen.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/network_service.dart';
import 'package:danaya_plus/core/services/sound_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController(text: 'Administrateur');
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePin = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // ── SON D'ACCUEIL PREMIUM ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundServiceProvider).playTest(); // Petit son de 'ping' à l'ouverture
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final pin = _pinController.text;
      
      // Son de clic premium
      ref.read(soundServiceProvider).playScanSuccess();
      
      await ref.read(authServiceProvider.notifier).login(username, pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authServiceProvider);
    final settings = ref.watch(shopSettingsProvider).value;

    ref.listen<AsyncValue>(authServiceProvider, (previous, next) {
      next.whenOrNull(error: (error, stackTrace) {
        if (mounted) {
          // Jouer le son d'erreur
          ref.read(soundServiceProvider).playScanError();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 6),
              content: Row(
                children: [
                  const Icon(FluentIcons.warning_24_regular, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Échec de connexion", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        Text(
                          error.toString().length > 80 ? "Une erreur inattendue est survenue." : error.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(children: [
                            Icon(FluentIcons.bug_24_regular, color: Colors.orange),
                            SizedBox(width: 10),
                            Text("Rapport Technique"),
                          ]),
                          content: SelectableText(error.toString(), style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")),
                          ],
                        ),
                      );
                    },
                    child: const Text("Détails", style: TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── ARRIÈRE-PLAN ANIMÉ (GLOBAL) ──
          const Positioned.fill(
            child: PremiumAnimatedBackground(),
          ),
          
          Row(
            children: [
              // ── ZONE GAUCHE (BRANDING & GLASS) ──
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(64.0),
                  child: EnterpriseWidgets.buildGlassContainer(
                    blur: 40,
                    opacity: isDark ? 0.1 : 0.15,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1), width: 1.5),
                    child: Stack(
                      children: [
                        Center(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLogo(settings, theme),
                                const SizedBox(height: 48),
                                Text(
                                  settings?.name.toUpperCase() ?? "DANAYA+",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (settings?.slogan.isNotEmpty ?? false)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      settings!.slogan,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.7),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Footer Branding
                        Positioned(
                          bottom: 40,
                          left: 40,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Row(
                              children: [
                                Icon(FluentIcons.shield_checkmark_24_regular, color: isDark ? Colors.white54 : Colors.black45, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  "Standard de Sécurité Enterprise v3.0",
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black45, 
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w600, 
                                    letterSpacing: 0.5
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── ZONE DROITE (CONNEXION) ──
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: EnterpriseWidgets.buildGlassContainer(
                        blur: 20,
                        opacity: isDark ? 0.05 : 0.08,
                        borderRadius: BorderRadius.circular(32),
                        padding: const EdgeInsets.all(40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Terminal de Vente",
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Authentification",
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                    letterSpacing: -1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Accédez à votre espace de travail sécurisé.",
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 48),
                                
                                // IDENTIFIANT
                                EnterpriseWidgets.buildPremiumTextField(
                                  context,
                                  ctrl: _usernameController,
                                  label: "UTILISATEUR",
                                  hint: "Nom d'utilisateur",
                                  icon: FluentIcons.person_24_regular,
                                  validator: (v) => v!.isEmpty ? "Nom requis" : null,
                                ),
                                const SizedBox(height: 24),
                                
                                // CODE PIN (Premium)
                                EnterpriseWidgets.buildPremiumTextField(
                                  context,
                                  ctrl: _pinController,
                                  label: "CODE PIN",
                                  hint: "••••",
                                  icon: FluentIcons.password_24_regular,
                                  obscureText: _obscurePin,
                                  suffix: IconButton(
                                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                    icon: Icon(_obscurePin ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? "PIN requis" : null,
                                  onSubmitted: (_) => _handleLogin(),
                                ),
                                
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      ref.read(soundServiceProvider).playScanSuccess();
                                      _showRecoveryDialog();
                                    },
                                    child: Text(
                                      "Mot de passe oublié ?",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // BOUTON ACCÈS (Premium)
                                EnterpriseWidgets.buildLockedButton(
                                  context,
                                  label: "DÉVERROUILLER L'ACCÈS",
                                  icon: FluentIcons.shield_keyhole_24_filled,
                                  isLoading: authState.isLoading,
                                  onPressed: _handleLogin,
                                ),
                                
                                const SizedBox(height: 48),
                                const Divider(),
                                const SizedBox(height: 24),
                                
                                // OPTIONS INFÉRIEURES (Réseau / Licence)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                    onPressed: () {
                                      ref.read(soundServiceProvider).playScanSuccess();
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LicenseScreen()));
                                    },
                                    icon: const Icon(FluentIcons.key_24_regular, size: 18),
                                    label: const Text("Licence", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                    IconButton(
                                    onPressed: () {
                                      ref.read(soundServiceProvider).playScanSuccess();
                                      _showNetworkSettingsDialog();
                                    },
                                    icon: Icon(FluentIcons.settings_24_regular, color: isDark ? Colors.white70 : Colors.black54),
                                    tooltip: "Réglages Réseau",
                                      style: IconButton.styleFrom(
                                        backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogo(ShopSettings? settings, ThemeData theme) {
    final hasLogo = settings?.logoPath != null && settings!.logoPath!.isNotEmpty && File(settings.logoPath!).existsSync();
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(
          color: (isDark ? Colors.white : theme.colorScheme.primary).withValues(alpha: 0.1), 
          width: 8
        ),
      ),
      padding: EdgeInsets.all(hasLogo ? 16 : 30),
      child: hasLogo
          ? ClipOval(
              child: Image.file(
                File(settings.logoPath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(theme),
              ),
            )
          : _buildFallbackIcon(theme),
    );
  }

  Widget _buildFallbackIcon(ThemeData theme) {
    return Icon(
      FluentIcons.lock_shield_48_filled,
      size: 60,
      color: theme.colorScheme.primary,
    );
  }

  void _showRecoveryDialog() {
    final keyCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => EnterpriseWidgets.buildPremiumDialog(
          context,
          title: "Récupération Super Admin",
          icon: FluentIcons.key_reset_24_filled,
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Utilisez votre clé de sécurité exclusive pour réinitialiser l'accès critique.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: keyCtrl,
                label: "CLÉ DE SECOURS",
                hint: "XXXX-XXXX-XXXX-XXXX",
                icon: FluentIcons.lock_shield_20_regular,
              ),
              const SizedBox(height: 20),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: newPinCtrl,
                label: "NOUVEAU PIN",
                hint: "4 chiffres",
                icon: FluentIcons.password_20_regular,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text("ANNULER"),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: isLoading ? null : () async {
                final key = keyCtrl.text.trim();
                final pin = newPinCtrl.text.trim();
                
                if (key.length < 16 || pin.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Format invalide. Vérifiez vos entrées."))
                  );
                  return;
                }

                setState(() => isLoading = true);
                final success = await ref.read(authServiceProvider.notifier).resetPinWithRecoveryKey(key, pin);
                
                if (context.mounted) {
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Accès rétabli avec succès ! ✅"), backgroundColor: Colors.green)
                    );
                  } else {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Clé d'accès refusée. ❌"), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("RÉTABLIR L'ACCÈS"),
            ),
          ],
        ),
      ),
    );
  }

  void _showNetworkSettingsDialog() {
    final settingsValue = ref.read(shopSettingsProvider).value;
    if (settingsValue == null) return;

    final ipController = TextEditingController(text: settingsValue.serverIp);
    NetworkMode selectedMode = settingsValue.networkMode == NetworkMode.solo
        ? NetworkMode.server
        : settingsValue.networkMode;
    List<Map<String, String>> discoveredServers = [];
    bool isScanning = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          Future<void> scan() async {
            setDialogState(() => isScanning = true);
            final servers = await ref.read(networkServiceProvider).discoverServers();
            setDialogState(() {
              discoveredServers = servers;
              isScanning = false;
            });
          }

          Widget modeCard({
            required NetworkMode mode,
            required String title,
            required String subtitle,
            required IconData icon,
            required Color color,
          }) {
            final selected = selectedMode == mode;
            return GestureDetector(
              onTap: () => setDialogState(() => selectedMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.1)
                      : (isDark ? const Color(0xFF1E2028) : const Color(0xFFF9FAFB)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? color : (isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: selected ? color : null)),
                          const SizedBox(height: 2),
                          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(FluentIcons.checkmark_circle_24_filled, color: color, size: 24),
                  ],
                ),
              ),
            );
          }

          return EnterpriseWidgets.buildPremiumDialog(
            context, 
            title: "Configuration Réseau", 
            icon: FluentIcons.network_check_24_regular,
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                modeCard(
                  mode: NetworkMode.server,
                  title: "Mode Serveur (Host)",
                  subtitle: "Machine principale gérant les données centralisées.",
                  icon: FluentIcons.server_24_regular,
                  color: theme.colorScheme.primary,
                ),
                modeCard(
                  mode: NetworkMode.client,
                  title: "Mode Client (Satellite)",
                  subtitle: "Machine secondaire se synchronisant au serveur.",
                  icon: FluentIcons.desktop_24_regular,
                  color: Colors.orange,
                ),

                if (selectedMode == NetworkMode.client) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  EnterpriseWidgets.buildPremiumTextField(
                    context,
                    ctrl: ipController,
                    label: "ADRESSE IP SERVEUR",
                    hint: "ex: 192.168.1.100",
                    icon: FluentIcons.router_24_regular,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: isScanning ? null : scan,
                    icon: isScanning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(FluentIcons.search_24_regular, size: 18),
                    label: Text(isScanning ? "RECHERCHE..." : "DÉTECTER AUTOMATIQUEMENT"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  if (discoveredServers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...discoveredServers.map((srv) => ListTile(
                      onTap: () => setDialogState(() => ipController.text = srv['ip'] ?? ''),
                      leading: const Icon(FluentIcons.server_24_regular, color: Colors.green),
                      title: Text(srv['name'] ?? 'Serveur Danaya+', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${srv['ip']}:${srv['port']}"),
                      trailing: const Icon(FluentIcons.add_circle_24_regular),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: ipController.text == srv['ip'] ? Colors.green.withValues(alpha: 0.1) : null,
                    )),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ANNULER"),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final updated = settingsValue.copyWith(
                    networkMode: selectedMode,
                    serverIp: ipController.text.trim(),
                  );
                  await ref.read(shopSettingsProvider.notifier).save(updated);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("APPLIQUER"),
              ),
            ],
          );
        },
      ),
    );
  }
}
