import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/license/domain/license_service.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';

class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  final _keyController = TextEditingController();
  String _hid = "Chargement...";
  bool _isLoading = false;
  String? _errorMessage;
  int _logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHid();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadHid() async {
    final hid = await ref.read(licenseServiceProvider).getHardwareId();
    setState(() => _hid = hid);
  }

  void _handleActivate() async {
    if (_keyController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ref
        .read(licenseServiceProvider)
        .activateApp(_keyController.text);

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Clé d'activation invalide pour ce matériel.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── FONDS DÉGRADÉ DYNAMIQUE ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)],
              ),
            ),
          ),
          
          // Décorations subtiles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.03),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark 
                          ? Colors.white.withValues(alpha: 0.03) 
                          : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark 
                            ? Colors.white.withValues(alpha: 0.08) 
                            : Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo Tap for Secret Admin
                            GestureDetector(
                              onTap: () {
                                _logoTapCount++;
                                if (_logoTapCount >= 7) {
                                  _showAdminPasswordDialog();
                                  _logoTapCount = 0;
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.verified_user_rounded,
                                  size: 64,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              "Activation de Licence",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Veuillez activer votre copie de ${ref.watch(shopSettingsProvider).value?.name ?? 'Danaya+'} pour profiter de toutes les fonctionnalités.",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Hardware ID block
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "ID MATÉRIEL",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: theme.colorScheme.primary,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SelectableText(
                                          _hid,
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.copy_all_rounded, size: 20),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _hid));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("ID matériel copié !"),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // License Key input
                            EnterpriseWidgets.buildPremiumTextField(
                              context,
                              ctrl: _keyController,
                              label: "CLÉ D'ACTIVATION",
                              hint: "XXXX-XXXX-XXXX-XXXX",
                              icon: Icons.vpn_key_rounded,
                              onChanged: (_) => setState(() => _errorMessage = null),
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),

                            const SizedBox(height: 40),

                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _handleActivate,
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                      )
                                    : const Text(
                                        "ACTIVER MAINTENANT",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 32),
                            
                            // Info Footer
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 20, color: Colors.amber),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "L'ID matériel garantit que votre licence est unique à cet ordinateur.",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
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
                  ),
                ),
              ),
            ),
          ),
          
          // Bouton Retour
          if (Navigator.canPop(context))
            Positioned(
              top: 40,
              left: 40,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                padding: const EdgeInsets.all(16),
              ),
            ),
        ],
      ),
    );
  }

  void _showAdminPasswordDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Accès Développeur",
        icon: Icons.admin_panel_settings_rounded,
        actions: const [],
        child: Column(
          children: [
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: passController,
              label: "Mot de passe Maître",
              hint: "••••••••",
              icon: Icons.lock_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    if (passController.text == "www.Diarra9869.com") {
                      Navigator.pop(context);
                      _showAdminPinDialog();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Accès refusé.")),
                      );
                    }
                  },
                  child: const Text("Suivant"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Vérification PIN",
        icon: Icons.security_rounded,
        actions: const [],
        child: Column(
          children: [
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: pinController,
              label: "Code PIN",
              hint: "••••",
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    if (pinController.text == "9869") {
                      Navigator.pop(context);
                      _showAdminPanel();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("PIN Incorrect.")),
                      );
                    }
                  },
                  child: const Text("Déverrouiller"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminPanel() {
    final clientHidController = TextEditingController(text: _hid);
    String selectedType = "Y1";
    String generatedKey = "";
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => EnterpriseWidgets.buildPremiumDialog(
          context,
          title: "Générateur de Clés",
          icon: Icons.key_rounded,
          width: 500,
          actions: const [],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: clientHidController,
                label: "Hardware ID Client",
                icon: Icons.computer_rounded,
              ),
              const SizedBox(height: 16),
              EnterpriseWidgets.buildPremiumDropdown<String>(
                label: "DURÉE DE LICENCE",
                value: selectedType,
                icon: Icons.timer_rounded,
                items: const ["D7", "M1", "M3", "M6", "Y1", "Y2", "Y3", "INF"],
                itemLabel: (v) {
                  switch (v) {
                    case "D7": return "Essai (7 Jours)";
                    case "M1": return "1 Mois";
                    case "M3": return "3 Mois";
                    case "M6": return "6 Mois";
                    case "Y1": return "1 An (Standard)";
                    case "Y2": return "2 Ans";
                    case "Y3": return "3 Ans";
                    case "INF": return "Illimité (Gold)";
                    default: return v;
                  }
                },
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              if (generatedKey.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  "Clé Générée :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary),
                  ),
                  child: SelectableText(
                    generatedKey,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Fermer"),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final key = ref
                          .read(licenseServiceProvider)
                          .generateLicenseKey(clientHidController.text, selectedType);
                      setDialogState(() => generatedKey = key);
                    },
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text("GÉNÉRER"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
