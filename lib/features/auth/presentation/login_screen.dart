import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/widgets/premium_background.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/license/presentation/license_screen.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/network_service.dart';
import 'package:danaya_plus/core/network/cloud_sync_service.dart';
import 'package:danaya_plus/core/services/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour charger uniquement les utilisateurs actifs
final _activeLoginUsersProvider = FutureProvider<List<_LoginUser>>((ref) async {
  final db = await ref.read(databaseServiceProvider).database;
  final maps = await db.query(
    'users',
    columns: ['id', 'username', 'first_name', 'last_name', 'is_active'],
    where: 'is_active = 1',
    orderBy: 'username ASC',
  );
  return maps.map((m) => _LoginUser(
    id: m['id'] as String,
    username: m['username'] as String,
    firstName: m['first_name'] as String?,
    lastName: m['last_name'] as String?,
  )).toList();
});

class _LoginUser {
  final String id;
  final String username;
  final String? firstName;
  final String? lastName;

  _LoginUser({required this.id, required this.username, this.firstName, this.lastName});

  String get displayName {
    if ((firstName != null && firstName!.isNotEmpty) || (lastName != null && lastName!.isNotEmpty)) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return username;
  }

  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      final first = firstName![0].toUpperCase();
      if (lastName != null && lastName!.isNotEmpty) {
        return '$first${lastName![0].toUpperCase()}';
      }
      return first;
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePin = true;
  _LoginUser? _selectedUser;
  bool _isSwitchingUser = false; // Mode sélection d'utilisateur ouvert

  // Variables pour le triple clic
  int _tapCount = 0;
  DateTime? _lastTapTime;

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
    _loadLastUser();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundServiceProvider).playTest();
    });
  }
  
  Future<void> _loadLastUser() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUsername = prefs.getString('last_logged_in_username');
    
    if (lastUsername != null && mounted) {
      // On attend que les utilisateurs soient chargés par le provider
      final usersList = await ref.read(_activeLoginUsersProvider.future);
      try {
        final lastUser = usersList.firstWhere((u) => u.username == lastUsername);
        if (mounted) {
          setState(() {
            _selectedUser = lastUser;
          });
        }
      } catch (e) {
        // Utilisateur non trouvé ou supprimé
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez sélectionner un utilisateur.")),
        );
        return;
      }
      final username = _selectedUser!.username;
      final pin = _pinController.text;
      
      ref.read(soundServiceProvider).playScanSuccess();
      
      // Sauvegarder l'utilisateur pour la prochaine fois
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_logged_in_username', username);
      
      await ref.read(authServiceProvider.notifier).login(username, pin);
    }
  }

  void _handleProfileTap() {
    final now = DateTime.now();
    // Si le dernier clic remonte à plus de 600ms, on réinitialise le compteur
    if (_lastTapTime == null || now.difference(_lastTapTime!).inMilliseconds > 600) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 3) {
      _tapCount = 0;
      ref.read(soundServiceProvider).playScanSuccess();
      setState(() => _isSwitchingUser = true);
    }
  }

  // Couleurs d'avatar

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF97316), // Orange
    ];
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authServiceProvider);
    final settings = ref.watch(shopSettingsProvider).value;
    final usersAsync = ref.watch(_activeLoginUsersProvider);

    ref.listen<AsyncValue>(authServiceProvider, (previous, next) {
      next.whenOrNull(error: (error, stackTrace) {
        if (mounted) {
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
          const Positioned.fill(
            child: PremiumAnimatedBackground(),
          ),
          
          Row(
            children: [
              // ── ZONE GAUCHE (BRANDING) ──
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
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDark
                                            ? [
                                                Colors.white.withValues(alpha: 0.08),
                                                Colors.white.withValues(alpha: 0.02),
                                              ]
                                            : [
                                                Colors.black.withValues(alpha: 0.04),
                                                Colors.black.withValues(alpha: 0.01),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                                        width: 1.2,
                                      ),
                                      boxShadow: isDark
                                          ? [
                                              BoxShadow(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                                blurRadius: 24,
                                                spreadRadius: -4,
                                              )
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.03),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              )
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: theme.colorScheme.primary,
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                                blurRadius: 6,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            settings!.slogan,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.9)
                                                  : Colors.black.withValues(alpha: 0.85),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.7,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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
                                const SizedBox(height: 40),
                                
                                // PROFIL MEMORISÉ OU DROPDOWN
                                usersAsync.when(
                                  data: (users) {
                                    if (users.isEmpty) {
                                      return const Text("Aucun utilisateur disponible.", style: TextStyle(color: Colors.red));
                                    }
                                    
                                    // Init avec le premier si aucun n'a été mémorisé (et forcer le menu)
                                    if (_selectedUser == null) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted && _selectedUser == null) {
                                          setState(() {
                                            _selectedUser = users.first;
                                            _isSwitchingUser = true;
                                          });
                                        }
                                      });
                                    }

                                    return AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      child: _isSwitchingUser || _selectedUser == null
                                          ? _buildPremiumDropdown(
                                              context,
                                              users: users,
                                              selected: _selectedUser,
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedUser = val;
                                                  _isSwitchingUser = false; // Ferme le mode sélection
                                                  _pinController.clear();
                                                });
                                              },
                                            )
                                          : _buildProfileCard(context, _selectedUser!),
                                    );
                                  },
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (err, _) => Text("Erreur: $err", style: const TextStyle(color: Colors.red)),
                                ),

                                const SizedBox(height: 24),
                                
                                // CODE PIN
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
                                
                                // BOUTON ACCÈS
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
                                
                                // OPTIONS INFÉRIEURES
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

  // Affiche un profil mémorisé de manière très discrète et premium
  Widget _buildProfileCard(BuildContext context, _LoginUser user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _avatarColor(user.username);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleProfileTap,
          borderRadius: BorderRadius.circular(100), // Forme de pilule
          child: Container(
            key: const ValueKey('profile_card_discreet'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini-Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nom & Username
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w800, 
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87
                      ),
                    ),
                    Text(
                      "@${user.username}",
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w600, 
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Icone de changement (Chevron) au lieu d'un gros bouton
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FluentIcons.arrow_swap_20_regular, 
                    size: 14, 
                    color: isDark ? Colors.white70 : Colors.black54
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Affiche le dropdown pour changer d'utilisateur
  Widget _buildPremiumDropdown(
    BuildContext context, {
    required List<_LoginUser> users,
    required _LoginUser? selected,
    required void Function(_LoginUser?) onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      key: const ValueKey('dropdown'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "SÉLECTIONNER UN UTILISATEUR",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            // Si on avait un utilisateur avant, on peut annuler le changement
            if (selected != null)
              InkWell(
                onTap: () => setState(() => _isSwitchingUser = false),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(FluentIcons.dismiss_24_regular, size: 16, color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<_LoginUser>(
          initialValue: selected,
          onChanged: onChanged,
          items: users.map((u) {
            final color = _avatarColor(u.username);
            return DropdownMenuItem<_LoginUser>(
              value: u,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      u.initials,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    u.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
            );
          }).toList(),
          icon: const Icon(FluentIcons.chevron_down_24_regular, size: 20),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildLogo(ShopSettings? settings, ThemeData theme) {
    final hasLogo = settings?.logoPath != null && settings!.logoPath!.isNotEmpty && File(settings.logoPath!).existsSync();
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
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
    final cloudSyncKeyController = TextEditingController(text: settingsValue.cloudSyncKey);
    final cloudEndpointController = TextEditingController(text: settingsValue.cloudEndpoint);
    NetworkMode selectedMode = settingsValue.networkMode == NetworkMode.solo
        ? NetworkMode.server
        : settingsValue.networkMode;
    List<Map<String, String>> discoveredServers = [];
    bool isScanning = false;
    bool isCloudValidating = false;

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
                      : (isDark ? theme.colorScheme.surface : const Color(0xFFF9FAFB)),
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
                modeCard(
                  mode: NetworkMode.cloud,
                  title: "Mode Distant (Cloud)",
                  subtitle: "Connexion et synchronisation à distance via le Cloud.",
                  icon: FluentIcons.cloud_24_regular,
                  color: Colors.purple,
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
                if (selectedMode == NetworkMode.cloud) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  EnterpriseWidgets.buildPremiumTextField(
                    context,
                    ctrl: cloudSyncKeyController,
                    label: "CLÉ CLOUD / BOUTIQUE ID",
                    hint: "ex: danaya_magasin_1",
                    icon: FluentIcons.key_24_regular,
                  ),
                  const SizedBox(height: 16),
                  EnterpriseWidgets.buildPremiumTextField(
                    context,
                    ctrl: cloudEndpointController,
                    label: "URL DU CLOUD FIREBASE",
                    hint: "https://votre-projet.firebaseio.com",
                    icon: FluentIcons.cloud_24_regular,
                  ),
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
                onPressed: isCloudValidating ? null : () async {
                  final ip = ipController.text.trim();
                  final key = cloudSyncKeyController.text.trim();
                  final endpoint = cloudEndpointController.text.trim();

                  if (selectedMode == NetworkMode.cloud) {
                    if (key.isEmpty || endpoint.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Veuillez remplir la clé Cloud et l'URL."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isCloudValidating = true);

                    try {
                      final syncService = ref.read(cloudSyncServiceProvider);
                      final res = await syncService.validateCloudConnection(
                        endpoint: endpoint,
                        key: key,
                      );

                      if (!context.mounted) return;

                      if (res != 'success') {
                        setDialogState(() => isCloudValidating = false);
                        
                        // Messages d'erreur clairs selon le type de problème
                        final String errorTitle;
                        final String errorMessage;
                        final IconData errorIcon;
                        final Color errorColor;
                        
                        if (res == 'not_found') {
                          errorTitle = "Clé Cloud Introuvable";
                          errorMessage = "La clé de boutique saisie n'existe pas sur ce serveur Cloud.\n\n"
                              "• Vérifiez l'orthographe exacte de votre clé\n"
                              "• Assurez-vous que la boutique a déjà été enregistrée depuis le poste principal";
                          errorIcon = Icons.search_off_rounded;
                          errorColor = Colors.orange;
                        } else if (res.startsWith('error:')) {
                          errorTitle = "Erreur de Connexion";
                          errorMessage = res.substring(6);
                          errorIcon = Icons.wifi_off_rounded;
                          errorColor = Colors.red;
                        } else {
                          errorTitle = "Erreur";
                          errorMessage = res;
                          errorIcon = Icons.error_outline_rounded;
                          errorColor = Colors.red;
                        }
                        
                        showDialog(
                          context: context,
                          builder: (errCtx) => AlertDialog(
                            backgroundColor: Theme.of(errCtx).colorScheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                Icon(errorIcon, color: errorColor, size: 28),
                                const SizedBox(width: 12),
                                Expanded(child: Text(errorTitle)),
                              ],
                            ),
                            content: Text(
                              errorMessage,
                              style: const TextStyle(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(errCtx),
                                child: const Text("COMPRIS"),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                    } catch (_) {
                      setDialogState(() => isCloudValidating = false);
                      return;
                    }
                  }

                  final updated = settingsValue.copyWith(
                    networkMode: selectedMode,
                    serverIp: ip,
                    cloudSyncKey: key,
                    cloudEndpoint: endpoint,
                  );
                  await ref.read(shopSettingsProvider.notifier).save(updated);
                  if (context.mounted) Navigator.pop(context);
                },
                child: isCloudValidating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("APPLIQUER"),
              ),
            ],
          );
        },
      ),
    );
  }
}
