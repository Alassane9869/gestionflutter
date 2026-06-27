import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../domain/models/help_article.dart';
import '../../inventory/presentation/widgets/dashboard_widgets.dart'; // Pour DashColors

class HelpScreen extends StatefulWidget {
  final bool embedded;
  const HelpScreen({super.key, this.embedded = false});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  HelpCategory? _selectedCategory;
  HelpArticle? _selectedArticle;
  String _searchQuery = "";
  final _searchCtrl = TextEditingController();

  final List<HelpArticle> _articles = [
    // --- INVENTAIRE ---
    const HelpArticle(
      id: 'stock-add',
      title: 'Ajouter des produits',
      category: HelpCategory.inventory,
      icon: FluentIcons.box_24_regular,
      markdownContent: '''
### Ajouter un nouveau produit
Pour ajouter un produit au stock :
1. Allez dans **Gestion de Stock** > **Liste des Produits**.
2. Cliquez sur le bouton **Ajouter (+)**.
3. Remplissez les informations essentielles :
   - **Nom** : Désignation de l'article.
   - **Prix d'achat** : Pour le calcul des marges.
   - **Prix de vente** : Prix unitaire au client.
   - **Seuil d'alerte** : Quantité minimum avant notification.

> [!TIP]
> Activez la gestion par code-barres pour accélérer vos ventes au comptoir.
''',
    ),
    const HelpArticle(
      id: 'stock-excel-export',
      title: 'Exportation vers Excel',
      category: HelpCategory.inventory,
      icon: FluentIcons.arrow_export_up_24_regular,
      markdownContent: '''
### Exporter vos données vers Excel
Danaya+ permet d'exporter l'intégralité de vos inventaires pour une analyse approfondie.

1. Allez dans **Gestion de Stock** > **Liste des Produits**.
2. Dans la barre d'outils, cliquez sur l'icône **Excel** (Export).
3. Choisissez l'emplacement de sauvegarde sur votre ordinateur.
4. Le fichier `.xlsx` généré contient :
   - Le stock actuel.
   - La valeur totale du stock (prix d'achat).
   - Le potentiel de vente (prix de vente).

> [!IMPORTANT]
> L'export Excel est idéal pour vos inventaires physiques de fin d'année.
''',
    ),
    const HelpArticle(
      id: 'stock-excel-import',
      title: 'Importation de masse',
      category: HelpCategory.inventory,
      icon: FluentIcons.arrow_import_24_regular,
      markdownContent: '''
### Importer un catalogue existant
Si vous avez déjà une liste de produits, vous pouvez les importer massivement.
1. Téléchargez le **Modèle Excel** fourni dans l'écran d'import.
2. Remplissez les colonnes sans modifier les en-têtes.
3. Chargez le fichier dans Danaya+.
4. Validez l'importation.
''',
    ),

    // --- POS ---
    const HelpArticle(
      id: 'pos-sale',
      title: 'Vente au comptoir',
      category: HelpCategory.pos,
      icon: FluentIcons.receipt_24_regular,
      markdownContent: '''
### Réaliser une vente rapide
1. Ouvrez le **Point de Vente (POS)**.
2. Filtrez par catégorie ou scannez le **Code-barres**.
3. Les articles s'ajoutent automatiquement au panier.
4. Cliquez sur **Payer**.
5. Imprimez le ticket après validation.
''',
    ),
    const HelpArticle(
      id: 'pos-discounts',
      title: 'Remises et Promotions',
      category: HelpCategory.pos,
      icon: FluentIcons.tag_24_regular,
      markdownContent: '''
### Appliquer une réduction
Vous pouvez appliquer une remise sur un article ou sur le total du panier.
1. Sélectionnez l'article dans le panier.
2. Entrez le pourcentage (%) ou le montant fixe de la remise.
3. Le total est recalculé instantanément.
''',
    ),

    // --- FINANCE ---
    const HelpArticle(
      id: 'finance-cloture',
      title: 'Clôture de Caisse (Rapport Z)',
      category: HelpCategory.finance,
      icon: FluentIcons.calendar_ltr_24_regular,
      markdownContent: '''
### Fin de journée
La clôture de caisse permet de vérifier les fonds et réinitialiser le tiroir-caisse.
1. Allez dans **Finance** > **Rapports Quotidiens**.
2. Cliquez sur **Clôturer la Caisse**.
3. Vérifiez le total théorique vs le total physique.
4. Imprimez le **Rapport Z** pour votre comptabilité.
''',
    ),
    const HelpArticle(
      id: 'finance-expenses',
      title: 'Dépenses et Sorties',
      category: HelpCategory.finance,
      icon: FluentIcons.money_hand_24_regular,
      markdownContent: '''
### Enregistrer une dépense
Utilisez ce module pour toute sortie d'argent (achat de consommables, facture électricité, etc.).
1. Allez dans **Finance** > **Dépenses**.
2. Cliquez sur **Nouvelle Dépense**.
3. Indiquez le motif et le montant.
4. La dépense sera automatiquement déduite de votre profit net journalier.
''',
    ),

    // --- RESEAU ---
    const HelpArticle(
      id: 'network-setup',
      title: 'Configuration Multi-Postes',
      category: HelpCategory.network,
      icon: FluentIcons.share_android_24_regular,
      markdownContent: '''
### Connecter plusieurs PC
1. **POSTE SERVEUR** : L'ordinateur qui stocke les données. Notez son adresse IP (ex: 192.168.1.15).
2. **POSTE CLIENT** : Dans Paramètres > Réseau, entrez l'IP du serveur.
3. Testez la connexion pour synchroniser les stocks en temps réel.
''',
    ),
    const HelpArticle(
      id: 'network-synckey',
      title: 'Clé de Synchronisation (SyncKey)',
      category: HelpCategory.network,
      icon: FluentIcons.key_24_regular,
      markdownContent: '''
### Protéger votre réseau avec la SyncKey
La **SyncKey** est une clé secrète qui empêche tout accès non autorisé à votre serveur.

**Où la trouver ?**
- Sur le **Poste Admin** : Paramètres > Réseau > Section "Informations Serveur".

**Comment l'utiliser ?**
1. Notez la clé affichée sur le Poste Admin.
2. Sur chaque **Poste Client**, entrez cette clé dans l'assistant de configuration.
3. Sans cette clé, aucun appareil ne peut se synchroniser.

> [!IMPORTANT]
> Ne partagez jamais votre SyncKey publiquement. Elle protège toutes vos données commerciales.
''',
    ),
    const HelpArticle(
      id: 'network-remote',
      title: 'Accès Distant (Tailscale)',
      category: HelpCategory.network,
      icon: FluentIcons.globe_24_regular,
      markdownContent: '''
### Gérer votre boutique à distance
Avec **Tailscale**, le directeur peut accéder aux données depuis n'importe où, sans ouvrir de port sur votre box.

**Étapes :**
1. Installez Tailscale sur le **Poste Admin** (la boutique).
2. Installez Tailscale sur le **PC du Directeur** avec le même compte.
3. Notez l'adresse IP Tailscale du Poste Admin (ex: 100.x.y.z).
4. Dans Danaya+ (PC Directeur), entrez cette IP et la **SyncKey**.

**Avantages :**
- Gratuit (jusqu'à 100 appareils).
- Zéro configuration routeur.
- Connexion chiffrée de bout en bout.
- Se reconnecte automatiquement après redémarrage.
''',
    ),
    const HelpArticle(
      id: 'network-lan',
      title: 'Réseau Local (RJ45 / Câblage)',
      category: HelpCategory.network,
      icon: FluentIcons.plug_disconnected_24_regular,
      markdownContent: '''
### Câbler votre boutique en RJ45
Le câble RJ45 est plus fiable que le Wi-Fi pour les transactions commerciales.

**Matériel nécessaire :**
- Un routeur ou un **Switch Gigabit** (8 ports recommandé).
- Des câbles RJ45 Cat.5e ou Cat.6.

**Branchement :**
1. Branchez le **Poste Admin** au routeur/switch.
2. Branchez chaque **Poste Caissier** au même routeur/switch.

**IP Fixe (Crucial) :**
- Sur le Poste Admin, fixez l'adresse IP en mode "Manuel" dans les paramètres Windows.
- Cela garantit que les caisses retrouveront toujours le serveur.

> [!TIP]
> Un Switch Gigabit coûte environ 25-30€ et permet de connecter jusqu'à 8 postes simultanément avec une vitesse optimale.
''',
    ),

    // --- SECURITE ---
    const HelpArticle(
      id: 'security-recovery',
      title: 'Récupération du PIN',
      category: HelpCategory.security,
      icon: FluentIcons.key_24_regular,
      markdownContent: '''
### Oubli du code PIN
Utilisez votre **Clé de Récupération** de 16 caractères fournie lors de l'installation.
1. Écran de login > **Code oublié**.
2. Entrez la clé.
3. Paramétrez un nouveau PIN.
''',
    ),

    // --- GENERAL ---
    const HelpArticle(
      id: 'gen-shortcuts',
      title: 'Raccourcis Clavier',
      category: HelpCategory.general,
      icon: FluentIcons.keyboard_24_regular,
      markdownContent: '''
### Gagner du temps
- **F1** : Ouvrir ce centre d'aide.
- **F2** : Accès rapide au POS.
- **ENTRÉE** : Valider un paiement ou une recherche.
- **ÉCHAP** : Fermer un dialogue ou annuler.
''',
    ),
    const HelpArticle(
      id: 'gen-backup',
      title: 'Sauvegardes des données',
      category: HelpCategory.general,
      icon: FluentIcons.save_24_regular,
      markdownContent: '''
### Protéger vos informations
Par défaut, Danaya+ sauvegarde vos données localement.
1. Allez dans **Paramètres** > **Base de données**.
2. Effectuez une **Sauvegarde Manuelle** régulièrement.
3. Copiez le fichier sur une clé USB ou un drive externe.
''',
    ),
    const HelpArticle(
      id: 'gen-legal',
      title: "Conditions d'Utilisation",
      category: HelpCategory.general,
      icon: FluentIcons.shield_24_regular,
      markdownContent: '''
### Conditions Générales d'Utilisation (CGU)

**Version 1.1 — 2026**

Bienvenue sur Danaya+. En utilisant ce logiciel, vous acceptez expressément les présentes Conditions Générales d'Utilisation.

#### 1. Nature du Logiciel (Offline-First)
Danaya+ est une application **100% Hors-ligne**. Toutes les données commerciales sont stockées exclusivement sur votre ordinateur. Aucune donnée n'est envoyée vers des serveurs externes.

#### 2. Confidentialité des Données (Loi n° 2013-015, Mali)
- **Responsable du Traitement** : Conformément à la Loi, vous êtes responsable de la collecte des emails clients et du respect de leurs droits (APDP).
- **Stockage Local** : La base de contacts est stockée **uniquement sur votre disque**. Danaya+ Software ne consulte ni ne monétise jamais ces données.
- **Envois d'Emails (SMTP)** : Les emails transitent via votre propre fournisseur (ex: Gmail). L'application n'est qu'une passerelle locale.

#### 3. Responsabilité des Sauvegardes
**L'utilisateur est seul responsable** de ses sauvegardes. Danaya+ ne saurait être tenu responsable des pertes de données (pannes temporelles, vol, ransomware).

#### 4. Licence & Propriété Intellectuelle (Anti-Piratage)
Le logiciel reste la propriété de Danaya+ Software. **Tolérance Zéro contre le piratage** : Tenter de modifier le code ou de partager l'application avec des hackeurs pour une version "gratuite" (crack) exposera toute votre entreprise au vol de données et aux **rançongiciels (Ransomware)**. Toute fraude entraînera l'annulation des garanties et des poursuites pénales via les autorités.

#### 5. Sécurité & SyncKey
Vous êtes responsable de la gestion de vos codes PIN et de la **SyncKey**.

#### 6. Limitation de Responsabilité & Litiges
Dans toute la mesure permise par les lois de la République du Mali et de l'OHADA, Danaya+ décline toute responsabilité pour les pertes de profit ou fuites de données. Tout litige relève des tribunaux de Bamako.

#### 7. Configuration Matérielle
Utilisez un matériel adéquat. Un **Onduleur (UPS)** est fortement recommandé.

#### 8. Support Technique
Le support couvre les bugs logiciels, non le matériel, le réseau ou les blocages anti-spam de vos emails.

---
> [!CAUTION]
> **ALERTE JURIDIQUE : LOI N° 2013-015 (MALI)**
> 
> En tant que commerçant, vous êtes le **seul Responsable du Traitement** des données privées de vos clients au regard de l'APDP. 
> Danaya+ est une forteresse 100% Hors-ligne : nous n'avons aucun accès, ni aucune copie de vos données locales. **Vous devez OBLIGATOIREMENT sécuriser vos PC et réaliser vos propres sauvegardes** sous peine de perte définitive en cas de panne ou de vol.
''',
    ),
    const HelpArticle(
      id: 'gen-support',
      title: 'Support Technique',
      category: HelpCategory.general,
      icon: FluentIcons.person_support_24_regular,
      markdownContent: '''
### Besoin d'assistance ?
Notre équipe est à votre disposition pour vous accompagner dans l'utilisation de Danaya+.

**Contacts Officiels :**
- 📧 **Email** : alaska6e6ui3e@gmail.com
- 💬 **WhatsApp** : +223 66 82 62 07
- 👻 **Snapchat** : alasko_ff
- 🎵 **TikTok** : danaya+
- 🌐 **Site Web** : [danayaplus.online](https://danayaplus.online)

> [!TIP]
> Pour une assistance rapide, munissez-vous de votre **SyncKey** ou de votre numéro de licence lors de votre appel.
''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    if (widget.embedded) {
      return _buildContent(c);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: _buildContent(c),
    );
  }

  Widget _buildContent(DashColors c) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // SIDEBAR CATEGORIES (Glassmorphism)
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.8),
                border: Border(right: BorderSide(color: c.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ACADEMY D+",
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.textMuted,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Guide d'Utilisation",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search Bar Ultra-Compact
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Rechercher...",
                          prefixIcon: Icon(FluentIcons.search_16_regular, size: 16, color: c.textMuted),
                          filled: true,
                          fillColor: c.surfaceElev.withValues(alpha: 0.5),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        _buildCategoryItem(null, "Tous les guides", FluentIcons.library_24_regular, c),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Divider(height: 1),
                        ),
                        ...HelpCategory.values.map((cat) => _buildCategoryItem(cat, cat.label, cat.icon, c)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // CONTENT AREA
        Expanded(
          child: AnimatedSwitcher(
            duration: 250.ms,
            child: _selectedArticle != null
                ? _buildArticleDetail(c)
                : _buildArticleGrid(c),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(HelpCategory? category, String label, IconData icon, DashColors c) {
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedCategory = category;
            _selectedArticle = null;
          });
        },
        dense: true,
        visualDensity: VisualDensity.compact, // Mode compact
        leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : c.textMuted, size: 18),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? theme.colorScheme.primary : c.textSecondary,
            fontSize: 12,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.06),
      ),
    );
  }

  Widget _buildArticleGrid(DashColors c) {
    final filteredArticles = _articles.where((a) {
      final matchesCat = _selectedCategory == null || a.category == _selectedCategory;
      final matchesSearch = a.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Container(
      color: c.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), // Padding réduit
            child: Row(
              children: [
                Text(
                  _selectedCategory?.label ?? "Dernières mises à jour",
                   style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const Spacer(),
                Text("${filteredArticles.length} guides", style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (filteredArticles.isEmpty)
             Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.document_search_24_regular, size: 48, color: c.textMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text("Aucun guide trouvé", style: TextStyle(color: c.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380, // Cartes plus compactes
                  mainAxisExtent: 130, // Hauteur réduite
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredArticles.length,
                itemBuilder: (context, index) {
                  return _buildArticleCard(filteredArticles[index], c);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(HelpArticle art, DashColors c) {
    return _HoverCard(
      onTap: () => setState(() => _selectedArticle = art),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: art.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(art.icon, color: art.iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(art.category.label.toUpperCase(), style: TextStyle(fontSize: 9, color: art.iconColor, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text(
                      art.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _getSnippet(art.markdownContent),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _getSnippet(String content) {
    return content.replaceAll(RegExp(r'[#\*>]'), '').trim().split('\n').firstWhere((l) => l.isNotEmpty, orElse: () => "");
  }

  Widget _buildArticleDetail(DashColors c) {
    final theme = Theme.of(context);
    return Container(
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Detail Ultra-Compact
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: BoxDecoration(
              color: c.bg,
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedArticle = null),
                  icon: const Icon(FluentIcons.arrow_left_16_regular, size: 14),
                  label: const Text("RETOUR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(_selectedArticle!.icon, color: _selectedArticle!.iconColor, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedArticle!.category.label.toUpperCase(), style: TextStyle(color: _selectedArticle!.iconColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                          Text(
                            _selectedArticle!.title,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 40), // Marges ajustées
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: MarkdownBody(
                  data: _selectedArticle!.markdownContent,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 15, height: 1.6, color: c.textPrimary, fontWeight: FontWeight.w400),
                    h3: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 2, color: c.textPrimary, letterSpacing: -0.3),
                    listBullet: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    blockquoteDecoration: BoxDecoration(
                      color: c.surfaceElev,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                    ),
                    blockquotePadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverCard({required this.child, required this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.all(12), // Compact
          decoration: BoxDecoration(
            color: _hover ? c.surfaceElev : c.surface,
            borderRadius: BorderRadius.circular(12), // Plus carré (Elite)
            border: Border.all(color: _hover ? themeColorScheme(context).primary.withValues(alpha: 0.3) : c.border),
            boxShadow: _hover ? [BoxShadow(color: themeColorScheme(context).primary.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
  ColorScheme themeColorScheme(BuildContext context) => Theme.of(context).colorScheme;
}

extension HelpArticleColor on HelpArticle {
  Color get iconColor {
    switch (category) {
      case HelpCategory.inventory: return const Color(0xFF3B82F6);
      case HelpCategory.pos: return const Color(0xFF10B981);
      case HelpCategory.network: return const Color(0xFFF59E0B);
      case HelpCategory.security: return const Color(0xFFEF4444);
      case HelpCategory.finance: return const Color(0xFF10B981); 
      case HelpCategory.general: return const Color(0xFF6366F1); // Indigo for general
    }
  }
}
