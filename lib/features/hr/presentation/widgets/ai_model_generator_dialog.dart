import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

class AiModelGeneratorDialog extends StatefulWidget {
  final String shopName;
  final String currency;
  const AiModelGeneratorDialog({
    super.key,
    required this.shopName,
    required this.currency,
  });

  @override
  State<AiModelGeneratorDialog> createState() => _AiModelGeneratorDialogState();
}

class _AiModelGeneratorDialogState extends State<AiModelGeneratorDialog> {
  final _descriptionCtrl = TextEditingController();
  
  String _docType = "Contrat de Travail"; // "Contrat de Travail" or "Document Administratif"
  String _docSubType = "CDI"; // CDI, CDD, Freelance, Stage, Lettre d'offre, Avenant, Note de service
  String _tone = "Juridique rigoureux"; // Juridique rigoureux, Moderne & Collaboratif, Standard
  String _jurisdiction = "République du Mali"; // République du Mali, International, Autre
  
  // Clauses selection
  final Map<String, bool> _clauses = {
    "Clause de Confidentialité (NDA)": true,
    "Clause de Non-concurrence": false,
    "Régime de Télétravail": false,
    "Prime de performance": false,
    "Heures supplémentaires encadrées": true,
  };

  // Presets list
  final List<Map<String, String>> _presets = [
    {
      'label': 'CDI Développeur',
      'type': 'Contrat de Travail',
      'subType': 'CDI',
      'desc': 'Contrat CDI pour un développeur de logiciel senior. Inclure des clauses de propriété intellectuelle robustes, 3 mois de période d\'essai, et un salaire annuel de référence.'
    },
    {
      'label': 'CDD Commercial 6 mois',
      'type': 'Contrat de Travail',
      'subType': 'CDD',
      'desc': 'Contrat CDD de 6 mois renouvelable pour un commercial. Intégrer une clause de commission sur ventes et objectifs de performance.'
    },
    {
      'label': 'Stage Informatique',
      'type': 'Contrat de Travail',
      'subType': 'Stage',
      'desc': 'Convention de stage d\'immersion de 3 mois pour un étudiant en informatique. Horaires de 40h/semaine, indemnité forfaitaire mensuelle.'
    },
    {
      'label': 'Freelance / Prestation',
      'type': 'Contrat de Travail',
      'subType': 'Freelance',
      'desc': 'Contrat de prestation de service freelance pour un consultant. Facturation au livrable, obligation de résultats, absence de lien de subordination.'
    },
    {
      'label': 'Avenant Télétravail',
      'type': 'Document Administratif',
      'subType': 'Avenant',
      'desc': 'Avenant au contrat de travail initial pour officialiser un régime de télétravail hybride à hauteur de 2 jours par semaine à domicile.'
    },
    {
      'label': 'Lettre d\'Offre d\'Emploi',
      'type': 'Document Administratif',
      'subType': 'Lettre d\'offre',
      'desc': 'Lettre formelle de proposition d\'embauche détaillant le poste, la rémunération de départ, les avantages sociaux, et fixant une date limite de réponse.'
    },
  ];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _docType = preset['type']!;
      _docSubType = preset['subType']!;
      _descriptionCtrl.text = preset['desc']!;
      if (preset['subType'] == 'Freelance') {
        _clauses["🔒 Clause de Confidentialité (NDA)"] = true;
        _clauses["🚫 Clause de Non-concurrence"] = true;
      }
    });
  }

  void _generate() {
    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez décrire le document ou choisir un modèle rapide."), backgroundColor: Colors.orange),
      );
      return;
    }

    // Build the structural prompt
    final selectedClauses = _clauses.entries.where((e) => e.value).map((e) => e.key).join(", ");
    
    final prompt = "Tu es 'Danaya Copilot', un Expert Juridique et Rédacteur de classe mondiale (façon Canva AI).\\n"
        "Ton objectif : Rédiger le corps d'un modèle juridique complet de type : $_docType ($_docSubType), dans un style $_tone, pour la juridiction $_jurisdiction.\\n"
        "Sujet / Consignes : $description\\n"
        "Clauses requises : $selectedClauses\\n"
        "Entreprise émettrice : ${widget.shopName}\\n"
        "\\n"
        "DIRECTIVES CRUCIALES DE GÉNÉRATION (FORMAT HTML SÉMANTIQUE PUR) :\\n"
        "1. Génère le texte sous forme de corps HTML propre (uniquement du contenu sémantique comme <h1>, <h2>, <p>, <strong>, <ul>, <li>, <table>, <tr>, <td>).\\n"
        "2. NE génère PAS de balises structurales globales (PAS de <!doctype html>, <html>, <head>, <style>, ou <body>).\\n"
        "3. Concentre-toi sur le contenu textuel et la hiérarchie. L'application appliquera automatiquement le thème graphique.\\n"
        "4. Si le document parle de chiffres (salaires, honoraires), utilise une table HTML (<table>) propre pour structurer les données.\\n"
        "5. Rédige un document complet, rigoureux et exploitable juridiquement.\\n"
        "6. Utilise ces variables pour la personnalisation : [NOM_EMPLOYE], [DATE_NAISSANCE], [POSTE], [DEPARTEMENT], [SALAIRE], [DEVISE] (${widget.currency}), [DATE_DEBUT], [DATE_FIN], [DUREE], [BOUTIQUE] (${widget.shopName}), [ADRESSE], [DATE_JOUR].";

    Navigator.pop(context, prompt);
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: c.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(FluentIcons.sparkle_28_filled, color: Colors.purple.shade400, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Danaya Copilot - Assistant Juridique",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary),
                        ),
                        Text(
                          "Paramétrez et rédigez un modèle juridique sur-mesure conforme à la législation locale",
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                  ),
                ],
              ),
            ),
            
            // Core Contents
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: Parameters Selection
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionTitle("1. TYPE DE DOCUMENT", c),
                          const SizedBox(height: 8),
                          _buildDropdown<String>(
                            value: _docType,
                            items: ["Contrat de Travail", "Document Administratif"],
                            onChanged: (v) {
                              setState(() {
                                _docType = v!;
                                _docSubType = _docType == "Contrat de Travail" ? "CDI" : "Lettre d'offre";
                              });
                            },
                            c: c,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown<String>(
                            value: _docSubType,
                            items: _docType == "Contrat de Travail" 
                                ? ["CDI", "CDD", "Freelance", "Stage", "Essai"]
                                : ["Lettre d'offre", "Avenant", "Note de service", "Attestation", "Convocation"],
                            onChanged: (v) => setState(() => _docSubType = v!),
                            c: c,
                          ),
                          const SizedBox(height: 20),
                          
                          _buildSectionTitle("2. CADRE LÉGAL & STYLE", c),
                          const SizedBox(height: 8),
                          _buildDropdown<String>(
                            value: _jurisdiction,
                            items: ["République du Mali", "International", "Autre"],
                            onChanged: (v) => setState(() => _jurisdiction = v!),
                            c: c,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown<String>(
                            value: _tone,
                            items: ["Juridique rigoureux", "Moderne & Collaboratif", "Standard"],
                            onChanged: (v) => setState(() => _tone = v!),
                            c: c,
                          ),
                          const SizedBox(height: 20),
                          
                          _buildSectionTitle("3. CLAUSES SPÉCIALES À INCLURE", c),
                          const SizedBox(height: 6),
                          ..._clauses.keys.map((clauseKey) => Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: CheckboxListTile(
                              value: _clauses[clauseKey],
                              title: Text(clauseKey, style: TextStyle(fontSize: 11, color: c.textPrimary)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: Colors.purple.shade400,
                              onChanged: (val) => setState(() => _clauses[clauseKey] = val!),
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    
                    // RIGHT COLUMN: Prompts Presets & Main Input
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionTitle("MODÈLES DE DÉPART RAPIDE (PRESETS)", c),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presets.map((preset) => ActionChip(
                              label: Text(preset['label']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              onPressed: () => _applyPreset(preset),
                              backgroundColor: c.surfaceElev,
                            )).toList(),
                          ),
                          const SizedBox(height: 24),
                          
                          _buildSectionTitle("DESCRIPTIF / CONSIGNES PARTICULIÈRES", c),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionCtrl,
                            maxLines: 7,
                            style: TextStyle(fontSize: 13, color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: "Décrivez ici les détails du document à rédiger (missions, clauses spéciales, horaires, préavis, etc.). Soyez précis pour obtenir un meilleur résultat.",
                              border: const OutlineInputBorder(),
                              fillColor: c.surfaceElev,
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Actions Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: c.surfaceElev,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler"),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: _generate,
                    icon: const SizedBox.shrink(),
                    label: const Text("Rédiger le modèle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, DashColors c) {
    return Text(
      title,
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: c.blue, letterSpacing: 0.5),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required DashColors c,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: c.surfaceElev,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((i) => DropdownMenuItem<T>(
            value: i,
            child: Text(i.toString(), style: TextStyle(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600)),
          )).toList(),
          onChanged: onChanged,
          isExpanded: true,
          icon: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
