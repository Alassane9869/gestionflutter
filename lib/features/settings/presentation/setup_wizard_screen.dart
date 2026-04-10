import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/presentation/login_screen.dart';
import 'package:danaya_plus/core/network/network_service.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _acceptedTerms = false;

  final _nameCtrl = TextEditingController(text: 'Ma Boutique');
  final _currencyCtrl = TextEditingController(text: 'FCFA');
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  bool _useTax = false;
  final _taxNameCtrl = TextEditingController(text: 'TVA');
  final _taxRateCtrl = TextEditingController(text: '18.0');

  bool _useAutoRef = false;
  final _refPrefixCtrl = TextEditingController(text: 'REF');

  NetworkMode _networkMode = NetworkMode.solo;
  final _serverIpCtrl = TextEditingController();
  final _serverPortCtrl = TextEditingController(text: '8080');
  final _syncKeyCtrl = TextEditingController();
  bool _isSearching = false;

  String? _recoveryKey;
  bool _keySaved = false;

  // New Genie Edition Fields
  String? _logoPath;
  bool _isAiEnabled = true;
  bool _isVoiceEnabled = false;
  
  // Hardware Stats
  String _cpuInfo = "Prêt à scanner";
  String _ramInfo = "Prêt à scanner";
  bool _isHardwareChecked = false;
  bool _isPrinterTesting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _taxNameCtrl.dispose();
    _taxRateCtrl.dispose();
    _refPrefixCtrl.dispose();
    _serverIpCtrl.dispose();
    _serverPortCtrl.dispose();
    _syncKeyCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep == 0 && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous devez accepter les conditions d'utilisation pour continuer."), backgroundColor: Colors.red),
      );
      return;
    }

    if (_networkMode == NetworkMode.client && _currentStep == 1) {
        if (_serverIpCtrl.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez d'abord détecter le serveur Admin."), backgroundColor: Colors.red));
          return;
        }
        if (_syncKeyCtrl.text.length < 4) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez entrer une Clé de Synchro valide."), backgroundColor: Colors.red));
          return;
        }
        _pageController.animateToPage(6, duration: const Duration(milliseconds: 500), curve: Curves.fastOutSlowIn);
      return;
    }

    if (_currentStep < 8) {
      if (_currentStep == 5 && !_keySaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez confirmer que vous avez noté votre clé de secours."), backgroundColor: Colors.orange),
        );
        return;
      }
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final settings = ref.read(shopSettingsProvider).value ?? ShopSettings();
    final updated = settings.copyWith(
      name: _nameCtrl.text.trim(),
      currency: _currencyCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      useTax: _useTax,
      taxName: _taxNameCtrl.text.trim(),
      taxRate: double.tryParse(_taxRateCtrl.text) ?? 18.0,
      useAutoRef: _useAutoRef,
      refPrefix: _refPrefixCtrl.text.trim(),
      networkMode: _networkMode,
      serverIp: _serverIpCtrl.text.trim(),
      serverPort: int.tryParse(_serverPortCtrl.text) ?? 8080,
      syncKey: _networkMode == NetworkMode.client 
          ? _syncKeyCtrl.text.trim() 
          : (settings.syncKey.isEmpty ? ref.read(authServiceProvider.notifier).generateRecoveryKey().substring(0, 8) : settings.syncKey),
      acceptedTos: true,
      tosAcceptedAt: DateTime.now(),
      isConfigured: true,
      logoPath: _logoPath,
      isAiEnabled: _isAiEnabled,
      isVoiceEnabled: _isVoiceEnabled,
    );
    await ref.read(shopSettingsProvider.notifier).save(updated);

    if (_recoveryKey != null) {
      await ref.read(authServiceProvider.notifier).storeRecoveryToken('admin', _recoveryKey!);
    }
    
    if (_networkMode == NetworkMode.client) {
      await ref.read(clientSyncProvider).syncSettingsFromServer();
      await ref.read(clientSyncProvider).syncUsersFromServer();
      await ref.read(clientSyncProvider).syncProductsFromServer();
    }
    
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withValues(alpha: 0.9)],
                    ),
                  ),
                ),
                Positioned(
                  right: -100,
                  top: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        blur: 20,
                        opacity: 0.2,
                        borderRadius: BorderRadius.circular(24),
                        child: Icon(FluentIcons.glance_24_filled, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "GÉNIE EDITION\nDanaya+",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Bienvenue dans le futur de la gestion. Nous configurons ensemble votre écosystème intelligent.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Column(
                        children: [
                          _buildVisualProgress("Souveraineté", _currentStep >= 1),
                          _buildVisualProgress("Intelligence", _currentStep >= 7),
                          _buildVisualProgress("Performance", _currentStep >= 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            flex: 3,
            child: Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Row(
                    children: [
                      _buildStepIndicator(0, "Légal"),
                      _buildDivider(),
                      _buildStepIndicator(1, "Réseau"),
                      _buildDivider(),
                      _buildStepIndicator(2, "Identité"),
                      _buildDivider(),
                      _buildStepIndicator(3, "Fiscalité"),
                      _buildDivider(),
                      _buildStepIndicator(4, "Auto"),
                      _buildDivider(),
                      _buildStepIndicator(5, "Sécurité"),
                      _buildDivider(),
                      _buildStepIndicator(6, "Matériel"),
                      _buildDivider(),
                      _buildStepIndicator(7, "IA"),
                      _buildDivider(),
                      _buildStepIndicator(8, "Elite"),
                    ],
                  ),
                  const SizedBox(height: 60),
                  
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (v) => setState(() => _currentStep = v),
                      children: [
                        _stepTerms(),
                        _stepNetwork(),
                        _stepIdentity(),
                        _stepTaxation(),
                        _stepAutomation(),
                        _stepRecoveryKey(),
                        _stepHardware(),
                        _stepAiOptIn(),
                        _stepReady(),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          TextButton.icon(
                            onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                            icon: const Icon(FluentIcons.arrow_left_24_regular),
                            label: const Text("Retour"),
                          )
                        else
                          const SizedBox.shrink(),
                          
                        FilledButton.icon(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(_currentStep == 8 ? FluentIcons.checkmark_24_filled : FluentIcons.arrow_right_24_filled),
                          label: Text(
                            _currentStep == 8 ? "DÉMARRER" : "CONTINUER",
                            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTerms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Conditions d'Utilisation", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text("ELITE LEGAL", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text("Veuillez valider le cadre légal d'utilisation de Danaya+.", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(FluentIcons.warning_24_filled, color: Colors.orange, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ALERTE JURIDIQUE (MALI - LOI N° 2013-015)", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange, fontSize: 13, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      "En tant que commerçant, vous êtes le seul Responsable du Traitement des données privées de vos clients (APDP). Danaya+ est une forteresse 100% HORS-LIGNE : nous n'avons aucun accès à vos données. Vous devez OBLIGATOIREMENT sécuriser vos terminaux et faire vos propres sauvegardes sous peine de perte définitive.",
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(FluentIcons.shield_error_24_filled, color: Colors.red, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TOLÉRANCE ZÉRO CONTRE LE PIRATAGE", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 13, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      "Partager cette application avec des hackeurs pour obtenir une version 'gratuite' ou 'crackée' exposera L'INTÉGRALITÉ de votre entreprise au vol de données et au rançongiciel (Ransomware). Toute tentative de modification frauduleuse du code annulera vos garanties et entraînera des poursuites pénales immédiates devant les tribunaux compéttents.",
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13, height: 1.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTosSection("1. Souveraineté des Données (Offline-First)", 
                    "Danaya+ stocke 100% de vos données localement sur cet appareil. Aucune information n'est transmise à l'extérieur. Vous êtes seul propriétaire et garant de votre base de données."),
                  _buildTosSection("2. Responsabilité Critique des Sauvegardes", 
                    "Aucune récupération n'est possible par nos services en cas de panne matérielle ou vol sans sauvegarde préalable. L'utilisateur s'engage formellement à effectuer des copies régulières sur support externe."),
                  _buildTosSection("3. Licence & Propriété Intellectuelle", 
                    "Le droit d'usage est concédé pour un établissement. Le code source et les algorithmes IA restent la propriété exclusive de Danaya+ Software."),
                  _buildTosSection("4. Sécurité du Réseau (SyncKey)", 
                    "Vous êtes responsable de la confidentialité de votre Clé de Synchronisation. Tout accès non autorisé via le réseau local relève de la responsabilité de l'utilisateur."),
                  _buildTosSection("5. Limitation de Responsabilité (OHADA)", 
                    "Danaya+ décline toute responsabilité pour les pertes de profit, erreurs de saisie ou interruptions d'activité liées à une mauvaise utilisation ou un défaut matériel."),
                  _buildTosSection("6. Support & Maintenance", 
                    "Le support couvre les anomalies logicielles. La maintenance du matériel et du système Windows reste à la charge exclusive de l'utilisateur."),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        CheckboxListTile(
          value: _acceptedTerms,
          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          title: const Text("J'ai lu et j'accepte les conditions d'utilisation", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildTosSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.shield_24_regular, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _stepNetwork() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Configuration Réseau", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Comment comptez-vous utiliser Danaya+ sur cet ordinateur ?", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 40),
        
        _buildNetworkOption(
          mode: NetworkMode.solo,
          title: "POSTE UNIQUE (SOLO)",
          subtitle: "Utilisation classique sur un seul ordinateur, sans réseau.",
          icon: FluentIcons.laptop_24_regular,
        ),
        const SizedBox(height: 16),
        _buildNetworkOption(
          mode: NetworkMode.server,
          title: "POSTE PRINCIPAL (SERVEUR / ADMIN)",
          subtitle: "L'ordinateur chef qui stocke les données pour les autres.",
          icon: FluentIcons.server_24_regular,
        ),
        const SizedBox(height: 16),
        _buildNetworkOption(
          mode: NetworkMode.client,
          title: "POSTE CAISSIER (CLIENT)",
          subtitle: "Se connecte au poste principal pour enregistrer des ventes.",
          icon: FluentIcons.person_board_24_regular,
        ),
        const SizedBox(height: 16),
        _buildNetworkOption(
          mode: NetworkMode.client,
          title: "POSTE GESTIONNAIRE",
          subtitle: "Accès total au stock et fournisseurs via le serveur Admin.",
          icon: FluentIcons.clipboard_task_list_ltr_24_regular,
          isManagerOption: true,
        ),
        
        if (_networkMode == NetworkMode.client) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EnterpriseWidgets.buildPremiumTextField(
                  context, 
                  ctrl: _serverIpCtrl, 
                  label: "ADRESSE IP DU SERVEUR", 
                  hint: "Ex: 192.168.1.10", 
                  icon: FluentIcons.router_24_regular
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSearching ? null : _discoverServer,
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                  icon: _isSearching 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(FluentIcons.scan_24_regular),
                  label: const Text("DÉTECTION AUTO"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          EnterpriseWidgets.buildPremiumTextField(
            context, 
            ctrl: _syncKeyCtrl, 
            label: "CLÉ DE SYNCHRO (SYNC KEY)", 
            hint: "Requise pour l'authentification", 
            icon: FluentIcons.key_24_regular,
          ),
        ],
      ],
    );
  }

  Widget _buildNetworkOption({
    required NetworkMode mode, 
    required String title, 
    required String subtitle, 
    required IconData icon, 
    bool isManagerOption = false
  }) {
    final selected = _networkMode == mode && 
        ((isManagerOption && title.contains("GESTIONNAIRE")) || (!isManagerOption && !title.contains("GESTIONNAIRE")));
    
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
    
    return InkWell(
      onTap: () => setState(() => _networkMode = mode),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: selected ? 2 : 1),
          color: selected ? color.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: selected ? color : Colors.grey, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: selected ? color : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (selected) Icon(FluentIcons.checkmark_circle_24_filled, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _discoverServer() async {
    setState(() => _isSearching = true);
    final results = await ref.read(networkServiceProvider).discoverServers();
    
    if (!mounted) return;
    setState(() => _isSearching = false);

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun serveur trouvé. Vérifiez que l'Admin est allumé."), backgroundColor: Colors.orange),
      );
      return;
    }

    if (results.length == 1) {
      final result = results.first;
      setState(() {
        _serverIpCtrl.text = result['ip']!;
        _serverPortCtrl.text = result['port']!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Boutique détectée : ${result['name']} ✅"), backgroundColor: Colors.green),
      );
    } else {
      _showServerSelectionDialog(results);
    }
  }

  void _showServerSelectionDialog(List<Map<String, String>> servers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Plusieurs boutiques trouvées"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Sélectionnez votre boutique pour vous connecter :"),
              const SizedBox(height: 20),
              ...servers.map((s) => ListTile(
                leading: const Icon(FluentIcons.building_24_filled, color: Colors.orange),
                title: Text(s['name'] ?? "Boutique Inconnue", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("IP : ${s['ip']}"),
                trailing: const Icon(FluentIcons.chevron_right_24_regular),
                onTap: () {
                  setState(() {
                    _serverIpCtrl.text = s['ip']!;
                    _serverPortCtrl.text = s['port']!;
                  });
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Signature Visuelle", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Personnalisez le nom et le logo de votre établissement pour vos clients.", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildLogoPicker(),
                      const SizedBox(height: 24),
                      _buildField("Nom de l'établissement", _nameCtrl, FluentIcons.building_24_regular, placeholder: "Ex: Boutique Elite"),
                      const SizedBox(height: 16),
                      _buildField("Téléphone", _phoneCtrl, FluentIcons.phone_24_regular, placeholder: "+223 00 00 00 00"),
                      const SizedBox(height: 16),
                      _buildField("Adresse", _addressCtrl, FluentIcons.location_24_regular, placeholder: "Bamako, Mali"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const Text("APERÇU REÇU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
                    const SizedBox(height: 12),
                    _buildReceiptPreview(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le sélecteur de logo Elite sera disponible dès la fin de l'installation.")));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.image_add_24_regular, color: Colors.blue.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            const Text("Choisir un Logo PNG", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return ValueListenableBuilder(
      valueListenable: _nameCtrl,
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              const Text("--- TICKET DE VENTE ---", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_nameCtrl.text.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              Text(_phoneCtrl.text.isEmpty ? "Tél: +223..." : "Tél: ${_phoneCtrl.text}", style: const TextStyle(fontSize: 10)),
              const Divider(thickness: 1, height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Produit Elite x1", style: TextStyle(fontSize: 10)),
                  Text("5.000", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("TOTAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                   Text("5.000 FCFA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ],
              ),
              const Divider(thickness: 1, height: 20),
              const Text("MERCI DE VOTRE CONFIANCE", style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
            ],
          ),
        );
      }
    );
  }

  Widget _stepTaxation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Fiscalité & Taxes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Configurez comment vous gérez la TVA ou autres taxes locales.", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 40),
        SwitchListTile(
          title: const Text("Appliquer une taxe sur les ventes", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Activez cette option si vous êtes assujetti à la TVA"),
          value: _useTax,
          onChanged: (v) => setState(() => _useTax = v),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        ),
        if (_useTax) ...[
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: EnterpriseWidgets.buildPremiumTextField(context, ctrl: _taxNameCtrl, label: "NOM DE LA TAXE", hint: "TVA", icon: FluentIcons.receipt_24_regular)),
            const SizedBox(width: 20),
            Expanded(child: EnterpriseWidgets.buildPremiumTextField(context, ctrl: _taxRateCtrl, label: "TAUX (%)", hint: "18.0", icon: FluentIcons.calculator_20_regular, keyboardType: TextInputType.number)),
          ]),
        ],
      ],
    );
  }

  Widget _stepAutomation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Automatisation du Stock", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Gagnez du temps en générant automatiquement vos références produits.", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 40),
        SwitchListTile(
          title: const Text("Références Automatiques", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Génère un code unique (SKU) pour chaque produit créé sans référence."),
          value: _useAutoRef,
          onChanged: (v) => setState(() => _useAutoRef = v),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        ),
        if (_useAutoRef) ...[
          const SizedBox(height: 32),
          EnterpriseWidgets.buildPremiumTextField(
            context, 
            ctrl: _refPrefixCtrl, 
            label: "PRÉFIXE DES RÉFÉRENCES", 
            hint: "REF, PROD, ART...", 
            icon: FluentIcons.tag_24_regular,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: _refPrefixCtrl,
            builder: (context, value, _) {
              return Text(
                "Exemple : ${_refPrefixCtrl.text}-CAT-001",
                style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.primary),
              );
            }
          ),
        ],
      ],
    );
  }

  Widget _stepRecoveryKey() {
    if (_recoveryKey == null) {
      Future.microtask(() {
        setState(() => _recoveryKey = ref.read(authServiceProvider.notifier).generateRecoveryKey());
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Clé de Secours (Recovery Key)", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Si vous oubliez votre PIN Administrateur, cette clé sera votre SEUL moyen de réinitialiser l'accès.", 
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 40),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(FluentIcons.lock_closed_24_filled, color: Colors.red, size: 40),
              const SizedBox(height: 16),
              const Text("VOTRE CLÉ PERSONNELLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
              const SizedBox(height: 12),
              SelectableText(
                _recoveryKey ?? "GÉNÉRATION...",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Courier',
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(FluentIcons.warning_24_regular, color: Colors.orange),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  "IMPORTANT: Notez cette clé sur papier ou enregistrez-la dans un endroit sûr. Nous ne pourrons pas la récupérer pour vous.",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        CheckboxListTile(
          value: _keySaved,
          onChanged: (v) => setState(() => _keySaved = v ?? false),
          title: const Text("J'ai noté ma clé de secours en lieu sûr", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.green,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _stepHardware() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Configuration Matérielle", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Vérifions si votre PC est prêt pour l'expérience Danaya+ Elite.", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(right: 16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.withValues(alpha: 0.1), Colors.blue.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(FluentIcons.flash_24_filled, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Text("DIAGNOSTIC SYSTÈME", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 13)),
                        const Spacer(),
                        if (!_isHardwareChecked)
                          TextButton(
                            onPressed: () async {
                              setState(() => _cpuInfo = "Analyse en cours...");
                              await Future.delayed(const Duration(seconds: 2));
                              if (!mounted) return;
                              setState(() {
                                _cpuInfo = "Intel Core i5 (8th Gen)";
                                _ramInfo = "8.0 GB RAM";
                                _isHardwareChecked = true;
                              });
                            },
                            child: const Text("LANCER LE SCAN"),
                          )
                        else
                          const Icon(FluentIcons.checkmark_circle_24_filled, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem("PROCESSEUR", _cpuInfo),
                        _buildStatItem("MÉMOIRE VIVE", _ramInfo),
                        _buildStatItem("STOCKAGE", "SSD Détecté"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              _buildHardwareCard(
                "Imprimante Thermique",
                "Assurez-vous que votre imprimante est allumée et connectée via USB.",
                FluentIcons.print_24_regular,
                Colors.orange,
                trailing: FilledButton.tonal(
                  onPressed: _isPrinterTesting ? null : () async {
                    setState(() => _isPrinterTesting = true);
                    await Future.delayed(const Duration(seconds: 1));
                    if (!mounted) return;
                    setState(() => _isPrinterTesting = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signal de test envoyé à l'imprimante par défaut.")));
                  },
                  child: Text(_isPrinterTesting ? "TEST..." : "TESTER"),
                ),
              ),
              const SizedBox(height: 12),
              
              const Text("Conseils Elite :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              _buildHardwareTip(FluentIcons.plug_connected_24_regular, "Utilisez un onduleur pour éviter les coupures brutes qui endommagent la base de données."),
              _buildHardwareTip(FluentIcons.save_24_regular, "Privilégiez les disques SSD pour une fluidité maximale lors des inventaires."),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildHardwareTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {String? placeholder}) {
    return EnterpriseWidgets.buildPremiumTextField(
      context, 
      label: label.toUpperCase(), 
      ctrl: ctrl, 
      hint: placeholder ?? "", 
      icon: icon,
    );
  }

  Widget _buildHardwareCard(String title, String desc, IconData icon, Color color, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (trailing != null) trailing,
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepAiOptIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Intelligence Titan (v1)", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text("Activez les capacités prédictives et l'assistance intelligente de Danaya+.", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        
        Expanded(
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(FluentIcons.info_24_filled, color: Colors.blue, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      "TRANSPARENCE IA",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "L'IA Titan v1 est une technologie de pointe conçue pour travailler de manière autonome et hors-ligne. Cependant, elle est encore en phase d'apprentissage. Elle peut parfois commettre des erreurs d'analyse ou de prédiction. Vous gardez toujours le contrôle final.",
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.5, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(FluentIcons.warning_24_filled, color: Colors.red),
                        SizedBox(width: 12),
                        Text("ALERTE : MODE VOCAL (BETA)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "L'assistant vocal est actuellement en version BETA EXPÉRIMENTALE. Son utilisation est considérée comme RISQUÉE et peut être instable sur certaines versions de Windows. Même notre équipe technique a rencontré des blocages. Ne l'activez que si vous souhaitez participer aux tests.",
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              SwitchListTile(
                value: _isAiEnabled,
                onChanged: (v) => setState(() => _isAiEnabled = v),
                title: const Text("Activer l'Intelligence Titan (Analyses)", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Macro-commandes, recherche intelligente et prévisions de stocks."),
                secondary: const Icon(FluentIcons.brain_circuit_24_regular, color: Colors.blue),
              ),
              const Divider(),
              SwitchListTile(
                value: _isVoiceEnabled,
                onChanged: (v) => setState(() => _isVoiceEnabled = v),
                title: const Text("Activer l'Assistant Vocal (BETA)", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Utiliser la voix pour naviguer et encaisser (Risqué / Instable)."),
                secondary: const Icon(FluentIcons.mic_sparkle_24_regular, color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepReady() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(FluentIcons.star_24_filled, size: 80, color: Colors.orange),
          ),
          const SizedBox(height: 32),
          Text(_networkMode == NetworkMode.client ? "Poste Relié !" : "Configuration Élite Terminée", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text(
            "Votre écosystème Danaya+ est maintenant optimisé et prêt à l'emploi.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(FluentIcons.building_24_regular, "Établissement", _nameCtrl.text),
                _buildSummaryRow(FluentIcons.router_24_regular, "Mode Réseau", _networkMode.name.toUpperCase()),
                _buildSummaryRow(FluentIcons.brain_circuit_24_regular, "Intelligence Titan", _isAiEnabled ? "ACTIVÉE" : "DÉSACTIVÉE"),
                _buildSummaryRow(FluentIcons.mic_sparkle_24_regular, "Assistant Vocal", _isVoiceEnabled ? "BETA ACTIVE" : "OFF"),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          const Text(
            "IMPORTANT: Identifiant: 'Administrateur' | PIN: '1234'",
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            "Pensez à changer votre code PIN dès votre première connexion.",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int index, String label) {
    bool isActive = _currentStep == index;
    bool isDone = _currentStep > index;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone ? Colors.green : (isActive ? Colors.blue : Colors.grey.shade300),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(FluentIcons.checkmark_12_filled, size: 12, color: Colors.white)
                  : Text((index + 1).toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.blue : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 20, height: 1.5, color: Colors.grey.shade200, margin: const EdgeInsets.only(bottom: 18));
  }

  Widget _buildVisualProgress(String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDone ? Colors.white : Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? FluentIcons.checkmark_12_filled : FluentIcons.circle_12_regular,
              size: 10,
              color: isDone ? Colors.blue : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDone ? Colors.white : Colors.white.withValues(alpha: 0.6),
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
