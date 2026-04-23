# 🚀 Danaya+ — Le POS & ERP Révolutionnaire "Offline-First"
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-blue?style=for-the-badge)](https://flutter.dev/multi-platform)

**Danaya+** n'est pas qu'un simple point de vente. C'est un écosystème commercial premium, conçu spécifiquement pour les environnements où la connectivité est instable mais les exigences professionnelles sont élevées. Développé avec **Flutter Desktop**, il allie la puissance d'une base de données locale à des innovations de pointe telles que l'**Intelligence Artificielle conversationnelle** et la **Synchronisation matérielle en temps réel**.

---

## 🌟 Fonctionnalités Révolutionnaires (L'Exclusivité Danaya)

### 🤖 1. Danaya Assistant (NLP Conversationnel)
Le premier POS de la région à intégrer un moteur **NLP 100% Offline**. Pas d'internet ? Aucun problème.
-   **Commandes Vocales & Textuelles** : Parlez à votre boutique. *"Combien j'ai vendu hier ?"*, *"Montre-moi les dettes du Client X"*.
-   **Reconnaissance Intelligente** : Gère les fautes de frappe, les synonymes et la terminologie commerciale locale.
-   **Confidentialité Totale** : Tous les traitements d'intention se font sur votre processeur local.

### ⚡ 2. Alpha-Migrate (Pont de Données par IA)
Passer de fichiers Excel désordonnés à un POS professionnel est désormais une question de secondes.
-   **Mapping Intelligent** : Notre moteur détecte automatiquement les en-têtes et les structures de vos fichiers externes.
-   **Importation "Fast-Track"** : Les modèles officiels Danaya sont reconnus instantanément, évitant tout mapping manuel.
-   **Validation des Données** : Une désinfection proactive garantit que votre inventaire démarre sur des bases saines.

### 🖥️ 3. Afficheur Client Digital (Système de Diffusion)
Élevez l'expérience d'achat avec un écran secondaire dédié.
-   **Liberté Matérielle** : N'importe quelle tablette ou téléphone sur le réseau local devient un afficheur professionnel.
-   **Synchro Temps Réel** : Le panier, les totaux et les points de fidélité se mettent à jour instantanément via un flux WebSocket léger.
-   **Engagement** : Affichez des promotions et le solde du client pendant qu'il fait ses achats.

### 📄 4. Moteur Documentaire Professionnel (Mode Prestige)
Ne vous contentez pas d'imprimer des reçus ; projetez l'excellence.
-   **Modèles Multi-Formats** : Basculez entre le mode "Standard" (Ticket 80mm) et "Prestige" (Facture A4).
-   **Aperçus Interactifs** : Visualisez vos documents en PDF haute fidélité avant l'impression ou le partage.
-   **Partage Direct** : Envoyez vos factures instantanément par WhatsApp ou Email (génération 100% hors-ligne).

---

## 💎 Philosophie Design : Bento UI
Danaya+ utilise un système de design **Bento Box** optimisé pour les opérations intensives en caisse.
-   **Glassmorphism & Micro-animations** : Une expérience fluide et moderne qui réduit la fatigue de l'opérateur.
-   **8 Palettes de Couleurs Dynamiques** : De "Enterprise Emerald" à "Midnight Blue", adaptez le logiciel à votre marque.
-   **Flux Optimisés** : Chaque pixel est placé pour minimiser les clics et maximiser la vitesse de transaction.

---

## 🔒 Sécurité & Fiabilité
-   **Chiffrement lié au Matériel** : Votre base de données (SQLite) est chiffrée en AES-256 et verrouillée par l'ID matériel (HID) de votre appareil.
-   **Base de Données Auto-Guérissante** : Des vérifications d'intégrité proactives et une réparation de schéma empêchent la perte de données en cas de coupure de courant.
-   **Souveraineté Hors-Ligne** : Vous possédez vos données. Pas de dépendance au cloud, pas de suivi par abonnement.

---

## 🛠️ Stack Technique
-   **Framework** : [Flutter](https://flutter.dev) (Desktop Native)
-   **Moteur** : C++/Dart (FFI direct pour SQLite)
-   **Gestion d'État** : [Riverpod 3.x](https://riverpod.dev) (Réactif & Robuste)
-   **Intelligence** : Moteur NLP et automatisation sur mesure
-   **Rapports** : Génération de PDF vectoriels haute densité

---

## 📂 Structure du Projet
```text
lib/
├── core/             # Base de données, Réseau (Diffusion), Ponts Matériels
├── features/
│   ├── assistant/    # Moteur NLP & Danaya Assistant
│   ├── inventory/    # Stock, Alpha-Migrate, Utilitaires Code-barres
│   ├── pos/          # Panier, Paiement, Serveur Afficheur Client
│   ├── finance/      # Trésorerie, Multi-devises, Audits Financiers
│   └── settings/     # Configuration Matérielle, Sécurité, Centre de Design
```

---

## 👨‍💻 Note sur la Publication Publique
Ce dépôt met en avant les innovations architecturales du projet **Danaya+**. Il démontre comment construire une application d'entreprise "Offline-First" de qualité industrielle avec Flutter.

*© 2024 Danaya+ Technologies. Tous droits réservés.*
