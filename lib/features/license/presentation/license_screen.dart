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
    String selectedLicenseType = "STANDARD";
    String generatedKey = "";
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isHidValid = clientHidController.text.trim().replaceAll(RegExp(r'\s+|-'), '').length == 16;
          
          return EnterpriseWidgets.buildPremiumDialog(
            context,
            title: "Console de Génération Danaya AI",
            icon: Icons.admin_panel_settings_rounded,
            width: 580,
            actions: const [],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // INFO HEADER DE DEV
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.terminal_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "DEVELOPER EDITION - Génération cryptographique de clés sécurisées par empreinte matérielle.",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // HID INPUT AND AUTO-FILL
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: clientHidController,
                        label: "Hardware ID Client (HID)",
                        hint: "16 caractères (ex: B4F8C9E7D2A1B0C3)",
                        icon: Icons.computer_rounded,
                        onChanged: (val) {
                          setDialogState(() {
                            generatedKey = "";
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 52,
                      margin: const EdgeInsets.only(bottom: 2),
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          setDialogState(() {
                            clientHidController.text = _hid;
                            generatedKey = "";
                          });
                        },
                        icon: const Icon(Icons.my_location_rounded, size: 16),
                        label: const Text("Mon HID", style: TextStyle(fontSize: 11)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // HID VALIDATION ALERTS
                if (clientHidController.text.isNotEmpty && !isHidValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          "Le HID doit faire exactement 16 caractères (actuel: ${clientHidController.text.trim().replaceAll(RegExp(r'\s+|-'), '').length})",
                          style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // LICENSE TYPE SELECTOR (WITH RICH BADGES AND DESCRIPTIONS)
                Text(
                  "TYPE DE LICENCE À GÉNÉRER",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeCard(
                        title: "Logiciel Standard",
                        subtitle: "Accès ERP complet hors-ligne",
                        icon: Icons.widgets_outlined,
                        color: theme.colorScheme.primary,
                        isSelected: selectedLicenseType == "STANDARD",
                        onTap: () => setDialogState(() {
                          selectedLicenseType = "STANDARD";
                          generatedKey = "";
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeCard(
                        title: "Danaya AI (Labs)",
                        subtitle: "Moteurs & assistant intelligent",
                        icon: Icons.psychology_outlined,
                        color: Colors.amber,
                        isSelected: selectedLicenseType == "LABS",
                        onTap: () => setDialogState(() {
                          selectedLicenseType = "LABS";
                          generatedKey = "";
                        }),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // DURATION SELECTOR WITH PREMIUM DROPDOWN
                EnterpriseWidgets.buildPremiumDropdown<String>(
                  label: "DURÉE DE LA LICENCE",
                  value: selectedType,
                  icon: Icons.timer_rounded,
                  items: const ["D7", "M1", "M3", "M6", "Y1", "Y2", "Y3", "INF"],
                  itemLabel: (v) {
                    switch (v) {
                      case "D7": return "Essai Gratuit (7 Jours)";
                      case "M1": return "Abonnement Mensuel (1 Mois)";
                      case "M3": return "Abonnement Trimestriel (3 Mois)";
                      case "M6": return "Abonnement Semestriel (6 Mois)";
                      case "Y1": return "Licence Annuelle (1 An)";
                      case "Y2": return "Licence Bisannuelle (2 Ans)";
                      case "Y3": return "Licence Trisannuelle (3 Ans)";
                      case "INF": return "Licence Illimitée (Gold)";
                      default: return v;
                    }
                  },
                  onChanged: (v) => setDialogState(() {
                    selectedType = v!;
                    generatedKey = "";
                  }),
                ),
                
                // GENERATED KEY PANEL
                if (generatedKey.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: selectedLicenseType == "LABS"
                            ? [Colors.amber.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)]
                            : [theme.colorScheme.primary.withValues(alpha: 0.15), theme.colorScheme.secondary.withValues(alpha: 0.05)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedLicenseType == "LABS" ? Colors.amber : theme.colorScheme.primary,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (selectedLicenseType == "LABS" ? Colors.amber : theme.colorScheme.primary).withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selectedLicenseType == "LABS" ? Icons.auto_awesome : Icons.check_circle_rounded,
                              size: 16,
                              color: selectedLicenseType == "LABS" ? Colors.amber.shade700 : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedLicenseType == "LABS" ? "CLÉ LABS / IA GÉNÉRÉE" : "CLÉ APPLICATION STANDARD GÉNÉRÉE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: selectedLicenseType == "LABS" ? Colors.amber.shade800 : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          generatedKey,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                            color: selectedLicenseType == "LABS" 
                                ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                                : (isDark ? Colors.blue.shade200 : Colors.blue.shade900),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: generatedKey));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Clé copiée dans le presse-papiers !"),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_all_rounded, size: 16),
                              label: const Text("Copier la clé", style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // ACTIONS BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Fermer"),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: !isHidValid
                          ? null
                          : () {
                              final service = ref.read(licenseServiceProvider);
                              final key = selectedLicenseType == "LABS"
                                  ? service.generateLabsLicenseKey(clientHidController.text.trim().replaceAll(RegExp(r'\s+|-'), ''), selectedType)
                                  : service.generateLicenseKey(clientHidController.text.trim().replaceAll(RegExp(r'\s+|-'), ''), selectedType);
                              
                              final formatted = [];
                              for (int i = 0; i < key.length; i += 5) {
                                if (i + 5 <= key.length) {
                                  formatted.add(key.substring(i, i + 5));
                                } else {
                                  formatted.add(key.substring(i));
                                }
                              }
                              
                              setDialogState(() {
                                generatedKey = formatted.join('-');
                              });
                            },
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text("GÉNÉRER LA CLÉ"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isSelected ? color : (isDark ? Colors.white38 : Colors.black38), size: 24),
                if (isSelected)
                  Icon(Icons.radio_button_checked_rounded, color: color, size: 18)
                else
                  Icon(Icons.radio_button_off_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected 
                    ? (isDark ? Colors.white : Colors.black87) 
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
