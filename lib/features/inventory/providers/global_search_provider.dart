import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/inventory/data/product_repository.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:flutter/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

enum SearchResultType { product, client, sale, supplier, expense, shortcut }

class SearchShortcut {
  final String label;
  final String description;
  final int pageIndex;
  final List<String> keywords;
  final IconData icon;

  const SearchShortcut({
    required this.label,
    required this.description,
    required this.pageIndex,
    required this.keywords,
    required this.icon,
  });
}

final List<SearchShortcut> _allShortcuts = [
  SearchShortcut(
    label: "Point de Vente (Caisse)",
    description: "Accéder au terminal de vente et encaisser",
    pageIndex: 3,
    keywords: ["vente", "caisse", "pos", "terminal", "encaissement", "panier", "vendre"],
    icon: FluentIcons.cart_20_regular,
  ),
  SearchShortcut(
    label: "Historique des Ventes",
    description: "Consulter l'historique et les factures/tickets",
    pageIndex: 4,
    keywords: ["historique", "vente", "ticket", "facture", "remboursement", "journal"],
    icon: FluentIcons.receipt_20_regular,
  ),
  SearchShortcut(
    label: "Devis / Proformas",
    description: "Gérer les devis et factures proforma",
    pageIndex: 10,
    keywords: ["devis", "proforma", "estimation", "offre"],
    icon: FluentIcons.document_pdf_20_regular,
  ),
  SearchShortcut(
    label: "Gestion des Produits",
    description: "Consulter, ajouter et modifier les produits en stock",
    pageIndex: 1,
    keywords: ["produit", "stock", "article", "prix", "barcode", "code barre"],
    icon: FluentIcons.box_20_regular,
  ),
  SearchShortcut(
    label: "Mouvements de Stock",
    description: "Suivi des entrées, sorties et ajustements de stock",
    pageIndex: 2,
    keywords: ["mouvement", "stock", "historique stock", "entree", "sortie"],
    icon: FluentIcons.history_20_regular,
  ),
  SearchShortcut(
    label: "Alertes de Stock",
    description: "Voir les produits en rupture ou en stock bas",
    pageIndex: 14,
    keywords: ["alerte", "stock", "bas", "rupture", "seuil", "critique"],
    icon: FluentIcons.alert_20_regular,
  ),
  SearchShortcut(
    label: "Inventaire Physique",
    description: "Faire des audits de stock et ajustements",
    pageIndex: 15,
    keywords: ["inventaire", "physique", "audit", "ajustement", "ecart"],
    icon: FluentIcons.clipboard_search_20_regular,
  ),
  SearchShortcut(
    label: "Entrepôts et Dépôts",
    description: "Gérer vos différents lieux de stockage",
    pageIndex: 11,
    keywords: ["entrepot", "depot", "stockage", "magasin"],
    icon: FluentIcons.building_multiple_20_regular,
  ),
  SearchShortcut(
    label: "Trésorerie (Comptes)",
    description: "Consulter les soldes, caisse, banque et flux",
    pageIndex: 6,
    keywords: ["tresorerie", "caisse", "banque", "solde", "compte", "mobile money", "transfert", "argent"],
    icon: FluentIcons.wallet_20_regular,
  ),
  SearchShortcut(
    label: "Dépenses Opérationnelles",
    description: "Gérer et enregistrer les charges et frais",
    pageIndex: 13,
    keywords: ["depense", "charge", "frais", "loyer", "electricite", "facture"],
    icon: FluentIcons.money_hand_20_regular,
  ),
  SearchShortcut(
    label: "Rapports & Statistiques",
    description: "Visualiser les chiffres d'affaires et performances",
    pageIndex: 5,
    keywords: ["rapport", "statistique", "performance", "chiffre d'affaires", "ca", "profit", "marge"],
    icon: FluentIcons.data_bar_vertical_20_regular,
  ),
  SearchShortcut(
    label: "Annuaire des Clients",
    description: "Gérer vos fiches clients et fidélité",
    pageIndex: 7,
    keywords: ["client", "fidelite", "credit", "dette", "annuaire"],
    icon: FluentIcons.people_20_regular,
  ),
  SearchShortcut(
    label: "Suivi des Dettes Clients",
    description: "Suivi des impayés et remboursements de dettes",
    pageIndex: 12,
    keywords: ["dette", "credit", "client", "impaye", "remboursement"],
    icon: FluentIcons.person_money_20_regular,
  ),
  SearchShortcut(
    label: "Gestion des Fournisseurs",
    description: "Réseau fournisseurs et contacts SRM",
    pageIndex: 8,
    keywords: ["fournisseur", "srm", "partenaire", "adresse"],
    icon: FluentIcons.building_20_regular,
  ),
  SearchShortcut(
    label: "Bons d'Achat (SRM)",
    description: "Passer des commandes d'approvisionnement",
    pageIndex: 16,
    keywords: ["achat", "approvisionnement", "commande", "fournisseur", "reception"],
    icon: FluentIcons.cart_20_regular,
  ),
  SearchShortcut(
    label: "Personnel & RH",
    description: "Gérer les contrats, paies et congés des employés",
    pageIndex: 19,
    keywords: ["rh", "personnel", "contrat", "salaire", "paie", "conge", "employe"],
    icon: FluentIcons.people_community_24_regular,
  ),
  SearchShortcut(
    label: "Paramètres de la Boutique",
    description: "Configurer les taxes, tickets, monnaie et options",
    pageIndex: 9,
    keywords: ["parametre", "configuration", "reglage", "taxe", "boutique", "monnaie"],
    icon: FluentIcons.settings_20_regular,
  ),
  SearchShortcut(
    label: "Centre d'Aide & Support",
    description: "Documentation et support technique",
    pageIndex: 18,
    keywords: ["aide", "support", "documentation", "tutoriel", "faq"],
    icon: FluentIcons.question_circle_20_regular,
  ),
];

class GlobalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final SearchResultType type;
  final dynamic original;

  GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.original,
  });
}

final globalSearchProvider = AsyncNotifierProvider<GlobalSearchNotifier, List<GlobalSearchResult>>(
  GlobalSearchNotifier.new,
);

final searchSelectionProvider =
    NotifierProvider<SearchSelectionNotifier, String?>(
  SearchSelectionNotifier.new,
);

class SearchSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

class GlobalSearchNotifier extends AsyncNotifier<List<GlobalSearchResult>> {
  @override
  Future<List<GlobalSearchResult>> build() async {
    return [];
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    
    try {
      final productRepo = ref.read(productRepositoryProvider);
      final db = await ref.read(databaseServiceProvider).database;

      final settings = ref.read(shopSettingsProvider).value;
      final currency = settings?.currency ?? 'FCFA';
      final queryLower = query.toLowerCase();

      final List<GlobalSearchResult> results = [];

      // 1. Search Shortcuts / Command Palette (Filtered by user permissions)
      final user = ref.read(authServiceProvider).value;
      if (user != null) {
        final matchedShortcuts = _allShortcuts.where((shortcut) {
          // Check permissions
          if (shortcut.pageIndex == 1 || shortcut.pageIndex == 2 || shortcut.pageIndex == 14 || shortcut.pageIndex == 15 || shortcut.pageIndex == 11) {
            if (!user.canManageInventory) return false;
          }
          if (shortcut.pageIndex == 6) {
            if (!user.canAccessFinance) return false;
          }
          if (shortcut.pageIndex == 13) {
            if (!user.canManageExpenses) return false;
          }
          if (shortcut.pageIndex == 5) {
            if (!user.canAccessReports) return false;
          }
          if (shortcut.pageIndex == 7 || shortcut.pageIndex == 12) {
            if (!user.canManageCustomers) return false;
          }
          if (shortcut.pageIndex == 8 || shortcut.pageIndex == 16) {
            if (!user.canManageSuppliers) return false;
          }
          if (shortcut.pageIndex == 19) {
            if (!user.canManageHR) return false;
          }
          if (shortcut.pageIndex == 9) {
            if (!user.canAccessSettings) return false;
          }
          if (shortcut.pageIndex == 18) {
            if (!(user.isAdmin || user.isManager)) return false;
          }

          // Match label, description or keywords
          return shortcut.label.toLowerCase().contains(queryLower) ||
              shortcut.description.toLowerCase().contains(queryLower) ||
              shortcut.keywords.any((k) => k.contains(queryLower) || queryLower.contains(k));
        }).toList();

        for (var s in matchedShortcuts) {
          results.add(GlobalSearchResult(
            id: 'shortcut_${s.pageIndex}',
            title: s.label,
            subtitle: s.description,
            type: SearchResultType.shortcut,
            original: s,
          ));
        }
      }

      // 2. Search Products
      final products = await productRepo.search(query); 
      for (var p in products) {
        final stockStatus = p.quantity <= 0 ? "🔴 Rupture" : (p.quantity <= p.alertThreshold ? "🟡 Bas" : "🟢 En stock");
        final barcode = p.barcode != null ? " | ${p.barcode}" : "";
        results.add(GlobalSearchResult(
          id: p.id,
          title: p.name,
          subtitle: "$stockStatus (${DateFormatter.formatQuantity(p.quantity)})$barcode | ${p.sellingPrice} $currency",
          type: SearchResultType.product,
          original: p,
        ));
      }

      // 3. Search Clients
      final clientMaps = await db.query( 
        'clients',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 5,
      );
      final clients = clientMaps.map((m) => Client.fromMap(m)).toList();
      for (var c in clients) {
        final debt = c.credit > 0 ? " | ⚠️ Dette: ${c.credit} $currency" : "";
        results.add(GlobalSearchResult(
          id: c.id,
          title: c.name,
          subtitle: "Client${c.phone != null ? ' | ${c.phone}' : ''}$debt",
          type: SearchResultType.client,
          original: c,
        ));
      }

      // 4. Search Suppliers (SRM)
      if (user != null && user.canManageSuppliers) {
        final supplierMaps = await db.query(
          'suppliers',
          where: 'name LIKE ? OR phone LIKE ? OR contact_name LIKE ?',
          whereArgs: ['%$query%', '%$query%', '%$query%'],
          limit: 5,
        );
        final suppliers = supplierMaps.map((m) => Supplier.fromMap(m)).toList();
        for (var s in suppliers) {
          final debt = s.outstandingDebt > 0 ? " | ⚠️ Dette: ${DateFormatter.formatCurrency(s.outstandingDebt, currency)}" : "";
          results.add(GlobalSearchResult(
            id: s.id,
            title: s.name,
            subtitle: "Fournisseur${s.phone != null ? ' | ${s.phone}' : ''}$debt",
            type: SearchResultType.supplier,
            original: s,
          ));
        }
      }

      // 5. Search Sales / Tickets
      final saleMaps = await db.rawQuery('''
        SELECT s.*, c.name as client_name
        FROM sales s
        LEFT JOIN clients c ON s.client_id = c.id
        WHERE s.id LIKE ? OR c.name LIKE ? OR s.payment_method LIKE ? OR s.status LIKE ?
        ORDER BY s.date DESC
        LIMIT 5
      ''', ['%$query%', '%$query%', '%$query%', '%$query%']);
      for (var row in saleMaps) {
        final clientName = row['client_name'] as String? ?? "Passager";
        final saleId = row['id'] as String;
        final totalAmount = (row['total_amount'] as num).toDouble();
        final dateStr = row['date'] as String;
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();
        final pMethod = row['payment_method'] as String? ?? 'CASH';
        final isCredit = (row['is_credit'] as num).toInt() == 1;
        final status = row['status'] as String;

        final refString = "INV-${saleId.substring(0, 8).toUpperCase()}";
        final statusLabel = status == 'REFUNDED' ? "🔴 Annulé" : (isCredit ? "🟡 Crédit" : "🟢 Payé");

        results.add(GlobalSearchResult(
          id: saleId,
          title: refString,
          subtitle: "$clientName | ${DateFormatter.formatShortDate(date)} | ${DateFormatter.formatCurrency(totalAmount, currency)} | $pMethod ($statusLabel)",
          type: SearchResultType.sale,
          original: row,
        ));
      }

      // 6. Search Expenses
      if (user != null && user.canManageExpenses) {
        final expenseMaps = await db.query(
          'financial_transactions',
          where: "category = 'EXPENSE' AND (description LIKE ? OR reference_id LIKE ?)",
          whereArgs: ['%$query%', '%$query%'],
          limit: 5,
        );
        final expenses = expenseMaps.map((m) => FinancialTransaction.fromMap(m)).toList();
        for (var ex in expenses) {
          final categoryLabel = ex.referenceId ?? "Autre";
          results.add(GlobalSearchResult(
            id: ex.id,
            title: "$categoryLabel : ${ex.description ?? ''}",
            subtitle: "Dépense | -${DateFormatter.formatCurrency(ex.amount, currency)} | ${DateFormatter.formatShortDate(ex.date)}",
            type: SearchResultType.expense,
            original: ex,
          ));
        }
      }

      state = AsyncData(results);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() {
    state = const AsyncData([]);
  }
}
