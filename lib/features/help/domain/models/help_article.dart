import 'package:flutter/material.dart';

enum HelpCategory {
  inventory('Gestion de Stock', Icons.inventory_2_outlined),
  pos('Point de Vente', Icons.point_of_sale_outlined),
  finance('Finance & Trésorerie', Icons.account_balance_wallet_outlined),
  network('Réseau & Multi-Postes', Icons.lan_outlined),
  security('Sécurité & Admin', Icons.security_outlined),
  general('Généralités', Icons.help_outline);

  final String label;
  final IconData icon;
  const HelpCategory(this.label, this.icon);
}

class HelpArticle {
  final String id;
  final String title;
  final String markdownContent;
  final HelpCategory category;
  final IconData icon;

  const HelpArticle({
    required this.id,
    required this.title,
    required this.markdownContent,
    required this.category,
    required this.icon,
  });
}
